
mkdir -p secrets

echo -n "sua_senha_mariadb_user" > secrets/db_password.txt
echo -n "sua_senha_mariadb_root" > secrets/db_root_password.txt
echo -n "sua_senha_wp_admin" > secrets/wp_admin_password.txt
echo -n "sua_senha_wp_user" > secrets/wp_user_password.txt


chmod 600 secrets/*.txt


cat << 'EOF' > ./.env
DOMAIN_NAME=dviegas.42.fr

# Base de Dados
MYSQL_DATABASE=inception_db
MYSQL_USER=inception_user

# WordPress
WP_TITLE=Inception
WP_ADMIN_USER=admin_dviegas
WP_ADMIN_EMAIL=admin@dviegas.42.fr
WP_USER=author_dviegas
WP_USER_EMAIL=author@dviegas.42.fr
EOF