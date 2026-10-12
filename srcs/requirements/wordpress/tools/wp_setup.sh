#!/bin/bash
set -e

WP_PATH="/var/www/html"


# search for the database password and save it 
if [ -n "$WORDPRESS_DB_PASSWORD_FILE" ] && [ -f "$WORDPRESS_DB_PASSWORD_FILE" ]; then
    WORDPRESS_DB_PASSWORD=$(cat "$WORDPRESS_DB_PASSWORD_FILE")
    export WORDPRESS_DB_PASSWORD
fi
# search for the database password and save it 
if [ -n "$WORDPRESS_DB_ADMIN_PASSWORD_FILE" ] && [ -f "$WORDPRESS_DB_ADMIN_PASSWORD_FILE" ]; then
    WORDPRESS_DB_ADMIN_PASSWORD=$(cat "$WORDPRESS_DB_ADMIN_PASSWORD_FILE")
    export WORDPRESS_DB_ADMIN_PASSWORD
fi

# verify if the database name and user are in .env
if [ -z "$WORDPRESS_DB_NAME" ] || [ -z "$WORDPRESS_DB_USER" ]; then
    echo "[ERROR] Missing Environment Variables for Database"
    exit 1
fi


echo "Setting up WordPress..."

# Download and configure WordPress if not present
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    echo "Downloading WordPress..."
    wget -q https://wordpress.org/latest.tar.gz -O /tmp/wordpress.tar.gz
    tar -xzf /tmp/wordpress.tar.gz -C /tmp
    rm /tmp/wordpress.tar.gz

    # Copy only missing files (avoid overwriting existing content)
    cp -rn /tmp/wordpress/* "$WP_PATH" || true
    rm -rf /tmp/wordpress

    # Fetch security salts from WordPress API
    WP_SALTS=$(wget -qO- https://api.wordpress.org/secret-key/1.1/salt/)

    # Create wp-config.php
    cat > "$WP_PATH/wp-config.php" << EOF
    


<?php
define('DB_NAME', '${WORDPRESS_DB_NAME}');
define('DB_USER', '${WORDPRESS_DB_USER}');
define('DB_PASSWORD', '${WORDPRESS_DB_PASSWORD}');
define('DB_HOST', '${WORDPRESS_DB_HOST}');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

\$table_prefix = '${WORDPRESS_TABLE_PREFIX:-wp_}';

${WP_SALTS}

define('WP_DEBUG', false);

if ( !defined('ABSPATH') )
    define('ABSPATH', __DIR__ . '/');

require_once ABSPATH . 'wp-settings.php';
EOF

    # Set secure permissions
    find "$WP_PATH" -type d -exec chmod 755 {} \;
    find "$WP_PATH" -type f -exec chmod 644 {} \;
    chown -R www-data:www-data "$WP_PATH"
    wp core install --url="${DOMAIN_NAME}" \
                     --title="${WP_TITLE}" \
                     --admin_user="${WP_ADMIN_USER}" \
                     --admin_password="${WP_ADMIN_PASSWORD}" \
                     --admin_email="${WP_ADMIN_EMAIL}" \
                     --path="$WP_PATH" --allow-root

    echo "WordPress setup complete."
else
    echo "WordPress already initialized, skipping setup."
fi

echo "Starting PHP-FPM..."
echo "1 ${DOMAIN_NAME}"
echo "2 ${WP_TITLE}"
echo "3 ${WP_ADMIN_USER}"
echo "4 ${WORDPRESS_DB_ADMIN_PASSWORD}"
echo "5 ${WP_ADMIN_EMAIL}"
echo "6 ${WP_PATH}"
exec php-fpm8.2 -F