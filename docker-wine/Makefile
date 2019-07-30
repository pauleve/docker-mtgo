
DOCKER=sudo docker

custom:
	$(DOCKER) pull i386/debian:stretch-slim
	$(DOCKER) build -t panard/wine:$@ -f Dockerfile .


