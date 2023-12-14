
DOCKER=docker

wow64:
	$(DOCKER) buildx build --platform linux/amd64,linux/arm64/v8 -t panard/wine:wow64 .

push: 
	$(DOCKER) buildx build --platform linux/amd64,linux/arm64/v8 -t panard/wine:wow64 --push .
