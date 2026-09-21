#!/bin/bash
set -e

# Lê segredos se existirem
if [ -f "/run/secrets/db_password" ]; then
    MYSQL_PASSWORD=$(cat /run/secrets/db_password)
fi
if [ -f "/run/secrets/wp_admin_password" ]; then
    WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
fi
if [ -f "/run/secrets/wp_user_password" ]; then
    WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)
fi

mkdir -p /var/www/html
chown -R www-data:www-data /var/www/html
cd /var/www/html

# Aguarda até o MariaDB aceitar conexões TCP (sem exigir autenticação para o ping)
echo "[INFO] A aguardar pelo serviço MariaDB..."
while ! mariadb-admin ping -h"mariadb" --silent; do
    sleep 2
done

# Só instala se o ficheiro de configuração ainda não existir
if [ ! -f "wp-config.php" ]; then
    echo "[INFO] A descarregar e configurar WordPress via WP-CLI..."
    wp core download --allow-root

    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="mariadb:3306" \
        --allow-root

    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --role=author \
        --user_pass="${WP_USER_PASSWORD}" \
        --allow-root
fi

echo "[INFO] A arrancar o PHP-FPM em primeiro plano (PID 1)..."
exec php-fpm8.2 -F