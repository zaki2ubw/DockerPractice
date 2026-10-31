*このプロジェクトは、sohyamaz による 42 curriculum の一環として作成されました。*

# Inception

## 概要

Inception は、Docker Compose を使用して仮想マシン内に小規模なWebインフラストラクチャを構築する、システム管理プロジェクトです。

このプロジェクトは、3つの専用サービスで構成されています。

- **NGINX** — 唯一の外部公開エントリーポイントであり、TLS 1.2 または TLS 1.3 を使用して443番ポートでHTTPSを提供します。
- **WordPress + PHP-FPM** — WordPressアプリケーションを提供し、PHPを実行します。
- **MariaDB** — WordPressのデータベースを保存します。

各サービスはそれぞれ独立したDockerコンテナ内で動作し、Alpine Linuxをベースとした独自のDockerfileからビルドされます。

Docker Composeは、各コンテナをどのようにビルド・接続・設定・再起動するかを定義します。専用のDockerネットワークによって各サービスを接続し、Docker named volumeによってWordPressファイルとMariaDBデータベースを永続化します。

リクエストの流れは次の通りです。

```text
Client
  |
  | HTTPS :443
  v
NGINX
  |
  | FastCGI :9000
  v
WordPress + PHP-FPM
  |
  | MariaDB protocol :3306
  v
MariaDB
```

ホストにポートを公開しているのはNGINXのみです。

### プロジェクト構成

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/                  # ローカル専用、Gitでは無視
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        └── tools/
            └── setup-host.sh
```

各サービスの `Dockerfile` は、そのDocker imageをどのようにビルドするかを定義します。`conf` ディレクトリにはサービスの設定ファイルが、`tools` ディレクトリには初期化処理やentrypoint scriptが含まれています。

`docker-compose.yml` は、network、volume、secret、environment variable、依存関係、restart policyを定義することで、これらの独立したサービスを1つのインフラストラクチャとして組み合わせます。

## アーキテクチャ

この環境全体には、2段階の分離があります。

第1段階は仮想マシンです。Inception環境全体を物理ホストから分離します。

第2段階はDockerです。VM内部で、NGINX、WordPress、MariaDBをそれぞれ専用コンテナとして分離します。

```text
Physical host
└── Virtual Machine
    └── Docker Engine
        ├── nginx
        ├── wordpress
        └── mariadb
```

コンテナは仮想マシンのLinux kernelを共有しますが、filesystem、process、network、runtime environmentはそれぞれ分離されています。

2つのDocker named volumeによって永続ストレージを提供します。

- `mariadb` → `/var/lib/mysql`
- `wordpress` → `/var/www/html`

Docker daemonのdata rootは次の場所に設定されています。

```text
/home/<login>/data/docker
```

これにより、volumeをbind mountに変換することなく、永続化されたDocker named volumeのデータを `/home/<login>/data` 配下に配置できます。

機密性のあるpasswordはDocker secretsを通して提供され、Git repositoryには保存されません。

## 実行方法

### 前提条件

このプロジェクトは、以下を備えたInception用仮想マシン内で実行することを想定しています。

- Linux
- Docker Engine
- Docker Compose
- `doas`
- 初回build時に利用できるInternet接続
- `eth0` という名前のnetwork interface

### 初回ホスト設定

repository rootから実行します。

```sh
make setup
```

この処理では、以下を設定します。

- Docker data rootを `/home/<login>/data/docker` に設定する
- `<login>.42.fr` のlocal hostname mappingを設定する

現在のプロジェクトdomainは次の通りです。

```text
sohyamaz.42.fr
```

### 必要なローカルsecret

以下のファイルが `secrets/` 配下にローカルで存在している必要があります。

```text
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

`secrets/` ディレクトリはGitの管理対象外であり、絶対にcommitしてはいけません。

### Buildと起動

```sh
make
```

Docker Composeを使ってDocker imageをbuildし、stack全体を起動します。

起動中のサービスを確認します。

```sh
make ps
```

### アクセス

Webサイト:

```text
https://sohyamaz.42.fr
```

WordPress管理画面:

```text
https://sohyamaz.42.fr/wp-admin
```

self-signed TLS certificateを使用しているため、browserに証明書警告が表示される場合があります。

HTTPの80番ポートは意図的に使用できないようになっています。

### 停止と起動

既存containerを削除せず停止します。

```sh
make stop
```

再度起動します。

```sh
make start
```

persistent volumeを残したままcontainerとnetworkを削除します。

```sh
make down
```

再buildして起動します。

```sh
make
```

### 破壊的クリーンアップ

```sh
make fclean
```

container、project image、named volumeを削除します。

named volumeにはWordPressファイルとMariaDB databaseが保存されているため、このコマンドは永続化されたapplication dataも削除します。

