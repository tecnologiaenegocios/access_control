# AccessControl

## Getting started for development

### Launching a container

```
$ docker compose run --rm lib bash
```

This will pull any required Docker image and system-level dependencies and start
a `bash` prompt inside the `lib` container (the container of the source code).

Gem dependencies are installed outside the `lib` image, in a dedicated volume,
for speed.  See `docker-compose.yml` and `.docker-config/entrypoint.sh`.

### Running tests

```
$ docker compose run --rm lib bash -c 'bundle exec spec spec/'
```

If inside the `lib` container, you can just do:

```
bash-4.3#: bin/spec spec/
```
