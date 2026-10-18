FROM alpine:3.23

RUN apk add --no-cache nginx openssl
RUN sed -i "s/TLSv1.1 TLSv1.2 TLSv1.3/TLSv1.2 TLSv1.3/" /etc/nginx/nginx.conf

RUN mkdir -p /run/nginx /etc/nginx/ssl

COPY conf/default.conf /etc/nginx/http.d/default.conf
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
