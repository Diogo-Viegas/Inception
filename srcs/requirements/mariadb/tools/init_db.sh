#!/bin/bash
set -e

# Lê segredos se existirem via ficheiro (Secrets da 42), senão usa variáveis normais
if [ -f "/run/secrets/db_root_password" ]; then
    MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
fi
if [ -f "/run/secrets/db_password" ]; then
    MYSQL_PASSWORD=$(cat /run/secrets/db_password)
fi

# Inicializa as tabelas apenas na primeira vez
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "[INFO] A inicializar as tabelas do MariaDB..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null

    # Cria o ficheiro temporário com comandos SQL
    INIT_FILE="/tmp/init.sql"
    cat <<EOF > "$INIT_FILE"
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'\%' IDENTIFIED BY '${MYSQL_PASSWORD}';
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

    chown mysql:mysql "$INIT_FILE"

    # Arranca o daemon em PID 1 consumindo o script de inicialização
    exec mariadbd --user=mysql --init-file="$INIT_FILE"
fi

# Se a pasta já existir, corre o MariaDB normalmente
exec mariadbd --user=mysql