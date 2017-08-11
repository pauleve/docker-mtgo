
all: wine-stable

wine-%:
	docker build -t panard/wine:$* --build-arg WINE_BUILD=$* .

