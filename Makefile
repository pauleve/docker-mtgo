
TIMESTAMP=$(shell date +%F)

BASE=panard/mtgo:$(TIMESTAMP)

DOCKER=docker

image:
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
	$(DOCKER) build --build-arg BASE=$(BASE) -t panard/mtgo:sound sound/

try-sound:
	./run-mtgo --sound panard/mtgo:sound

# sound image on top of the published base image (no full rebuild)
LOCALBASE=panard/mtgo:latest
sound-local:
	$(DOCKER) build --build-arg BASE=$(LOCALBASE) -t panard/mtgo:sound-base sound/
	$(DOCKER) build -f sound/local.Dockerfile -t panard/mtgo:sound-local .

try-sound-local:
	./run-mtgo --sound panard/mtgo:sound-local

push-sound:
	$(DOCKER) push panard/mtgo:sound

