
DOCKER=docker

custom:
	$(DOCKER) pull i386/debian:stable-slim
	#$(DOCKER) pull i386/debian:stable
	$(DOCKER) build -t panard/wine:$@ -f Dockerfile .
