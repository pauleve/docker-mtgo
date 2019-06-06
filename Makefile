
TIMESTAMP=$(shell date +%F)

BASE=panard/mtgo:$(TIMESTAMP)

DOCKER=sudo docker

image:
	make -C docker-wine $(shell grep FROM Dockerfile|cut -d: -f2)
	$(DOCKER) build -t $(BASE) .

test:
	./run-mtgo --test --reset $(BASE)

try:
	./run-mtgo $(BASE)

push:
	$(DOCKER) push $(BASE)

validate: push
	$(DOCKER) tag $(BASE) panard/mtgo:latest
	$(DOCKER) push panard/mtgo:latest

