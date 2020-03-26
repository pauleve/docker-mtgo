
TIMESTAMP=$(shell date +%F)

BASE=panard/mtgo:$(TIMESTAMP)

DOCKER=docker

image:
	make -C docker-wine $(shell grep FROM Dockerfile|cut -d: -f2)
	$(DOCKER) build -t $(BASE) .

test:
	./run-mtgo --test --reset $(BASE)

try:
	./run-mtgo $(BASE)

push:
	$(DOCKER) push $(BASE)

tag:
	git tag $(TIMESTAMP)

validate: push tag
	$(DOCKER) tag $(BASE) panard/mtgo:latest
	$(DOCKER) push panard/mtgo:latest

.PHONY: sound
sound:
	$(DOCKER) build -t panard/mtgo:sound sound/

push-sound:
	$(DOCKER) push panard/mtgo:sound

