
TIMESTAMP=$(shell date +%F)

wine-mtgo:
	docker pull i386/debian:stretch-slim
	docker build -t panard/wine:mtgo-$(TIMESTAMP) -t panard/wine:mtgo .

push:
	docker push panard/wine:mtgo-$(TIMESTAMP)
	docker push panard/wine:mtgo

