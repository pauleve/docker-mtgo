
staging:
	docker build -t mtgo:staging .

prepare-staging:
	./run-mtgo --name mtgo_staging mtgo:staging

commit-staging:
	docker commit mtgo_staging mtgo:test

validate-test:
	docker tag mtgo:test panard/mtgo:latest
	docker tag mtgo:test panard/mtgo:$(shell date +%F)
	docker tag mtgo:staging panard/mtgo:staging
	docker tag mtgo:staging panard/mtgo:staging-$(shell date +%F)

push:
	docker push panard/mtgo:staging
	docker push panard/mtgo:staging-$(shell date +%F)
	docker push panard/mtgo:latest
	docker push panard/mtgo:$(shell date +%F)

