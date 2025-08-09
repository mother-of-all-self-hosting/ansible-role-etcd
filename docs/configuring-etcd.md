<!--
SPDX-FileCopyrightText: 2020 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2020 - 2024 Slavi Pantaleev
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

Add the following configuration if you'd like to run etcd without password-protection:

```yaml
etcd_environment_variable_allow_none_authentication: true
```

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `etcd_environment_variables_additional_variables` variable

See its [this page](https://etcd.io/docs/latest/op-guide/configuration/) for a complete list of etcd's config options that you could put in `etcd_environment_variables_additional_variables`.

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
