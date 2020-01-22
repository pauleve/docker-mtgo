
DOCKER=sudo docker

custom:
	$(DOCKER) pull i386/debian:stable-slim
	$(DOCKER) build -t panard/wine:$@ -f Dockerfile .


