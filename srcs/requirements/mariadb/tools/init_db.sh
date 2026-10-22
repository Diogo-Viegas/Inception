#!/bin/bash

set -e

echo "Starting MariaDB initialization..."
if [ -n "$MYSQL_PASSWORD_FILE" ] && [ -f "$MYSQL_PASSWORD_FILE" ]; then
    MYSQL_PASSWORD=$(cat "$MYSQL_PASSWORD_FILE")
    export MYSQL_PASSWORD
fi
if [ -n "$MYSQL_ROOT_PASSWORD_FILE" ] && [ -f "$MYSQL_ROOT_PASSWORD_FILE" ]; then
    MYSQL_ROOT_PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE")
    export MYSQL_ROOT_PASSWORD
fi

mkdir -p /run/mysqld
chown -R mysql:mysql /var/lib/mysql /run/mysqld

# Initialize MySQL data directory if it doesn't exist
if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
    echo "First Run: Initializing MariaDB..."

    if [ ! -d "/var/lib/mysql/mysql"]; then
        mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
    fi

    mysqld --skip-networking --socket=/run/mysqld/mysqld.sock --user=mysql &
    pid="$!"
    
    until mysqladmin --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; do
        sleep 1
    done
    mysql --socket=/run/mysqld/mysqld.sock -u root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    mysqladmin --socket=/run/mysqld/mysqld.sock -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

    # Wait for shutdown
    wait "$pid" || true
    echo "Initialization complete. Starting MariaDB..."
else
    echo "MariaDB already initialized, skipping..."
fi

exec mysqld --user=mysql --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock