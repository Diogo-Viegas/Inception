*This project has been created as part of the 42 curriculum by dviegas.*

# Inception

## Description

**Inception** is a system administration project from the 42 curriculum. Its goal is to build a small but complete web infrastructure using **Docker** and **Docker Compose**, running inside a virtual machine. Every service is built from a custom `Dockerfile` based on Debian (no pre-built service images such as `wordpress`,`nginx`or `mariadb` from Docker Hub).

The stack is made of three containers:

| Service | Role | Exposed to |
|---|---|---|
| **NGINX** | Reverse proxy and the only entry point. Serves HTTPS with TLS (port 443). | Host (port 443) |
| **WordPress + PHP-FPM** | The WordPress application, run by PHP-FPM (port 9000). | Internal network only |
| **MariaDB** | The relational database used by WordPress (port 3306). | Internal network only |

Data is persisted in two volumes: the WordPress database and the WordPress website files.

```
                 Internet / Host
                       |
                   :443 (TLS)
                       |
                 +-----------+
                 |   NGINX   |
                 +-----------+
                       |  FastCGI :9000
                 +-----------+
                 | WordPress |
                 | (PHP-FPM) |
                 +-----------+
                       |  SQL :3306
                 +-----------+
                 |  MariaDB  |
                 +-----------+

        All containers share the "inception_net" bridge network.
```

### Project structure

```
.
├── Makefile
├── README.md
├── secrets/                  # Password files (never committed)
│   ├── db_root_password.txt
│   ├── db_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env                  # Non-sensitive configuration (never commited)
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/          # Dockerfile, conf/, tools/init_db.sh
        ├── wordpress/        # Dockerfile, conf/, tools/
        └── nginx/            # Dockerfile, conf/, tools/
```

### Main design choices

- **One service per container**, each with its own `Dockerfile`, built from `debian:bookworm-slim` (a pinned tag, never `latest`).
- **Each server runs as PID 1** in the foreground (`exec mysqld`, `php-fpm -F`, `nginx -g 'daemon off;'`), with no `tail -f`, `sleep infinity` or other hacks to keep the container alive.
- **TLS only**: NGINX accepts TLSv1.2 / TLSv1.3 on port 443. Port 80 is not exposed.
- **Idempotent MariaDB initialization**: the entrypoint script (`init_db.sh`) only creates the database, the user and the root password on the first run. Later restarts skip straight to starting the server, so the container never fails because the root password is already set.
- **Secrets for passwords, environment variables for everything else.** No password is hardcoded in a `Dockerfile` or committed to Git.
- **Dedicated bridge network**, so containers resolve each other by name (`mariadb`, `wordpress`) and only NGINX publishes a port.
- **`restart: always`** so that services come back after a crash or a reboot.

### Virtual Machines vs Docker

| | Virtual Machine | Docker container |
|---|---|---|
| **Isolation** | Full hardware virtualization with its own guest kernel, which gives strong isolation. | Process-level isolation through namespaces and cgroups, sharing the host kernel. |
| **Size** | Gigabytes (full OS image). | Megabytes (only the userland needed). |
| **Startup time** | Tens of seconds to minutes. | Usually a second or less. |
| **Resource usage** | High: each VM reserves RAM and CPU for a whole OS. | Low: containers only use what their processes need. |
| **Portability** | Heavy disk images, hypervisor-dependent. | Images are small, layered and reproducible from a `Dockerfile`. |
| **Best for** | Running different operating systems, strong security boundaries. | Packaging and deploying applications and microservices consistently. |

In this project, a VM is the host that runs Docker, and Docker runs the services in lightweight, reproducible containers inside it.

### Secrets vs Environment Variables

| | Environment variables | Docker secrets |
|---|---|---|
| **Storage** | Part of the container's configuration. | Files mounted read-only at `/run/secrets/<name>` (in memory). |
| **Visibility** | Visible in `docker inspect`, in `/proc/<pid>/environ`, may leak into logs or child processes. | Not shown in `docker inspect` and not inherited by child processes. |
| **Best for** | Non-sensitive config (database name, usernames, domain name). | Passwords and any sensitive value. |

Here, passwords are stored in `secrets/*.txt` and passed to the containers through the `*_FILE` convention (for example `MYSQL_ROOT_PASSWORD_FILE=/run/secrets/db_root_password`). The entrypoint scripts read the file content at startup. Non-sensitive values (`MYSQL_DATABASE`, `MYSQL_USER`, `DOMAIN_NAME`, ...) live in `srcs/.env`.

### Docker Network vs Host Network

| | Docker (bridge) network | Host network |
|---|---|---|
| **Isolation** | Containers get their own network namespace and private IPs. | The container shares the host's network stack directly. |
| **Port exposure** | Only explicitly published ports (`ports:`) are reachable from outside. | Every port the process opens is exposed on the host. |
| **Service discovery** | Built-in DNS: containers reach each other by service name. | None; everything is `localhost`. |
| **Port conflicts** | Avoided; two containers can use the same internal port. | Possible, since all share the host's ports. |

This project uses a user-defined **bridge network** (`inception_net`). MariaDB (`expose: 3306`) and WordPress (`expose: 9000`) are reachable only from inside that network. Only NGINX publishes a port (`443:443`). `network_mode: host` and `links` are not used.

### Docker Volumes vs Bind Mounts

| | Named volumes | Bind mounts |
|---|---|---|
| **Managed by** | Docker (stored under `/var/lib/docker/volumes/`). | The user: a host path is mapped directly into the container. |
| **Declaration** | In the top-level `volumes:` section, with a name. | As a path in the service definition (`./data:/var/lib/mysql`). |
| **Portability** | Independent of the host directory layout. | Depends on the host's directory structure and permissions. |
| **Permissions** | Initialized by Docker. | Inherit the host folder's owner and mode (a common source of errors). |
| **Best for** | Persistent data of production-like services (databases). | Development, sharing source code or config with a container. |

The subject requires **named volumes** for the two persistent storages, and bind mounts for them are not allowed. Services therefore reference named volumes only (`db_data:/var/lib/mysql`, `wp_data:/var/www/html`). Because the subject also requires the data to live under `/home/<login>/data`, the named volumes are declared with the `local` driver and `driver_opts` pointing to that folder:

```yaml
volumes:
  db_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/dviegas/data/mariadb
```

They are real Docker volumes (visible with `docker volume ls`) whose storage location is `/home/dviegas/data/`. Note that `docker compose down -v` removes the volume object but does **not** delete the host folder's contents.

## Instructions

### Prerequisites

- A Linux virtual machine (Debian recommended) with:
  - Docker Engine and the Docker Compose plugin
  - `make`
  - `sudo` access
- The domain name resolving to your local IP. Add this line to `/etc/hosts`, replacing the domain with the one set in `srcs/.env`:

  ```
  127.0.0.1   dviegas.42.fr
  ```

### Configuration

1. Create the data folders used by the volumes:

   ```bash
   mkdir -p /home/dviegas/data/mariadb /home/dviegas/data/wordpress
   ```

2. Create the secret files (one password per file, with no trailing spaces, and avoid single quotes `'` since they are interpolated into SQL):

   ```bash
   mkdir -p secrets
   echo "your_root_password"  > secrets/db_root_password.txt
   echo "your_db_password"    > secrets/db_password.txt
   echo "your_wp_admin_pass"  > secrets/wp_admin_password.txt
   echo "your_wp_user_pass"   > secrets/wp_user_password.txt
   chmod 600 secrets/*.txt
   ```

3. Create `srcs/.env` with the non-sensitive settings:

   ```env
   DOMAIN_NAME=dviegas.42.fr
   MYSQL_DATABASE=inception_db
   MYSQL_USER=inception_user
   WP_DB_HOST=mariadb
   WP_TITLE=Inception
   WP_ADMIN_USER=<admin_name>
   WP_ADMIN_EMAIL=<admin_email>
   WP_USER=<user_name>
   WP_USER_EMAIL=<user_email>
   ```

   > The WordPress administrator username must **not** contain `admin` or `administrator` (for example, `admin123`, `administrator` or `Admin` are forbidden).

### Build and run

```bash
make            # build the images and start all containers
```

Or, directly with Docker Compose:

```bash
docker compose -f srcs/docker-compose.yml up --build -d
```

Then open **https://dviegas.42.fr** in your browser. The TLS certificate is self-signed, so the browser will show a warning that you must accept.

### Useful commands

```bash
docker compose -f srcs/docker-compose.yml ps         # container status
docker compose -f srcs/docker-compose.yml logs -f    # follow logs
docker logs mariadb                                  # logs of one container
docker exec -it mariadb mariadb -u root -p           # open a MariaDB shell
docker volume ls                                     # list volumes
docker volume inspect inception_db_data              # inspect where data is stored
docker compose -f srcs/docker-compose.yml down       # stop and remove containers
```

### Resetting everything

The database is only initialized when its data folder is empty. To start from scratch:

```bash
docker compose -f srcs/docker-compose.yml down -v
sudo rm -rf /home/dviegas/data/mariadb/* /home/dviegas/data/wordpress/*
```

## Resources

### Documentation and references

- [Docker documentation](https://docs.docker.com/)
- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/)
- [Docker Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Docker Compose: secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Docker networking overview](https://docs.docker.com/engine/network/)
- [Docker storage: volumes and bind mounts](https://docs.docker.com/engine/storage/)
- [Best practices for writing Dockerfiles](https://docs.docker.com/build/building/best-practices/)
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/documentation/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [NGINX: configuring HTTPS servers](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [WordPress developer resources](https://developer.wordpress.org/)
- [WP-CLI handbook](https://make.wordpress.org/cli/handbook/)
- [Inception Tutorial](https://dev.to/alejiri/docker-nginx-wordpress-mariadb-tutorial-inception42-1eok?ct=1791885494414)

### Use of AI

AI (Claude, by Anthropic) was used as a support tool for the following tasks:

- **Debugging the MariaDB container:** analyzing the restart-loop logs (`ERROR 1045: Access denied for user 'root'@'localhost'`) and identifying that the setup SQL ran on every start even though the root password had already been set.
- **Rewriting the MariaDB entrypoint script** (`init_db.sh`) to make initialization idempotent, handle permissions on the data directory at runtime, and stop printing passwords to the logs.
- **Reviewing `docker-compose.yml`:** spotting a missing `WP_USER_PASSWORD_FILE`, suggesting a healthcheck with `depends_on: condition: service_healthy`, and clarifying how named volumes with `driver_opts` relate to the subject's volume rules.
- **Drafting this README**, including the comparison sections.-
- **Designing and Generating**, html and css for the static website bonus.

All AI-generated suggestions were reviewed, tested and adapted by the author, who is able to explain every part of the project.