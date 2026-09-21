FROM debian:bookworm

# Instala PHP-FPM, extensões essenciais e cliente MariaDB para healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
    php-fpm \
    php-mysql \
    php-curl \
    php-gd \
    php-intl \
    php-mbstring \
    php-xml \
    php-zip \
    mariadb-client \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Instala o WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Garante o diretório de execução para o socket/PID do PHP-FPM
RUN mkdir -p /run/php && chown -R www-data:www-data /run/php

# Copia a configuração do pool e o script de entrada
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/wp_setup.sh /usr/local/bin/wp_setup.sh

RUN chmod +x /usr/local/bin/wp_setup.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/wp_setup.sh"]