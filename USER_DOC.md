# User Documentation

This guide explains how to use the Inception stack as an end user or administrator, without needing to know how it is built.

## 1. What services are provided

The stack runs three services, each in its own Docker container:

| Service | What it does | Reachable from |
|---|---|---|
| **NGINX** | The web server. It is the only entry point and serves the website securely over HTTPS (port 443). | Your browser |
| **WordPress** (with PHP-FPM) | The website itself and its administration panel. | Only through NGINX |
| **MariaDB** | The database that stores the website's content, users and settings. | Only from WordPress |

You only ever talk to NGINX. WordPress and MariaDB are not exposed outside the stack.

## 2. Start and stop the project

All commands are run from the root of the repository.

**Start** (builds the images the first time):

```bash
make
```

**Stop** (containers are removed, your data is kept):

```bash
make down
```

**Start again** after stopping:

```bash
make up
```

The equivalent Docker Compose commands are:

```bash
docker compose -f srcs/docker-compose.yml up --build -d    # start
docker compose -f srcs/docker-compose.yml down             # stop
```

Stopping the stack does **not** delete the website or the database. They are stored in persistent volumes (see section 4).

## 3. Access the website and the administration panel

Before the first use, make sure your machine resolves the domain name. Add this line to `/etc/hosts` (replace the domain with the one in `srcs/.env`):

```
127.0.0.1   dviegas.42.fr
```

| What | Address |
|---|---|
| Website | https://dviegas.42.fr |
| Administration panel | https://dviegas.42.fr/wp-admin |

**Certificate warning:** the site uses a self-signed TLS certificate, so the browser will warn you that the connection is not trusted. This is expected. Choose "Advanced" and continue to the site.

Only HTTPS is available. `http://` (port 80) is not served.

## 4. Locate and manage credentials

### Where they are

| Credential | Location |
|---|---|
| Database root password | `secrets/db_root_password.txt` |
| Database user password | `secrets/db_password.txt` |
| WordPress administrator password | `secrets/wp_admin_password.txt` |
| WordPress regular user password | `secrets/wp_user_password.txt` |
| Usernames, e-mails, domain name, database name | `srcs/.env` |

The WordPress administrator username is the value of `WP_ADMIN_USER` in `srcs/.env`. Log in at `/wp-admin` with that username and the password from `secrets/wp_admin_password.txt`.

### How to manage them

- Keep the `secrets/` folder private. It must **never** be committed to Git (it should be listed in `.gitignore`).
- Restrict access to the files: `chmod 600 secrets/*.txt`.
- Do not use single quotes (`'`) in passwords, because they would break the database setup.
- **Changing the WordPress passwords:** do it from the WordPress admin panel (Users → Profile). Editing the file alone does not update an existing site.
- **Changing the database passwords:** the database is initialized only once, so editing the secret files after the first start has no effect on the existing database. To apply new database passwords, the data must be reset (this deletes the site data):

  ```bash
  make down
  sudo rm -rf /home/dviegas/data/mariadb/* /home/dviegas/data/wordpress/*
  make
  ```

## 5. Check that the services are running correctly

**1. Container status.** All three containers should be listed as `Up`:

```bash
docker compose -f srcs/docker-compose.yml ps
```

Expected containers: `mariadb`, `wordpress`, `nginx`.

**2. The website responds.** The `-k` flag accepts the self-signed certificate:

```bash
curl -kI https://dviegas.42.fr
```

You should get an `HTTP/1.1 200 OK` (or a `301/302` redirect to the same site).

**3. The database is reachable.** Ask MariaDB to answer a ping (you will be asked for the root password):

```bash
docker exec -it mariadb mariadb-admin -u root -p ping
```

The expected answer is `mysqld is alive`.

**4. Look at the logs** if something seems wrong:

```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

**5. HTTP is not exposed.** This request should fail to connect:

```bash
curl -I http://dviegas.42.fr
```

### Common problems

| Symptom | What to try |
|---|---|
| Browser cannot find the site | Check the `/etc/hosts` entry and that the domain matches `DOMAIN_NAME` in `srcs/.env`. |
| "Error establishing a database connection" | Check `docker logs mariadb`. Make sure MariaDB is `Up` and not restarting in a loop. |
| A container keeps restarting | Run `docker logs <name>` to see the error. |
| Cannot log in to `/wp-admin` | Check the username in `srcs/.env` and the password in `secrets/wp_admin_password.txt`. |