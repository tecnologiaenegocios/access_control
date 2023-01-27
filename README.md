# AccessControl

## Getting started for development

### Launching a container

```
$ make run
bash-4.3#:
```

This will pull any required Docker image and system-level dependencies and start
a `bash` prompt inside the `lib` container (the container of the source code).

Gem dependencies are installed outside the `lib` image, in a dedicated volume,
for speed.  See `docker-compose.yml` and `.docker-config/entrypoint.sh`.

Use the `rebuild` task to rebuild images:

```
$ edit Dockerfile # or docker-compose.yml
$ make rebuild
bash-4.3#:
```

### Running tests

```
$ make tests
```

If inside the `lib` container (through `make run`), you can just do:

```
bash-4.3#: bin/spec spec/
```
