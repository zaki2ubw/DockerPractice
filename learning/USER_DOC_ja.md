# Inception ユーザーガイド

## 概要

Inceptionは、Dockerベースのstack上で動作するWordPress Webサイトを提供します。このstackは3つのserviceで構成されています。

- **NGINX** — HTTPSのentry point
- **WordPress + PHP-FPM** — WordPress application
- **MariaDB** — WordPress database

hostへ公開されているのはHTTPSの443番portのみです。

Webサイトは以下からアクセスできます。

```text
https://sohyamaz.42.fr
```

WordPress管理画面は以下です。

```text
https://sohyamaz.42.fr/wp-admin
```

self-signed TLS certificateを使用しているため、browserでcertificate warningが表示されるのは正常です。

## プロジェクトの起動

repository rootへ移動します。

```sh
cd ~/inception
```

まだ準備されていないVMの場合、以下を実行します。

```sh
make setup
```

その後、stackをbuildして起動します。

```sh
make
```

状態を確認します。

```sh
make ps
```

以下のserviceが表示されることを確認します。

```text
mariadb
wordpress
nginx
```

3つすべてがrunning状態である必要があります。

hostにportを公開しているserviceは、443番portのNGINXのみである必要があります。

## プロジェクトの停止

既存containerを削除せず停止します。

```sh
make stop
```

同じcontainerを再び起動します。

```sh
make start
```

persistent dataを残したままcontainerとDocker networkを削除する場合は以下を実行します。

```sh
make down
```

再び起動するには以下を実行します。

```sh
make
```

## ログの確認

service logを表示します。

```sh
make logs
```

特定のserviceだけ確認する場合:

```sh
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

## Webサイトへのアクセス

以下を開きます。

```text
https://sohyamaz.42.fr
```

HTTPの80番portへのaccessは意図的に無効になっています。

VMから以下で確認できます。

```sh
curl -v --max-time 5 http://sohyamaz.42.fr/
```

connectionは失敗する必要があります。

HTTPSは以下で確認できます。

```sh
curl -k https://sohyamaz.42.fr/
```

`-k` optionは、このprojectで使用しているself-signed certificateを許可します。

## WordPressアカウント

設定されているWordPress usernameは `srcs/.env` で定義されています。

現在のaccount:

```text
Administrator: owner42
User:          user42
```

passwordは `.env` に保存されておらず、Gitにもcommitされていません。

対応するlocal secret fileは以下です。

```text
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

管理画面へaccessするには、以下を開きます。

```text
https://sohyamaz.42.fr/wp-admin
```

`owner42` でloginし、passwordには以下にローカル保存されている値を使用します。

```text
secrets/wp_admin_password.txt
```

## Database credential

database configurationは以下で定義されています。

```text
srcs/.env
secrets/db_password.txt
secrets/db_root_password.txt
```

現在のdatabase nameと通常利用するdatabase userは以下です。

```text
Database: wordpress
User:     wpuser
```

passwordは絶対にGitへcommitしてはいけません。

## Credentialの管理

credential fileは以下にローカル保存されています。

```text
secrets/
```

このdirectoryはGitの管理対象外です。

新規installationでは、初回起動前にcredentialを設定する必要があります。

WordPressまたはMariaDBがすでに初期化されたあとでsecret fileだけを変更しても、persistent application data内に保存されているpasswordは自動では変更されません。

そのため、既存installationでpasswordをrotationする場合は、対応するWordPressまたはMariaDB account側のpasswordも変更する必要があります。

別の方法として、persistent dataを意図的に削除し、新しいcredentialでstackを再初期化することもできます。

## 基本的なhealth check

containerを確認します。

```sh
make ps
```

Webサイトを確認します。

```sh
curl -k -I https://sohyamaz.42.fr/
```

MariaDBを確認します。

```sh
docker exec mariadb sh -c \
'mariadb-admin -uroot -p"$(cat /run/secrets/db_root_password)" ping'
```

期待される結果:

```text
mysqld is alive
```

WordPressがinstall済みか確認します。

```sh
docker exec wordpress \
wp core is-installed \
--path=/var/www/html \
--allow-root
```

commandが成功しexit code `0` を返せば、WordPressはinstall済みです。

## Persistent data

WordPress fileとMariaDB dataはDocker named volumeに保存されています。

以下を実行してもdataは保持されます。

```sh
make stop
make start
```

また、以下でも保持されます。

```sh
make down
make
```

通常のVM reboot後もdataは保持される想定です。

### 警告: 破壊的command

persistent dataを意図的に削除する場合以外、以下のcommandは使用しないでください。

```sh
make fclean
make re
```

`make fclean` はDocker named volumeを削除します。

`make re` はrebuild前に `fclean` を実行するため、永続化されたWordPress dataとdatabase dataも削除します。
