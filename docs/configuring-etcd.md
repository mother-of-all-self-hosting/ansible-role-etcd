<!--
SPDX-FileCopyrightText: 2020 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2020 - 2026 Slavi Pantaleev
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up etcd

This is an [Ansible](https://www.ansible.com/) role which installs [etcd](https://etcd.io) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

etcd is a strongly consistent, distributed key-value store that provides a reliable way to store data that needs to be accessed by a distributed system or cluster of machines. It gracefully handles leader elections during network partitions and can tolerate machine failure, even in the leader node.

See the project's [documentation](https://etcd.io/docs/latest/) to learn what etcd does and why it might be useful to you.

## Adjusting the playbook configuration

To enable etcd with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# etcd                                                                 #
#                                                                      #
########################################################################

etcd_enabled: true

########################################################################
#                                                                      #
# /etcd                                                                #
#                                                                      #
########################################################################
```

### Password-protect the instance

You also need to set the root password by adding the following configuration to your `vars.yml` file:

```yaml
etcd_environment_variable_etcd_root_password: YOUR_PASSWORD_HERE
```

Each time the service starts, the role creates etcd's `root` user with this password and turns etcd's authentication on, after which etcd refuses clients which do not authenticate. Both steps are skipped when they have already been done, so restarting the service repeatedly is harmless.

Note that etcd is briefly reachable without authentication while this happens: it has to be running before it can be told about a user at all. The window lasts a second or two per start, and is only reachable from etcd's own container network unless you publish its port with `etcd_container_client_communication_bind_port`.

Add the following configuration if you'd like to run etcd without password-protection:

```yaml
etcd_environment_variable_allow_none_authentication: true
```

#### Changing the password later

etcd stores the password itself, and changing a stored password requires knowing the current one — which this role does not keep. Changing `etcd_environment_variable_etcd_root_password` on an instance which has already been started therefore does **not** change what etcd accepts. The service keeps running, and each start reports the mismatch to its log:

```text
etcd requires authentication, but not with the password etcd is configured with.
```

To actually change it, change it in etcd first and in `vars.yml` afterwards:

```sh
docker exec etcd etcdctl --user root:CURRENT_PASSWORD user passwd root --new-user-password=NEW_PASSWORD
```

(replace `etcd` with the name your playbook gives the service, e.g. `mash-etcd`)

The same applies in reverse: setting `etcd_environment_variable_allow_none_authentication` to `true` on an instance which already requires authentication does not turn authentication back off. Run `docker exec etcd etcdctl --user root:CURRENT_PASSWORD auth disable` to do that.

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `etcd_environment_variables_additional_variables` variable

See its [this page](https://etcd.io/docs/latest/op-guide/configuration/) for a complete list of etcd's config options that you could put in `etcd_environment_variables_additional_variables`.

## Upgrading from a release before `v3.6.4-10`

Releases up to and including `v3.6.4-9` ran [Bitnami's etcd container image](https://hub.docker.com/r/bitnamilegacy/etcd), which Bitnami has stopped maintaining. This role now runs [the image etcd publishes itself](https://gcr.io/etcd-development/etcd).

There is nothing to do: the two keep their data in the same place, and the role hands the new image the same directory the old one wrote to. Your data, your `root` user and its password all carry over. Just run the playbook.

A few settings changed along the way, and the role fails with a message naming each of them if it finds one in your configuration:

- `etcd_environment_variable_etcd_enable_v2` is gone. etcd 3.6 removed the v2 API, so it had stopped doing anything.
- the `etcd_container_image_self_build*` settings are gone. Self-building only ever built Bitnami's image, and etcd's own image cannot be built from a checkout without a Go toolchain first producing its binaries.

`etcd_environment_variable_etcd_root_password` and `etcd_environment_variable_allow_none_authentication` keep working and keep meaning the same thing, but they are no longer passed to the container: nothing in the official image reads them. The role sets etcd's authentication up itself instead, as described above.

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, the etcd instance becomes available.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu etcd` (or how you/your playbook named the service, e.g. `mash-etcd`).
