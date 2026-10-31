# Inception 開発者ガイド

## 目的

このdocumentでは、Inception infrastructureの準備、build、運用、調査、変更方法について説明します。

stackは以下の構成です。

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

各serviceは独自のDockerfileからbuildされ、Docker Composeによって管理されます。

## 前提条件

現在のdevelopment environmentでは以下を前提としています。

- Linux virtual machine
- Docker Engine
- Docker Compose
- `doas`
- image buildおよび初回WordPress download時のInternet接続
- `eth0` という名前のnetwork interface

現在のVMではAlpine Linuxを使用しています。

service imageはAlpine Linux 3.23をbase imageとして使用しています。

## Repository構成

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

`secrets/` directoryは意図的にGitの管理対象外にしています。

## ゼロからの初期setup

### 1. Environment configurationの確認

機密性のないapplication settingは以下に保存されています。

```text
srcs/.env
```

現在の値には以下が含まれています。

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

このprojectを別の42 login用に変更する場合、少なくとも以下を更新します。

```text
DOMAIN_NAME=<login>.42.fr
```

以下にあるNGINXの `server_name` も、

```text
srcs/requirements/nginx/conf/default.conf
```

設定したdomainと一致させる必要があります。

### 2. Local secretの作成

local secrets directoryを作成します。

```sh
mkdir -p secrets
```

例えば以下のようにpasswordを生成できます。

```sh
head -c 24 /dev/urandom | base64 > secrets/db_password.txt
head -c 24 /dev/urandom | base64 > secrets/db_root_password.txt
head -c 24 /dev/urandom | base64 > secrets/wp_admin_password.txt
head -c 24 /dev/urandom | base64 > secrets/wp_user_password.txt
```

これらのfileをcommitしてはいけません。

Gitによって無視されていることを確認します。

```sh
git check-ignore -v secrets/db_password.txt
```

### 3. VM hostの設定

以下を実行します。

```sh
make setup
```

これにより以下が実行されます。

```text
srcs/requirements/tools/setup-host.sh
```

scriptは以下を行います。

1. 現在のlogin名を取得する
2. `/home/<login>/data/docker` を作成する
3. Dockerの `data-root` にその場所を設定する
4. data rootが変更された場合Dockerをrestartする
5. `eth0` のIPv4 addressを取得する
6. 必要に応じて `<login>.42.fr` を `/etc/hosts` に追加する

このhelperはInception専用VMでの使用を想定しています。main interfaceの名前が `eth0` であることを前提とし、`/etc/docker/daemon.json` を管理します。

Docker rootを確認します。

```sh
docker info --format '{{.DockerRootDir}}'
```

期待される値:

```text
/home/<login>/data/docker
```

### 4. Buildと起動

repository rootから以下を実行します。

```sh
make
```

内部ではDocker Composeの以下のcommandが実行されます。

```sh
docker compose -f srcs/docker-compose.yml up -d --build
```

確認します。

```sh
make ps
```

## Makefile target

### Buildと起動

```sh
make
make up
```

imageをbuildし、stackを起動します。

### Host preparation

```sh
make setup
```

Docker data rootとlocal hostname mappingを設定します。

### 既存containerの停止

```sh
make stop
```

### 既存containerの起動

```sh
make start
```

### Service restart

```sh
make restart
```

### 状態表示

```sh
make ps
```

### Log表示

```sh
make logs
```

### Volumeを残してcontainerを削除

```sh
make down
make clean
```

### Container、image、persistent volumeを削除

```sh
make fclean
```

これは破壊的操作です。

### 完全な破壊的rebuild

```sh
make re
```

`fclean` のあとにrebuildを行うため、persistent WordPress dataとMariaDB dataも削除されます。

## Docker Compose architecture

Compose projectでは3つのserviceを定義しています。

```text
mariadb
wordpress
nginx
```

各serviceは以下の特徴を持ちます。

- 独自のDockerfileからbuildされる
- `.env` から機密性のない値を受け取る
- `inception` Docker networkへ参加する
- `restart: unless-stopped` を使用する

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

初回startup時、entrypointは以下を行います。

1. MariaDB data directoryを初期化する
2. MariaDBをlocalで一時的に起動する
3. root passwordを設定する
4. WordPress databaseを作成する
5. 通常利用するdatabase userを作成する
6. そのuserにWordPress databaseへの権限を付与する
7. 一時的に起動したserverを停止する
8. shell processを最終的な `mariadbd` processで置き換える

最後のprocessでは `exec` を使用し、MariaDBがcontainerのmain processになります。

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

