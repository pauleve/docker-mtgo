
DOCKER=docker

custom:
	$(DOCKER) pull i386/debian:testing-slim
	$(DOCKER) build -t panard/wine:$@ -f Dockerfile .


