
staging:
	docker build -t mtgo:staging .
	./run.sh mtgo:staging --name mtgo_staging

commit-staging:
	docker commit mtgo_staging mtgo:test

validate-test:
	docker tag mtgo:test panard/mtgo:latest
	docker tag mtgo:test panard/mtgo:$(shell date +%F)

