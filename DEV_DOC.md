# Inception Developer Guide

## Purpose

This document describes how to prepare, build, operate, inspect, and modify the Inception infrastructure.

The stack consists of:

```text
NGINX
  |
  | FastCGI
  v
WordPress + PHP-FPM
  |
  | MariaDB protocol
  v
MariaDB
```

The services are built from custom Dockerfiles and managed by Docker Compose.

## Prerequisites

The current development environment assumes:

- a Linux virtual machine;
- Docker Engine;
- Docker Compose;
- `doas`;
- Internet access during image build and initial WordPress download;
- a network interface named `eth0`.

The current VM uses Alpine Linux.

The service images use Alpine Linux 3.23 as their base image.

## Repository structure

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore
├── secrets/
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── mariadb-server.cnf
        │   └── tools/
        │       └── entrypoint.sh
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── default.conf
        │   └── tools/
        │       └── entrypoint.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── www.conf
        │   └── tools/
        │       └── entrypoint.sh
        └── tools/
            └── setup-host.sh
```

The `secrets/` directory is intentionally excluded from Git.

## Initial setup from scratch

### 1. Review environment configuration

The non-sensitive application settings are stored in:

```text
srcs/.env
```

Current values include:

```text
DOMAIN_NAME=sohyamaz.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser

