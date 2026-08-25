#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at etcd v3.6.4 which has already
# seen two releases of it (v3.6.4-0 and v3.6.4-1).
#
# The defaults file mirrors the real one: the version value carries a leading
# `v`, and the image name and tag are derived from it through Jinja rather
# than repeating it. A match on `etcd_container_image_tag` would therefore
# yield the literal `{{ etcd_version }}`, and a match on `etcd_container_image`
# a whole image reference.
#
# The decoy `..._repo_version` key above `etcd_version` is a hostile input
# rather than a copy of anything currently in defaults/main.yml: keys ending
# in `_version` have come and gone there, and a match on `_version:` instead
# of on the anchored leaf name has to keep being wrong when the next one
# arrives.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		etcd_decoy_repo_version: "main"

		# renovate: datasource=docker depName=gcr.io/etcd-development/etcd versioning=semver
		etcd_version: v3.6.4

		etcd_container_image: "{{ etcd_container_image_registry_prefix }}etcd-development/etcd:{{ etcd_container_image_tag }}"
		etcd_container_image_tag: "{{ etcd_version }}"
	YAML

	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local release_number
	for release_number in 0 1; do
		git tag "v3.6.4-$release_number"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^etcd_version: v3.6.4|etcd_version: v3.7.0|' defaults/main.yml"
revert_version="sed -i 's|^etcd_version: v3.7.0|etcd_version: v3.6.4|' defaults/main.yml"
unprefixed_version="sed -i 's|^etcd_version: v3.6.4|etcd_version: 3.7.0|' defaults/main.yml"
bump_decoy="sed -i 's|_repo_version: \"main\"|_repo_version: \"9.9.9\"|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v3.7.0-0 "$(merge "$bump_version")"
expect 'task edit'    v3.7.0-1 "$(merge "$edit_task")"
expect 'template'     v3.7.0-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v3.6.4-2 "$(merge "$edit_task")"
expect 'version bump' v3.7.0-0 "$(merge "$bump_version")"

scenario 'Commits that do not affect the role'
expect 'README'   ''       "$(merge "$edit_readme")"
expect 'a script' ''       "$(merge "$edit_script")"
expect 'a task'   v3.6.4-2 "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v3.6.4-$release_number"
done
expect 'a task' v3.6.4-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v3.6.4-1 already published, so there is
# nothing new to release.
expect 'a revert' '' "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v3.6.4-2 "$(merge "$revert_version && $edit_task")"

# The value carries a leading `v` and so do the tags, but the two must not be
# doubled up into `vv3.7.0-0`.
scenario 'A version value carrying a leading v does not double it in the tag'
expect 'version bump' v3.7.0-0 "$(merge "$bump_version")"

# Every release before the switch to the official container image was cut
# from a value which carried no `v`, so a value which loses one has to keep
# producing the same shape of tag.
scenario 'A version value carrying no leading v still gets one in the tag'
expect 'version bump' v3.7.0-0 "$(merge "$unprefixed_version")"

# The decoy sits above `etcd_version` in the defaults file. Changing it is a
# role change and deserves a release, but the release must still be numbered
# against the etcd version.
scenario 'A decoy version key does not become the tag'
expect 'decoy bump' v3.6.4-2 "$(merge "$bump_decoy")"

# The image name and tag are Jinja references. Reading either of them instead
# of the leaf would produce a tag with braces in it, which is how a literal
# `v{{-0` once reached a release in this organization.
scenario 'A derived image reference does not become the tag'
expect 'task edit' v3.6.4-2 "$(merge "$edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
