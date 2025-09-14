<!--
SPDX-FileCopyrightText: 2024 Slavi Pantaleev

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# etcd Ansible role

>[!NOTE]
> Currently this role is configured to use a container image for etcd in Bitnami Legacy repository, an archive for images which [Bitnami has stopped maintaining](https://github.com/bitnami/containers/issues/83267). Because the image stops receiving an update after September 29th, 2025 and it may be deleted in a future, it is recommended to migrate to another container image.

This is an [Ansible](https://www.ansible.com/) role which installs [etcd](https://etcd.io/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)

For an Ansible playbook which integrates this role and makes it easier to use, see the [mash-playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

💡 See this [document](docs/configuring-etcd.md) for details about setting up the service with this role.

## Development

You can optionally install [pre-commit](https://pre-commit.com/) so that simple mistakes are checked and noticed before changes are pushed to a remote branch. See [`.pre-commit-config.yaml`](./.pre-commit-config.yaml) for which hooks are to be executed.

See [this section](https://pre-commit.com/#usage) on the official documentation for usage.
