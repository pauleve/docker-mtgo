
DOCKER=sudo docker

custom vanilla:
	$(DOCKER) pull i386/debian:stretch-slim
	$(DOCKER) build -t panard/wine:$@ -f Dockerfile.$@ .


