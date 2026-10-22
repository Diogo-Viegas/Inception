
mkdir -p secrets

echo -n "password" > secrets/db_password.txt
echo -n "password" > secrets/db_root_password.txt
echo -n "password" > secrets/wp_admin_password.txt
echo -n "password" > secrets/wp_user_password.txt


chmod 600 secrets/*.txt


cat << 'EOF' > ./.env
DOMAIN_NAME=dviegas.42.fr

# Base de Dados
MYSQL_DATABASE=inception_db
MYSQL_USER=inception_user

# WordPress
WP_TITLE=Inception
WP_ADMIN_USER=master
WP_ADMIN_EMAIL=master@dviegas.42.fr
WP_USER=dviegas
WP_USER_EMAIL=user@dviegas.42.fr
WP_DB_HOST=mariadb
EOF