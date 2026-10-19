FROM debian:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/*
 
COPY conf/static.conf /etc/nginx/sites-enabled/default
COPY site/ /var/www/html/
 
EXPOSE 80
 
CMD ["nginx", "-g", "daemon off;"]
