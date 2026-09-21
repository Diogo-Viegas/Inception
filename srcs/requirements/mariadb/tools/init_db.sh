#!/bin/bash
set -e

# --- Localização das secrets (montadas pelo Docker em /run/secrets) ---
DB_PASSWORD_FILE="${MYSQL_PASSWORD_FILE:-/run/secrets/db_password}"
DB_ROOT_PASSWORD_FILE="${MYSQL_ROOT_PASSWORD_FILE:-/run/secrets/db_root_password}"

if [ ! -f "$DB_PASSWORD_FILE" ] || [ ! -f "$DB_ROOT_PASSWORD_FILE" ]; then
    echo "[mariadb] Erro: secrets nao encontradas em /run/secrets." >&2
    exit 1
fi

DB_PASSWORD="$(cat "$DB_PASSWORD_FILE")"
DB_ROOT_PASSWORD="$(cat "$DB_ROOT_PASSWORD_FILE")"

# --- Variáveis não-sensíveis, vindas do .env / docker-compose.yml ---
: "${MYSQL_DATABASE:?A variavel MYSQL_DATABASE tem de estar definida}"
: "${MYSQL_USER:?A variavel MYSQL_USER tem de estar definida}"

# --- Inicialização (só corre uma vez, graças ao volume nomeado) ---
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "[mariadb] Primeira execução: a inicializar a base de dados..."

    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql \
        --skip-test-db \
        > /dev/null

    # Arranque temporário, apenas por socket local, para configurar a BD
    mariadbd --user=mysql --skip-networking --socket=/run/mysqld/mysqld.sock &
    tmp_pid="$!"

    for i in $(seq 1 30); do
        if mysqladmin --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    mysql --socket=/run/mysqld/mysqld.sock -u root <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
        DELETE FROM mysql.user WHERE User='';
        DROP DATABASE IF EXISTS test;
        FLUSH PRIVILEGES;
EOSQL

    mysqladmin --socket=/run/mysqld/mysqld.sock -u root -p"${DB_ROOT_PASSWORD}" shutdown
    wait "$tmp_pid" 2>/dev/null || true

    echo "[mariadb] Base de dados inicializada com sucesso."
else
    echo "[mariadb] Base de dados já existente (volume persistente), a arrancar."
fi

# --- Arranque final: mariadbd fica como PID 1, em primeiro plano ---
echo "[mariadb] A arrancar o servidor..."
exec mariadbd --user=mysql