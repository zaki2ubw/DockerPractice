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
    ├── .env.example
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

`secrets/` and `srcs/.env` are generated locally by `make init` and are intentionally excluded from Git. `srcs/.env.example` is the tracked template.

## Initial setup from scratch

From the repository root:

```sh
make setup
make init
vi srcs/.env
make
```

Each step has a single responsibility. `make init` does not call `make setup`.

### 1. Configure the VM host

Run:

```sh
make setup
```

This executes:

```text
srcs/requirements/tools/setup-host.sh
```

The script:

1. determines the current login and uses `<login>.42.fr` as the domain;
2. retrieves the IPv4 address of `eth0`;
3. creates `/home/<login>/data/docker`;
4. writes `/etc/docker/daemon.json` with that `data-root` and restarts Docker, only when the current Docker root differs;
5. checks whether `/etc/hosts` contains the exact line `<current IP> <login>.42.fr`;
6. if not, removes any existing line for `<login>.42.fr` (for example one with an old IP) and appends the current mapping.

The script is safe to re-run: an already correct Docker root and hosts entry are left unchanged.

The helper is intended for the dedicated Inception VM. It assumes the main interface is named `eth0` and manages `/etc/docker/daemon.json`.

Verify the Docker root:

```sh
docker info --format '{{.DockerRootDir}}'
```

Expected:

```text
/home/<login>/data/docker
```

### 2. Generate `.env` and secrets

Run:

```sh
make init
```

This:

1. copies `srcs/.env.example` to `srcs/.env` if `srcs/.env` does not exist;
2. creates `secrets/` and generates the four password files with `head -c 24 /dev/urandom | base64`, readable only by the owner (`umask 077`):

```text
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

On re-run, an existing `srcs/.env` and existing non-empty secret files are preserved. If a secret file exists but is empty, `make init` stops with an error; delete or fill the file and run it again.

`make init` never fills in or rewrites the values inside `srcs/.env`.

Verify that Git ignores the generated files:

```sh
git check-ignore -v srcs/.env secrets/db_password.txt
```

### 3. Edit environment configuration

```sh
vi srcs/.env
```

The template contains:

```text
DOMAIN_NAME=
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser

WP_TITLE=Inception
WP_ADMIN_USER=
WP_ADMIN_EMAIL=
WP_USER=
WP_USER_EMAIL=
```

Set the five empty values manually:

```text
DOMAIN_NAME=sohyamaz.42.fr
WP_ADMIN_USER=<administrator name>
WP_ADMIN_EMAIL=<administrator email>
WP_USER=<regular user name>
WP_USER_EMAIL=<regular user email>
```

`MYSQL_DATABASE`, `MYSQL_USER`, and `WP_TITLE` have usable defaults.

The administrator name must not contain `admin` or `administrator` (for example `admin`, `Admin`, `administrator`, `admin-123`), as forbidden by the subject.

Passwords are not set in `.env`; they come from the files under `secrets/`.

If adapting the project for another 42 login, use `DOMAIN_NAME=<login>.42.fr`. The NGINX `server_name` in:

```text
srcs/requirements/nginx/conf/default.conf
```

must match the selected domain.

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

Configure the Docker data root and local hostname mapping. Re-run after cloning the VM or when its IP address changes.

### Initialize local configuration

```sh
make init
```

Create `srcs/.env` from the template and generate the four secret files. Existing files are preserved.

### Stop existing containers

```sh
make stop
```

Containers are stopped but not removed.

### Start existing containers

```sh
make start
```

Starts containers that already exist. It does not build images or create missing containers; use `make` for that.

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

Both remove the containers and the Compose network. Named volumes are kept.

### Remove containers, images, and persistent volumes

```sh
make fclean
```

Runs `docker compose down -v --rmi all`. This is destructive: the named volumes holding WordPress files and the MariaDB database are deleted.

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

### TLS handshake per protocol version

```sh
openssl s_client -connect sohyamaz.42.fr:443 -servername sohyamaz.42.fr -tls1_2 </dev/null
openssl s_client -connect sohyamaz.42.fr:443 -servername sohyamaz.42.fr -tls1_3 </dev/null
```

Both should complete the handshake and report the negotiated protocol.

### Published ports

```sh
docker ps
```

Only `nginx` should show a host mapping (`0.0.0.0:443->443/tcp`). `wordpress` (9000) and `mariadb` (3306) must not publish ports to the host.

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

## Changing the VM IP address

`<login>.42.fr` is resolved through `/etc/hosts`. After cloning the VM, or whenever the IP address of `eth0` changes, run again:

```sh
make setup
```

`setup-host.sh` replaces an outdated `<login>.42.fr` line with the current IP and leaves a correct entry unchanged.

Check the current IP and the registered mapping:

```sh
ip -4 addr show eth0
grep 'sohyamaz.42.fr' /etc/hosts
```

Both should show the same IPv4 address.

## Temporarily changing the HTTPS host port

The subject-compliant configuration publishes port 443. For evaluation or testing only, the host port can be changed temporarily. The example below uses 8443.

### Change the published port

Edit `srcs/docker-compose.yml`, in the `nginx` service:

```yaml
ports:
  - "8443:443"
```

The format is `HOST_PORT:CONTAINER_PORT`. NGINX still listens on 443 inside the container, so `listen` in `nginx/conf/default.conf` and `EXPOSE` in the NGINX Dockerfile are not changed.

Apply the change:

```sh
make
```

Verify:

```sh
docker ps
curl -k -I https://sohyamaz.42.fr:8443
```

`docker ps` should show `0.0.0.0:8443->443/tcp` for `nginx`.

### WordPress canonical URL

WordPress stores its `home` and `siteurl` options in the database. After changing only the Compose port, requests to port 8443 may be redirected (HTTP 301) to the original `https://sohyamaz.42.fr`.

To use 8443 as the canonical URL:

```sh
docker exec wordpress wp option update home \
  'https://sohyamaz.42.fr:8443' --allow-root

docker exec wordpress wp option update siteurl \
  'https://sohyamaz.42.fr:8443' --allow-root
```

Verify:

```sh
curl -k -I https://sohyamaz.42.fr:8443
```

### Restore port 443

1. While the stack is still running, restore the WordPress URLs:

```sh
docker exec wordpress wp option update home \
  'https://sohyamaz.42.fr' --allow-root

docker exec wordpress wp option update siteurl \
  'https://sohyamaz.42.fr' --allow-root
```

2. Restore `srcs/docker-compose.yml`:

```yaml
ports:
  - "443:443"
```

3. Apply and verify:

```sh
make
docker ps
curl -k -I https://sohyamaz.42.fr
```

This procedure does not delete the named volumes; WordPress content and the database are preserved. Do not use `make fclean` or `make re` for it.

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

## Verified behavior

The following was confirmed in the project VM:

- initial build from a clean clone of the GitHub repository using `make setup`, `make init`, editing `srcs/.env`, and `make`;
- the `nginx`, `wordpress`, and `mariadb` containers running;
- HTTPS returning HTTP 200;
- creation of the WordPress administrator and regular user;
- persistence of posts and comments;
- successful TLS 1.2 and TLS 1.3 connections;
- connections to HTTP port 80 refused;
- no host ports published by `wordpress` or `mariadb`;
- temporary change of the host port to 8443 and restoration to 443 using the procedure above.
