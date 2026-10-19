FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    wget \
    php  \
    php-mysqli \
    php-cli \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

RUN wget -O index.php https://www.adminer.org/latest.php

RUN chown -R www-data:www-data /var/www/html

EXPOSE 8080

CMD ["php", "-S", "0.0.0.0:8080", "-t", "/var/www/html"]