WordPress entrypointは、MariaDBがqueryを受け付けるまで待機します。

初回startupでは、その後以下を行います。

1. WP-CLIを使用してWordPressをdownloadする
2. `wp-config.php` を生成する
3. WordPressをinstallする
4. administrator accountを作成する
5. 通常のWordPress userを作成する
6. filesystem ownershipを修正する
7. shell processをforegroundで動作するPHP-FPMに置き換える

以降のstartupでは、既存のWordPress dataが検出され、再利用されます。

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

NGINX containerは、static WordPress fileを配信できるよう、WordPress volumeをread-onlyでmountします。

PHP requestはFastCGIを通して以下へ転送されます。

```text
wordpress:9000
```

container startup時、NGINX entrypointはcertificateが存在しない場合self-signed certificateを生成し、その後NGINXをforegroundで起動します。

有効になっているのはTLS 1.2とTLS 1.3のみです。

## Docker networking

3つすべてのserviceが専用bridge networkに参加します。

```text
inception
```

Dockerはservice nameに基づく内部DNS resolutionを提供します。

これにより、

```text
nginx -> wordpress:9000
wordpress -> mariadb:3306
```

という通信が可能になります。

WordPressやMariaDBのportをVM hostへ公開する必要はありません。

networkを確認するには以下を使用します。

```sh
docker network ls
docker network inspect srcs_inception
```

## Persistent storage

2つのDocker named volumeを定義しています。

```text
srcs_mariadb
srcs_wordpress
```

以下で確認できます。

```sh
docker volume ls
docker volume inspect srcs_mariadb
docker volume inspect srcs_wordpress
```

Docker data rootは以下に設定されているため、

```text
/home/<login>/data/docker
```

volume dataはたとえば以下のようなpathに保存されます。

```text
/home/<login>/data/docker/volumes/srcs_mariadb/_data
/home/<login>/data/docker/volumes/srcs_wordpress/_data
```

Compose上の定義は通常のDocker named volumeのままであり、bind-mount用のdriver optionは使用していません。

named volumeを削除しない限り、persistent dataはcontainerの再作成や通常のVM reboot後も保持されます。

## Secretsとconfiguration

機密性のないconfigurationは以下に保存されています。

```text
srcs/.env
```

機密性のある値は、以下のlocal fileに保存します。

```text
secrets/
```

Composeによってcontainer内では以下のfileとして利用できます。

```text
/run/secrets/
```

例:

```text
/run/secrets/db_password
/run/secrets/db_root_password
/run/secrets/wp_admin_password
/run/secrets/wp_user_password
```

secret fileを変更しても、すでに初期化されpersistent data内に保存されているMariaDBやWordPressのpasswordは自動でrotationされません。

既存installationでは、application account側のpasswordも更新する必要があります。

## 調査に使えるcommand

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

### 実際に有効なNGINX TLS configuration

```sh
docker exec nginx nginx -T 2>/dev/null | grep ssl_protocols
```

期待されるprotocol:

```text
TLSv1.2 TLSv1.3
```

### HTTPが利用できないことの確認

```sh
curl -v --max-time 5 http://sohyamaz.42.fr/
```

80番portへのconnectionは拒否される必要があります。

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

その後:

```sh
mariadb -uroot -p"$(cat /run/secrets/db_root_password)"
```

または:

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

### WordPress user

```sh
docker exec wordpress \
wp user list \
--path=/var/www/html \
--allow-root
```

## Configuration変更後のrebuild

Dockerfile、entrypoint、configuration fileを変更した場合、以下で対象stackをrebuildします。

```sh
make
```

特定のserviceのみを対象にする場合、Docker Composeを直接使用することもできます。

```sh
docker compose -f srcs/docker-compose.yml up -d --build nginx
```

`nginx` の部分を対象serviceに置き換えます。

configuration変更が依存serviceに影響する場合、必要なdependent containerも再作成します。

persistent dataを意図的に削除したい場合を除き、単なるconfiguration rebuildのために `make re` を使うべきではありません。

## Persistence test

完全なpersistence testは以下のように実行できます。

1. WordPress上で目に見えるcontentを作成または編集する
2. browser上で変更を確認する
3. VMをrebootする
4. 以下でprojectを再び起動する

```sh
make
```

5. WordPress contentが残っていることを確認する
6. MariaDBが初期化済みの状態を維持していることを確認する

これにより、application stateが一時的なcontainer layer内ではなくnamed volumeに保存されていることを確認できます。
