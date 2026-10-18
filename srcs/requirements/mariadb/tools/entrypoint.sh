#!/bin/sh

set -eu

DB_PASSWORD="$(cat /run/secrets/db_password)"
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"

if [ ! -d "/var/lib/mysql/mysql" ]; then
    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql \
        --auth-root-authentication-method=normal

    mariadbd \
        --user=mysql \
        --datadir=/var/lib/mysql \
        --skip-networking &

    pid="$!"

    until mariadb-admin \
        --socket=/run/mysqld/mysqld.sock \
        ping --silent
    do
        sleep 1
    done

    mariadb --socket=/run/mysqld/mysqld.sock <<SQL
ALTER USER 'root'@'localhost'
    IDENTIFIED BY '${DB_ROOT_PASSWORD}';

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%'
    IDENTIFIED BY '${DB_PASSWORD}';

GRANT ALL PRIVILEGES
    ON \`${MYSQL_DATABASE}\`.*
    TO '${MYSQL_USER}'@'%';

FLUSH PRIVILEGES;
SQL

    mariadb-admin \
        --socket=/run/mysqld/mysqld.sock \
        -uroot \
        -p"${DB_ROOT_PASSWORD}" \
        shutdown

    wait "$pid"
fi

exec mariadbd \
    --user=mysql \
    --datadir=/var/lib/mysql \
    --console
