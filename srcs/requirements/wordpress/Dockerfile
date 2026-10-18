FROM alpine:3.23

RUN apk add --no-cache \
    php83 \
    php83-fpm \
    php83-mysqli \
    php83-curl \
    php83-dom \
    php83-mbstring \
    php83-phar \
    php83-openssl \
    php83-xml \
    php83-zip \
    php83-gd \
    mariadb-client \
    curl

RUN ln -sf /usr/bin/php83 /usr/bin/php
RUN sed -i "s/^memory_limit = .*/memory_limit = 512M/" /etc/php83/php.ini

RUN curl -o /usr/local/bin/wp \
    https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

RUN mkdir -p /var/www/html

COPY conf/www.conf /etc/php83/php-fpm.d/www.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9000

WORKDIR /var/www/html

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
