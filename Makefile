
TIMESTAMP=$(shell date +%F)

BASE=panard/mtgo:$(TIMESTAMP)

image:
	docker pull i386/debian:stretch-slim
	docker build -t $(BASE) .

test:
	./run-mtgo $(BASE)

push:
	docker push $(BASE)

validate: push
	docker tag $(BASE) panard/mtgo:latest
	docker push panard/mtgo:latest

