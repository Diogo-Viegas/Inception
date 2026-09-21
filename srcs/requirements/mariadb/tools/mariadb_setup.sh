#!/bin/bash
set -e

# Lê passwords de ficheiros de secrets se existirem
if [ -f "/run/secrets/db_root_password" ]; then
    MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
fi
if [ -f "/run/secrets/db_password" ]; then
    MYSQL_PASSWORD=$(cat /run/secrets/db_password)
fi

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# Inicializa as tabelas de sistema se for a primeira execução
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

# Cria o ficheiro de comandos SQL temporário para arranque
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

# O comando exec inicia o MariaDB diretamente com o ficheiro de inicialização
# Isto assegura o PID 1 e aplica os utilizadores no primeiro arranque
exec mariadbd --user=mysql --init-file="$INIT_FILE"