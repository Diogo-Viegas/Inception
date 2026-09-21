FROM debian:bookworm

# Install MariaDB
RUN apt-get update && apt-get install -y \
    mariadb-server \
    && rm -rf /var/lib/apt/lists/*

# Criação das pastas de runtime e logs com permissões adequadas
RUN mkdir -p /run/mysqld /var/run/mysqld /var/log/mysql \
    && chown -R mysql:mysql /run/mysqld /var/run/mysqld /var/log/mysql \
    && chmod 755 /run/mysqld /var/run/mysqld /var/log/mysql

# Copy configuration
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/
COPY tools/init_db.sh /usr/local/bin/

# Set permissions
RUN chmod +x /usr/local/bin/init_db.sh


EXPOSE 3306

ENTRYPOINT ["init_db.sh"]