#!/bin/sh

set -eu

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

until mariadb \
    -h mariadb \
    -u"${MYSQL_USER}" \
    -p"${DB_PASSWORD}" \
    "${MYSQL_DATABASE}" \
    -e "SELECT 1;" >/dev/null 2>&1
do
    sleep 1
done

if [ ! -f /var/www/html/wp-load.php ]; then
    wp core download \
        --path=/var/www/html \
        --allow-root
fi

if [ ! -f /var/www/html/wp-config.php ]; then
    wp config create \
        --path=/var/www/html \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="mariadb:3306" \
        --allow-root
fi

if ! wp core is-installed \
    --path=/var/www/html \
    --allow-root
then
    wp core install \
        --path=/var/www/html \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root
fi

if ! wp user get "${WP_USER}" \
    --path=/var/www/html \
    --allow-root >/dev/null 2>&1
then
    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}" \
        --path=/var/www/html \
        --allow-root
fi

chown -R nobody:nobody /var/www/html

exec php-fpm83 -F