WP_TITLE=Inception
WP_ADMIN_USER=owner42
WP_ADMIN_EMAIL=owner42@42.fr
WP_USER=user42
WP_USER_EMAIL=user42@42.fr
```

If adapting the project for another 42 login, update at least:

```text
DOMAIN_NAME=<login>.42.fr
```

The NGINX `server_name` in:

```text
srcs/requirements/nginx/conf/default.conf
```

must match the selected domain.

### 2. Create local secrets

Create the local secrets directory:

```sh
mkdir -p secrets
```

Generate passwords, for example:

```sh
head -c 24 /dev/urandom | base64 > secrets/db_password.txt
head -c 24 /dev/urandom | base64 > secrets/db_root_password.txt
head -c 24 /dev/urandom | base64 > secrets/wp_admin_password.txt
head -c 24 /dev/urandom | base64 > secrets/wp_user_password.txt
```

Do not commit these files.

Verify that Git ignores them:

```sh
git check-ignore -v secrets/db_password.txt
```

### 3. Configure the VM host

Run:

```sh
make setup
```

This executes:

```text
srcs/requirements/tools/setup-host.sh
```

The script:

1. determines the current login;
2. creates `/home/<login>/data/docker`;
3. configures Docker's `data-root` to use that location;
4. restarts Docker when the root changes;
5. retrieves the IPv4 address of `eth0`;
6. adds `<login>.42.fr` to `/etc/hosts` if necessary.

The helper is intended for the dedicated Inception VM. It assumes the main interface is named `eth0` and manages `/etc/docker/daemon.json`.

Verify the Docker root:

```sh
docker info --format '{{.DockerRootDir}}'
```

Expected:

```text
/home/<login>/data/docker
```

### 4. Build and launch

From the repository root:

```sh
make
```

This runs Docker Compose with:

```sh
docker compose -f srcs/docker-compose.yml up -d --build
```

Verify:

```sh
make ps
```

## Makefile targets

### Build and launch

```sh
make
make up
```

Build the images and start the stack.

### Host preparation

```sh
make setup
```

Configure the Docker data root and local hostname mapping.

### Stop existing containers

```sh
make stop
```

### Start existing containers

```sh
make start
```

### Restart services

```sh
make restart
```

### Display status

```sh
make ps
```

### Display logs

```sh
make logs
```

### Remove containers but preserve volumes

```sh
make down
make clean
```

### Remove containers, images, and persistent volumes

```sh
make fclean
```

This is destructive.

### Full destructive rebuild

```sh
make re
```

This runs `fclean` before rebuilding and therefore removes persistent WordPress and MariaDB data.

## Docker Compose architecture

The Compose project defines three services:

```text
mariadb
wordpress
nginx
```

Each service:

- is built from its own Dockerfile;
- receives non-sensitive values through `.env`;
- joins the `inception` Docker network;
- uses `restart: unless-stopped`.

### MariaDB

Image:

```text
mariadb:inception
```

Container:

```text
mariadb
```

Internal port:

```text
3306
```

Persistent storage:

```text
mariadb:/var/lib/mysql
```

Secrets:

```text
db_password
db_root_password
```

On the first startup, the entrypoint:

1. initializes the MariaDB data directory using `mariadb-install-db`;
2. executes initialization SQL using `mariadbd --bootstrap`, without starting a background server;
3. configures the root password;
4. creates the WordPress database;
5. creates the normal database user;
6. grants that user access to the WordPress database;
7. skips initialization on subsequent starts when the MariaDB system database directory already exists;
8. replaces the shell process with the final `mariadbd` process using `exec`.

The final process uses `exec`, allowing MariaDB to become the main container process.

### WordPress

Image:

```text
wordpress:inception
```

Container:

```text
wordpress
```

Internal PHP-FPM port:

```text
9000
```

Persistent storage:

```text
wordpress:/var/www/html
```

Secrets:

```text
db_password
wp_admin_password
wp_user_password
```

The WordPress entrypoint waits until MariaDB accepts a query.

On the first startup it then:

1. downloads WordPress with WP-CLI;
2. generates `wp-config.php`;
3. installs WordPress;
4. creates the administrator account;
5. creates the regular WordPress user;
6. fixes filesystem ownership;
7. replaces the shell process with foreground PHP-FPM.

Existing WordPress data is detected and reused on later starts.

### NGINX

Image:

```text
nginx:inception
```

Container:

```text
nginx
```

Published host port:

```text
443
```

The NGINX container mounts the WordPress volume read-only so that it can serve static WordPress files.

PHP requests are forwarded through FastCGI to:

```text
wordpress:9000
```

At container startup, the NGINX entrypoint generates a self-signed certificate if one is not present and then starts NGINX in the foreground.

Only TLS 1.2 and TLS 1.3 are enabled.

## Docker networking

All three services join the dedicated bridge network:

```text
inception
```

Docker provides internal DNS resolution based on service names.

This allows:

```text
nginx -> wordpress:9000
wordpress -> mariadb:3306
```

without publishing WordPress or MariaDB ports on the VM host.

Inspect the network with:

```sh
docker network ls
docker network inspect srcs_inception
```

## Persistent storage

Two Docker named volumes are defined:

```text
srcs_mariadb
srcs_wordpress
```

Inspect them with:

```sh
docker volume ls
docker volume inspect srcs_mariadb
docker volume inspect srcs_wordpress
```

Because Docker's data root is configured under:

```text
/home/<login>/data/docker
```

their storage is expected under paths such as:

```text
/home/<login>/data/docker/volumes/srcs_mariadb/_data
/home/<login>/data/docker/volumes/srcs_wordpress/_data
```

The Compose definitions remain normal Docker named volumes and do not use bind-mount driver options.

Persistent data survives container recreation and normal VM reboots as long as the named volumes are not removed.

## Secrets and configuration

Non-sensitive configuration is stored in:

```text
srcs/.env
```

Sensitive values are stored in local files under:

```text
secrets/
```

Compose exposes them to containers as files under:

```text
/run/secrets/
```

Examples:

```text
/run/secrets/db_password
/run/secrets/db_root_password
/run/secrets/wp_admin_password
/run/secrets/wp_user_password
```

Changing a secret file does not automatically rotate an already initialized password stored in MariaDB or WordPress persistent data.

For an existing installation, the application account must also be updated.

## Useful inspection commands

### Container status

```sh
docker compose -f srcs/docker-compose.yml ps
```

### Images

```sh
docker image ls
```

### Network

```sh
docker network ls
```

### Volumes

```sh
docker volume ls
```

### Effective NGINX TLS configuration

```sh
docker exec nginx nginx -T 2>/dev/null | grep ssl_protocols
```

Expected protocols:

```text
TLSv1.2 TLSv1.3
```

### HTTP must not be available

```sh
curl -v --max-time 5 http://sohyamaz.42.fr/
```

Port 80 should refuse the connection.

### HTTPS

```sh
curl -k -I https://sohyamaz.42.fr/
```

### MariaDB health

```sh
docker exec mariadb sh -c \
'mariadb-admin -uroot -p"$(cat /run/secrets/db_root_password)" ping'
```

### MariaDB interactive login

```sh
docker exec -it mariadb sh
```

Then:

```sh
mariadb -uroot -p"$(cat /run/secrets/db_root_password)"
```

or:

```sh
mariadb \
  -u"$MYSQL_USER" \
  -p"$(cat /run/secrets/db_password)" \
  "$MYSQL_DATABASE"
```

### WordPress installation status

```sh
docker exec wordpress \
wp core is-installed \
--path=/var/www/html \
--allow-root
```

### WordPress users

```sh
docker exec wordpress \
wp user list \
--path=/var/www/html \
--allow-root
```

## Rebuilding after configuration changes

After modifying a Dockerfile, entrypoint, or configuration file, rebuild the affected stack with:

```sh
make
```

For one service only, Docker Compose can also be used directly:

```sh
docker compose -f srcs/docker-compose.yml up -d --build nginx
```

Replace `nginx` with the relevant service.

If the configuration affects a dependent service, recreate the required dependent containers as well.

Do not use `make re` merely to rebuild configuration unless intentionally deleting the persistent data.

## Persistence test

A complete persistence test can be performed as follows:

1. Create or edit visible WordPress content.
2. Confirm the change in the browser.
3. Reboot the VM.
4. Start the project again with:

```sh
make
```

5. Confirm that the WordPress content is still present.
6. Confirm that MariaDB remains initialized.

This verifies that application state is stored in the named volumes rather than only inside the disposable container layers.
