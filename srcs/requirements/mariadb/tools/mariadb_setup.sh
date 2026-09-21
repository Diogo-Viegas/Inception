#!/bin/bash
set -e

#LE PASSWORDS DE FICHEIROS SECRET SE EXISTIREM
if [ -f "/run/secrets/db_root_password" ]; then
    MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
fi 
if [ -f "/run/secrets/db_password" ]; then
    MYSQL_PASSWORD=$(cat /run/secrets/db_password)
fi 

#GARANTE QUE AS PASTAS DO RUNTIME E SOCKETS EXISTEM COM AS PERMISSOES CORRETAS
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

#INICIA AS TABELAS DE SISTEMA NA PRIMEIRA INICIALIZACAO
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql

#INICIA O DAEMON TEMPORARIAMENTE EM BACKGROUND PARA INJETAR COMNADOS SQL DE CRIACAO
    mariadbd-safe --datadir=/var/lib/mysql &

    #ESPERA ATE O SOCKET ESTAR ATIVO E PRONTO
    while ! mysqladminp ping --silent; do
        sleep 1
    done

    #CRIACAO DO USER DA BD E DO ROOT PROTEGIDO
    # Criação do utilizador da base de dados e do root protegido
    mariadb -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'\%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    # Encerra o servidor temporário de bootstrap
    mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
fi

# O comando 'exec' substitui a shell atual pelo binário final do MariaDB, garantindo o PID 1
exec mariadbd-safe --datadir=/var/lib/mysql