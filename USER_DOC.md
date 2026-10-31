# Inception User Guide

## Overview

Inception provides a WordPress website running as a Docker-based stack composed of three services:

- **NGINX** — HTTPS entry point.
- **WordPress + PHP-FPM** — WordPress application.
- **MariaDB** — WordPress database.

Only HTTPS port 443 is exposed to the host.

The website is available at:

```text
https://sohyamaz.42.fr
```

The WordPress administration panel is available at:

```text
https://sohyamaz.42.fr/wp-admin
```

A self-signed TLS certificate is used, so a browser certificate warning is expected.

## Starting the project

Move to the repository root:

```sh
cd ~/inception
```

For a VM that has not yet been prepared, run:

```sh
make setup
```

Then build and start the stack:

```sh
make
```

Check its status:

```sh
make ps
```

The expected services are:

```text
mariadb
wordpress
nginx
```

All three should show a running status.

NGINX should be the only service publishing a host port, on port 443.

## Stopping the project

Stop the existing containers without removing them:

```sh
make stop
```

Start the same containers again:

```sh
make start
```

To remove the containers and Docker network while preserving persistent data:

```sh
make down
```

Start the project again with:

```sh
make
```

## Viewing logs

Display service logs with:

```sh
make logs
```

For one service only:

```sh
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

## Website access

Open:

```text
https://sohyamaz.42.fr
```

HTTP access on port 80 is intentionally disabled.

It can be checked from the VM with:

```sh
curl -v --max-time 5 http://sohyamaz.42.fr/
```

The connection should fail.

HTTPS can be checked with:

```sh
curl -k https://sohyamaz.42.fr/
```

The `-k` option accepts the project's self-signed certificate.

## WordPress accounts

The configured WordPress usernames are defined in `srcs/.env`.

Current accounts:

```text
Administrator: owner42
User:          user42
```

Their passwords are not stored in `.env` or committed to Git.

The corresponding local secret files are:

```text
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

To access the administration panel, open:

```text
https://sohyamaz.42.fr/wp-admin
```

and log in as `owner42` using the password stored locally in:

```text
secrets/wp_admin_password.txt
```

## Database credentials

The database configuration is defined by:

```text
srcs/.env
secrets/db_password.txt
secrets/db_root_password.txt
```

The current database name and normal database user are:

```text
Database: wordpress
User:     wpuser
```

Passwords must never be committed to Git.

## Managing credentials

Credential files are stored locally under:

```text
secrets/
```

This directory is ignored by Git.

For a fresh installation, credentials should be set before the first startup.

Changing a secret file after WordPress or MariaDB has already been initialized does not automatically change the password stored inside the persistent application data.

Password rotation on an existing installation must therefore also update the corresponding WordPress or MariaDB account.

Alternatively, persistent data can be deliberately removed and the stack initialized again with new credentials.

## Basic health checks

Check containers:

```sh
make ps
```

Check the website:

```sh
curl -k -I https://sohyamaz.42.fr/
```

Check MariaDB:

```sh
docker exec mariadb sh -c \
'mariadb-admin -uroot -p"$(cat /run/secrets/db_root_password)" ping'
```

Expected result:

```text
mysqld is alive
```

Check whether WordPress is installed:

```sh
docker exec wordpress \
wp core is-installed \
--path=/var/www/html \
--allow-root
```

A successful command with exit code `0` means WordPress is installed.

## Persistent data

WordPress files and MariaDB data are stored in Docker named volumes.

They survive:

```sh
make stop
make start
```

and:

```sh
make down
make
```

They are also expected to survive a normal VM reboot.

### Warning: destructive commands

Do not use the following commands unless persistent data is intentionally being deleted:

```sh
make fclean
make re
```

`make fclean` removes the Docker named volumes.

`make re` runs `fclean` before rebuilding, so it also removes the persistent WordPress and database data.
