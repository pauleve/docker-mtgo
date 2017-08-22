
TIMESTAMP=$(shell date +%F)
BASE=mtgo:base

base:
	docker build -t mtgo:base -t panard/base-$(TIMESTAMP) .

run-base:
	./run-mtgo --name mtgo_base $(BASE)

commit-base:
	docker commit mtgo_base mtgo:test

validate-base:
	docker tag $(BASE) panard/mtgo:base

push-base:
	docker push panard/mtgo:base
	docker push panard/mtgo:base-$(TIMESTAMP)

validate-test:
	docker tag mtgo:test panard/mtgo:latest

push-latest:
	docker push panard/mtgo:latest

validate-all: validate-base validate-test
push-all: push-base push-latest

