#!/bin/bash
set -e

#path where the passwords are located
DB_PASSWORD_FILE="${MYSQL_PASSWORD_FILE:-/run/secrets/db_password}"
DB_ROOT_PASSWORD_FILE="${MYSQL_ROOT_PASSWORD_FILE:-/run/secrets/db_root_password}"

#if the files containing the passwords exists, stores the values 
if [ -f "$DB_PASSWORD_FILE" ]; then
    DB_PASSWORD="$(cat "$DB_PASSWORD_FILE")"
fi
if [ -f "$DB_ROOT_PASSWORD_FILE" ]; then
    DB_ROOT_PASSWORD="$(cat "$DB_ROOT_PASSWORD_FILE")"
fi
#creates the directory for the MySQL socket and for the data,if they dont exist
mkdir -p /run/mysqld /var/lib/mysql
#ensure that the server has the right permissions to read and write
chown -R mysql:mysql /run/mysqld /var/lib/mysql

#first execution
# 1 - Executes the command to the standard instalation to create 
# the inicial table structure, ignoring test databases and not show excessive outputs
# 2 - SQL CONFIG SCRIPT
#  -> Define the path to a temp .sql file that will apply the initial configs
#  =============== INIT_FILE =================
#  -> DEFINE ROOT PASSWORD
#  -> CREATE DATABASE $MYSQL_DATABASE
#  -> CREATE A PERSONALIZED USER WITH ACESS FROM ANY HOST (%) or localhost
#  -> CONCEDES ALL THE PRIVILEGES
#  -> APPLY THE CHANGES
#  -> CHANGE THE GROUP OF THE TEMP FILE
#  -> STARTS THE MARIADB SERVER WITH THE INIT_FILE
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "[mariadb] First Execution: Starting Database..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db > /dev/null

    INIT_FILE="/tmp/init.sql"
    cat <<EOF > "$INIT_FILE"
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'\%' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    chown mysql:mysql "$INIT_FILE"
    exec mariadbd --user=mysql --init-file="$INIT_FILE"
fi

echo "[mariadb] Starting the server..."
exec mariadbd --user=mysql