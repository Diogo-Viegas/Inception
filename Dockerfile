FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Cria explicitamente as pastas antes de gerar os certificados
RUN mkdir -p /etc/nginx/ssl /var/run/nginx

# Gera a chave e o certificado numa linha contínua e robusta
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/C=PT/ST=Lisboa/L=Lisboa/O=42/OU=Student/CN=login.42.fr"

COPY conf/nginx.conf /etc/nginx/conf.d/default.conf

# Cria pasta e ficheiro temporário para teste isolado
RUN mkdir -p /var/www/html && echo "<h1>NGINX a funcionar com TLS!</h1>" > /var/www/html/index.html

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]