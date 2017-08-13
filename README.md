# MTGO docker image

This image provides a ready-to-play MTGO.

It is based on [i386/debian:stretch-slim](https://hub.docker.com/r/i386/debian/) and wine-devel (2.20) with  patches by Anton Romanov to better support MTGO:
- https://github.com/theli-ua/wine/tree/mtgo
- https://source.winehq.org/patches/data/136421

See https://appdb.winehq.org/objectManager.php?sClass=version&iId=32007 for more information.

## Usage

### Get last tested image

```
docker pull panard/mtgo
```

### Run MTGO

```
docker run --privileged --rm -it -e DISPLAY  \
   -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
   -v $HOME/.Xauthority:/home/wine/.Xauthority:ro  \
   --net=host \
   panard/mtgo
```

Once you finished played, press Enter to shut down the container.

### Advanced usage

The image `panard/mtgo:latest` comes with a pre-installed MTGO, but before license acceptance.
Moreover, any setting will be lost at container shut down.

If you want to customize wine and remember your play settings, run first following command:
```
docker run --privileged --rm -it -e DISPLAY  \
   -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
   -v $HOME/.Xauthority:/home/wine/.Xauthority:ro  \
   --net=host \
   --name mtgo_running \
    panard/mtgo sh mtgo.sh  --winecfg
```
First, winecfg will open, which allows you to configure graphics for instance.

Then MTGO will launch. Enter your login, adjust your settings, disconnect MTGO, and _before_ pressing Enter to shut down the container, open a new terminal and type the following command:

```
docker commit mtgo_running mtgo:me
```
It will create a new docker image on top of `panard/mtgo` with your additional settings.

Then, you can start your image by replacing `panard/mtgo` with `mtgo:me`:

```
docker run --privileged --rm -it -e DISPLAY  \
   -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
   -v $HOME/.Xauthority:/home/wine/.Xauthority:ro  \
   --net=host \
   --name mtgo_running \
    mtgo:me sh mtgo.sh
```

(if you change your settings again, you can save them with the same above docker commit command).


## Tags

* `latest` is the latest tested image with configured wine environment and pre-installed MTGO
* `YYYY-MM-DD` are timestamps for the tested images with pre-installed MTGO.
* `staging` is the latest tested image with configured wine environment but without pre-installed MTGO (used to regenerate a `latest` image when MTGO is upgraded)
* `staging-YYYY-MM-DD` are timestamps for the staging images.

