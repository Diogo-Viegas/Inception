# Developer Documentation

This document explains how to set up, build, run and maintain the Inception project from scratch.

## 1. Prerequisites

- A Linux virtual machine (Debian recommended).
- **Docker Engine** and the **Docker Compose plugin** (`docker compose`, v2).
- **make**
- `sudo` access (needed to create and clear the data folders).
- Free port **443** on the host.

Verify the tools:

```bash
docker --version
docker compose version
make --version
```

## 2. Repository layout

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/                      # Password files (not committed)
│   ├── db_root_password.txt
│   ├── db_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env                      # Non-sensitive configuration
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/              # Dockerfile, conf/50-server.cnf, tools/init_db.sh
        ├── wordpress/            # Dockerfile, conf/, tools/
        └── nginx/                # Dockerfile, conf/
```

Adjust this tree if your layout differs.

## 3. Set up the environment from scratch

### 3.1 Domain name

Point the domain to the local machine in `/etc/hosts`:

```
127.0.0.1   dviegas.42.fr
```

### 3.2 Data folders

The named volumes store their data in these host folders, which must exist before the first run:

```bash
mkdir -p /home/dviegas/data/mariadb /home/dviegas/data/wordpress
```

### 3.3 Secrets

One password per file, with no trailing spaces, and no single quotes `'` (they are interpolated into SQL):

```bash
mkdir -p secrets
echo "your_root_password" > secrets/db_root_password.txt
echo "your_db_password"   > secrets/db_password.txt
echo "your_wp_admin_pass" > secrets/wp_admin_password.txt
echo "your_wp_user_pass"  > secrets/wp_user_password.txt
chmod 600 secrets/*.txt
```

Add `secrets/` and `srcs/.env` to `.gitignore`. No credential may be committed.

### 3.4 Environment file

Create `srcs/.env` with the non-sensitive settings:

```env
DOMAIN_NAME=dviegas.42.fr
MYSQL_DATABASE=inception_db
MYSQL_USER=inception_user
WP_DB_HOST=mariadb
WP_TITLE=Inception
WP_ADMIN_USER=<admin_name>        # must NOT contain "admin" or "administrator"
WP_ADMIN_EMAIL=<admin_email>
WP_USER=<user_name>
WP_USER_EMAIL=<user_email>
```

### 3.5 How configuration reaches the containers

| Data | Mechanism | Used by |
|---|---|---|
| Database name, usernames, domain, titles, e-mails | Environment variables from `srcs/.env` | All services |
| Passwords | Docker secrets, mounted at `/run/secrets/<name>` | MariaDB, WordPress |

Entrypoint scripts follow the `*_FILE` convention. For example, `MYSQL_ROOT_PASSWORD_FILE=/run/secrets/db_root_password` makes the script read the password from that file at startup.

## 4. Build and launch

### 4.1 With the Makefile

```bash
make            # build the images and start all containers
make down       # stop and remove the containers (data is kept)
make clean      # stop containers and remove images/volume objects
make fclean     # clean + delete the data in /home/dviegas/data
make re         # fclean, then rebuild and start
```

These target names are the usual ones. Check the real ones in your `Makefile` with `grep '^[a-zA-Z_-]*:' Makefile`.

### 4.2 With Docker Compose directly

```bash
docker compose -f srcs/docker-compose.yml up --build -d     # build and start
docker compose -f srcs/docker-compose.yml down              # stop
docker compose -f srcs/docker-compose.yml config            # validate and print the final config
```

Run `config` after any edit to the compose file. It catches YAML indentation errors and missing variables.

### 4.3 Startup order

`wordpress` depends on `mariadb`, and `nginx` depends on `wordpress`. A plain `depends_on` only waits for the container to start, not for the service to be ready. The recommended setup is a MariaDB healthcheck combined with `depends_on: condition: service_healthy`, so WordPress only starts once the database accepts connections.

## 5. Managing containers

```bash
docker compose -f srcs/docker-compose.yml ps                 # status
docker compose -f srcs/docker-compose.yml logs -f            # follow all logs
docker compose -f srcs/docker-compose.yml logs -f mariadb    # logs of one service
docker compose -f srcs/docker-compose.yml restart nginx      # restart one service
docker compose -f srcs/docker-compose.yml build --no-cache wordpress   # rebuild one image

docker exec -it mariadb bash                                 # shell in a container
docker exec -it mariadb mariadb -u root -p                   # MariaDB shell
docker exec -it wordpress ls /var/www/html                   # inspect WordPress files
docker inspect mariadb                                       # full container details
```

**Debugging tip:** `restart: always` hides crash loops. While debugging, temporarily use `restart: "no"` on the failing service to see the error in isolation, and restore it afterwards.

## 6. Managing volumes

```bash
docker volume ls                          # list volumes
docker volume inspect inception_db_data   # show the driver options and host path
docker volume inspect inception_wp_data
docker volume rm inception_db_data        # remove a volume object (containers must be removed first)
docker volume prune                       # remove unused volumes
```

Volume names are prefixed with the Compose project name (by default the folder containing the compose file), so use `docker volume ls` to see the exact names.

## 7. Where data is stored and how it persists

The project declares two **named volumes**, which store their data in folders on the host:

| Volume | Container path | Host path | Content |
|---|---|---|---|
| `db_data` | `/var/lib/mysql` | `/home/dviegas/data/mariadb` | MariaDB data files (all WordPress content, users, settings) |
| `wp_data` | `/var/www/html` | `/home/dviegas/data/wordpress` | WordPress files (core, themes, plugins, uploads) |

`wp_data` is mounted in both the `wordpress` and `nginx` containers, so NGINX can serve the static files that WordPress writes.

They are declared in `docker-compose.yml` with the `local` driver and these options:

```yaml
volumes:
  db_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/dviegas/data/mariadb
```

### Persistence rules

- Data **survives** `docker compose down`, container rebuilds, image rebuilds and VM reboots, because it lives on the host and not in the container's writable layer.
- `docker compose down -v` removes the Docker volume objects, but **does not delete the content of the host folders**.
- MariaDB initializes itself **only if its database does not already exist**. The setup SQL (database, user, root password) runs on the first start only. Changing the secret files later does not change an already-initialized database.

### Full reset

To wipe the project and start again from a clean state:

```bash
docker compose -f srcs/docker-compose.yml down -v
sudo rm -rf /home/dviegas/data/mariadb/* /home/dviegas/data/wordpress/*
docker compose -f srcs/docker-compose.yml up --build -d
```

This step is needed whenever a previous run left the database half-initialized or with a different root password, which shows up in `docker logs mariadb` as `ERROR 1045: Access denied for user 'root'@'localhost'`.

## 8. Quick verification checklist

- [ ] `docker compose -f srcs/docker-compose.yml ps` shows `mariadb`, `wordpress` and `nginx` as `Up`.
- [ ] `https://dviegas.42.fr` loads (accept the self-signed certificate).
- [ ] `http://dviegas.42.fr` (port 80) does not respond.
- [ ] Only port 443 is published: `docker ps` shows `0.0.0.0:443->443/tcp` for nginx and no ports for the others.
- [ ] `/wp-admin` login works with the admin user, whose name does not contain "admin".
- [ ] A post or comment added in WordPress is still there after `down` and `up`.
- [ ] `docker logs mariadb` shows no passwords and no errors.