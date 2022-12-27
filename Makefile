.PHONY: run rebuild tests

run:
	docker compose run --rm -it lib bash

rebuild:
	docker compose down -v --rmi local
	make run

tests:
	docker compose run --rm lib bash -c 'bundle exec spec spec/'
