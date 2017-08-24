# MTGO docker image

This image provides a ready-to-play MTGO for Linux.

It is based on [i386/debian:stretch-slim](https://hub.docker.com/r/i386/debian/) and wine-staging (2.15) with patches by Anton Romanov to better support MTGO:
- https://github.com/theli-ua/wine/tree/mtgo

See https://appdb.winehq.org/objectManager.php?sClass=version&iId=32007 for more information.

## Usage

Pull latest docker image:
```
docker pull panard/mtgo
```

Run the docker image using [run-mtgo](./run-mtgo?raw=true) helper script
```
./run-mtgo
```

The script `run-mtgo` can be installed and upgraded as follows:
```
wget -O run-mtgo https://raw.githubusercontent.com/pauleve/docker-mtgo/master/run-mtgo
chmod +x run-mtgo
```

If you want to customize wine (notably the graphics), you can use
```
./run-mtgo --winecfg
```

See
```
./run-mtgo --help
```
for other options.


## Docker image building

```
make -C docker-wine
make
```


