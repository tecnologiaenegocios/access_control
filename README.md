# AccessControl

## Getting started for development

```
$ docker compose up --build -d
```

This will create a `lib` container for the gem files and a `db` container for
MariaDB, used as a test database.  Check if the database container was started
with:

```
$ docker compose ps
NAME                 IMAGE ...          SERVICE ... STATUS
access_control-db-1  mariadb:latest ... db ...      Up ...
```

## Running tests

```
$ docker compose run --rm lib bash
```

This will launch `bash` inside the `lib` container.  Then run Rspec with:

```
bash-4.3: bin/spec spec/
```
