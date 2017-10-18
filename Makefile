
TIMESTAMP=$(shell date +%F)

BASE=panard/mtgo:$(TIMESTAMP)

image:
	make -C docker-wine $(shell grep FROM Dockerfile|cut -d: -f2)
	docker build -t $(BASE) .

test:
	./run-mtgo $(BASE)

push:
	docker push $(BASE)

validate: push
	docker tag $(BASE) panard/mtgo:latest
	docker push panard/mtgo:latest

