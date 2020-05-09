
DOCKER=docker

custom:
	$(DOCKER) pull i386/debian:testing-slim
	$(DOCKER) pull i386/debian:testing
	$(DOCKER) build -t panard/wine:$@ -f Dockerfile .


