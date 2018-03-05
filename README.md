# MTGO docker image

This image provides a ready-to-play Magic The Gathering Online (MTGO) for Linux
and macOS.

Join the "WineHQ Players" clan! (Account > Buddies, Clan, Chat > Look for WineHQ Players and contact the captain, or send a mail to panard at inzenet dot org with your MTGO user name)

It is based on [i386/debian:stretch-slim](https://hub.docker.com/r/i386/debian/) and wine 3.3.

See https://appdb.winehq.org/objectManager.php?sClass=version&iId=32007 for more information.

## Installation

A necessary prerequisite is to install **docker**: https://www.docker.com/community-edition#/download.
You do _not_ need wine.

### Linux

Open a terminal and install the `run-mtgo` script:
```
wget -O run-mtgo https://raw.githubusercontent.com/pauleve/docker-mtgo/master/run-mtgo
chmod +x run-mtgo
```

### macOS

Support for macOS is still under test.
Using [Homebrew](https://brew.sh/), install XQuartz, socat, and the GNU version of getopt.

```
brew cask install xquartz
brew install socat
brew install gnu-getopt
```
Then **restart your session** (or reboot) and, install the `run-mtgo` script:
```
curl -o run-mtgo https://raw.githubusercontent.com/pauleve/docker-mtgo/master/run-mtgo
chmod +x run-mtgo
```

## Usage

Run the docker image using the [run-mtgo](./run-mtgo?raw=true) helper script
```
./run-mtgo
```

If for some reason you are prompted for .NET installation, abort, press Ctrl+C to quit the script and run
```
./run-mtgo --reset
```
(use the `--reset` option only once).

Depending on your configuration, you may want to adjust the resolution of the game, or even switch to desktop emulation which may fix some graphics issues.
```
./run-mtgo --winecfg
```
It will launch a configuration tool prior to launching MTGO. There you may be interested in the Graphics tab.



To ensure running the latest docker image, use
```
./run-mtgo --update
```
You shoud consider updating the `run-mtgo` script as well by following the
installation procedure.


See
```
./run-mtgo --help
```
for other options.

## Troubleshooting

* `run-mtgo` asks me to install .NET:

First, exit with <kbd>Ctrl</kbd>+<kbd>C</kbd>, then
```
./run-mtgo --reset
```

* `run-mtgo` never exits, even after <kbd>Ctrl</kbd>+<kbd>C</kbd>:
```
docker kill mtgo_running
```

## FAQ

* [Change game resolution](https://github.com/pauleve/docker-mtgo/issues/12#issuecomment-355844711)
* [Access host files](https://github.com/pauleve/docker-mtgo/issues/11#issuecomment-355766306) (import/export decks)
