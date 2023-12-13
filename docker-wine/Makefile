
DOCKER=docker

custom64:
	$(DOCKER) pull debian:stable-slim
	$(DOCKER) pull debian:stable
	#$(DOCKER) pull i386/debian:stable
	$(DOCKER) build -t panard/wine:$@ -f Dockerfile .
