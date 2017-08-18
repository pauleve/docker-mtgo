# MTGO docker image

This image provides a ready-to-play MTGO for Linux.

It is based on [i386/debian:stretch-slim](https://hub.docker.com/r/i386/debian/) and wine-staging (2.14) with patches by Anton Romanov to better support MTGO:
- https://github.com/theli-ua/wine/tree/mtgo

See https://appdb.winehq.org/objectManager.php?sClass=version&iId=32007 for more information.

## Usage

### Get last tested image

```
docker pull panard/mtgo
```

### Run MTGO

```
./run-mtgo
```

Once you finished played, press Enter to shut down the container.

### Advanced usage

The image `panard/mtgo:latest` comes with a pre-installed MTGO, but before license acceptance.
Moreover, any setting will be lost at container shut down.

If you want to customize wine and remember your play settings, run first following command:
```
./run-mtgo --winecfg
```
First, winecfg will open, which allows you to configure graphics for instance.

Then MTGO will launch. Enter your login, adjust your settings, disconnect MTGO, and _before_ pressing Enter to shut down the container, open a new terminal and type the following command:

```
docker commit mtgo_running mtgo:me
```
It will create a new docker image on top of `panard/mtgo` with your additional settings.

Then, you can start your image by replacing `panard/mtgo` with `mtgo:me`:

```
./run-mtgo mtgo:me
```

(if you change your settings again, you can save them with the same above docker commit command).


## Building

To build the `mtgo:staging` image:
```
make -C docker-wine
make staging
```