`make re` は `fclean` のあとに完全なrebuildを行うため、同様に永続化されたapplication dataを削除します。

## 技術選択

### Virtual Machines vs Docker

仮想マシンは、完全なmachine environmentを仮想化します。仮想化されたhardware上で、独自のguest operating systemとkernelを実行します。

Docker containerは、別の完全な仮想マシンを提供するものではありません。containerはhost Linux kernelを共有しながら、process、filesystem、network、user-space runtime environmentを分離します。

そのため、virtual machineはより強いboundaryを提供し、物理hostとは異なるoperating system kernelを実行することもできますが、比較的重い仕組みです。

containerは、serviceごとに別のkernelをbootする必要がないため軽量で、素早く作成できます。またDocker imageによって、application environmentの再現性と可搬性を高めることができます。

このプロジェクトでは、両者は異なる責務を持っています。

- **VM** はInception環境全体を物理machineから分離する
- **Docker container** はその環境内の個々のserviceを分離する

両者は異なる問題を解決する仕組みであり、一方が常にもう一方より優れているという単純な関係ではありません。

### Secrets vs Environment Variables

environment variableは、以下のような機密性のない設定に適しています。

- domain name
- database name
- username
- WordPress site setting

このプロジェクトでは、これらの値を `srcs/.env` に保存しています。

passwordは別の方法で扱います。ローカルの `secrets/` 配下にfileとして保存し、Docker secretsを通してcontainerに公開します。

container内部では、secretは `/run/secrets/` 配下のfileとして利用できます。

これにより、passwordをDockerfileやcommit対象の `.env` に直接記述することを避け、通常のenvironment inspectionから意図せず露出する可能性を減らします。

### Docker Network vs Host Network

このプロジェクトでは、`inception` という専用Docker bridge networkを使用します。

container同士は、このnetwork上でDocker service nameを使って通信します。

```text
nginx -> wordpress:9000
wordpress -> mariadb:3306
```

Docker networkingによってservice間の分離と、内部DNSによるservice discoveryが提供されます。

host networkを使う場合、containerはhostのnetwork namespaceを共有することになり、infrastructureとhostとのnetwork isolationが弱くなります。

このプロジェクトでは、host networkingは必要なく、また使用も許可されていません。

### Docker Volumes vs Bind Mounts

Docker named volumeは、Dockerによって管理されるstorageです。containerは任意のhost filesystem pathではなく、Docker-managed nameを通してvolumeを参照します。

bind mountは、特定のhost pathをcontainerへ直接mappingする方法です。

このプロジェクトでは、WordPressとMariaDBの永続化にnamed volumeを使用します。

storageを真のDocker named volumeとして維持しながら、dataを `/home/<login>/data` 配下に配置する要件を満たすため、Docker daemonのdata rootを次のように設定しています。

```text
/home/<login>/data/docker
```

その結果、volume dataはたとえば以下のDocker自身のvolume directoryに保存されます。

```text
/home/<login>/data/docker/volumes/srcs_mariadb/_data
/home/<login>/data/docker/volumes/srcs_wordpress/_data
```

したがって、これらのvolumeはbind mountではなく、Dockerによって管理されるnamed volumeのままです。

## 参考資料

このプロジェクトの実装と理解のために、以下の資料を参照しました。

- Docker Documentation — https://docs.docker.com/
- Docker Compose Documentation — https://docs.docker.com/compose/
- Docker storage documentation — https://docs.docker.com/engine/storage/
- Alpine Linux Wiki — https://wiki.alpinelinux.org/
- NGINX Documentation — https://nginx.org/en/docs/
- MariaDB Documentation — https://mariadb.com/kb/en/documentation/
- WordPress CLI Documentation — https://developer.wordpress.org/cli/commands/
- PHP-FPM documentation — https://www.php.net/manual/en/install.fpm.php
- OpenSSL Documentation — https://docs.openssl.org/

### AIの利用

このプロジェクトでは、AI toolを補助として使用しました。

主に以下の目的で使用しました。

- Docker、container、virtual machine、network、volume、TLS、process managementの概念説明
- project subjectおよびevaluation requirementの確認
- configurationやruntime problemの調査補助
- shell script、Dockerfile、Docker Compose、NGINX、MariaDB、PHP-FPMの設定方針の提案とreview
- validation commandやtest caseの設計補助
- requirement complianceの観点でrepositoryをreview
- project documentationのdraftおよびreviewの補助

AIによる提案をそのまま正しいものとして扱うことはしませんでした。configurationやcommandは確認し、project VM上で実際に実行・testし、project requirementと一致しない場合は修正しました。

実装を理解し、testし、defenseで説明する最終的な責任はproject authorにあります。
