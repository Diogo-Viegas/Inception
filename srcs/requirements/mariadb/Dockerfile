# Imagem base: Debian (versão penúltima estável), sem tag "latest"
FROM debian:bookworm-slim

# Instala o servidor MariaDB sem pacotes recomendados supérfluos
RUN apt-get update && \
    apt-get install -y --no-install-recommends mariadb-server && \
    rm -rf /var/lib/apt/lists/*

# Configuração personalizada do servidor
COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Script de arranque/inicialização
COPY tools/init_db.sh /usr/local/bin/setup.sh
RUN chmod +x /usr/local/bin/setup.sh && \
    mkdir -p /run/mysqld && \
    chown -R mysql:mysql /run/mysqld /var/lib/mysql

EXPOSE 3306

# O script termina sempre com "exec mariadbd", tornando o próprio
# processo do servidor o PID 1 do container (sem daemonizar, sem tail -f)
ENTRYPOINT ["/usr/local/bin/setup.sh"]