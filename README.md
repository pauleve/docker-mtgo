# MTGO docker image

 <a title="Docker Hub" href="https://hub.docker.com/r/panard/mtgo"><img src="https://img.shields.io/docker/pulls/panard/mtgo.svg?longCache=true&style=flat-square&logo=docker&logoColor=fff"></a>

This image provides a ready-to-play Magic The Gathering Online (MTGO) for Linux
and macOS.

Join the "WineHQ Players" clan! (Account > Buddies, Clan, Chat > Look for WineHQ Players and contact the captain, or send a mail to panard at inzenet dot org with your MTGO user name)

It is based on [i386/debian:stable-slim](https://hub.docker.com/r/i386/debian/) and wine 6.20.

See https://appdb.winehq.org/objectManager.php?sClass=version&iId=32007 for more information.


[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=Y27XTWGY3ZZFY)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.me/loicpauleve)

## Installation

A necessary prerequisite is to install **docker**: https://www.docker.com/community-edition#/download.
You do _not_ need wine.

### Linux

Open a terminal and install the `run-mtgo` script:
```
wget -O run-mtgo https://raw.githubusercontent.com/pauleve/docker-mtgo/master/run-mtgo
chmod +x run-mtgo
```

Make sure your user is in the `docker` group (command `groups`). If not, add yourself to the docker group:
```
sudo usermod -aG docker $USER
```
You need to logout/login for the changes to take effect.

### macOS

Support for macOS is still under test.
Using [Homebrew](https://brew.sh/), install XQuartz, socat, and the GNU version of getopt.

```
brew install xquartz
brew install socat
brew install gnu-getopt
brew install wget
```
Then **restart your session** (or reboot) and, install the `run-mtgo` script:
```
curl -o run-mtgo https://raw.githubusercontent.com/pauleve/docker-mtgo/master/run-mtgo
chmod +x run-mtgo
```

*Important for macOS users*: depending on your configuration the Docker image may not work properly. You can consider installing MTGO using Wine directly, following the instructions here: https://github.com/pauleve/docker-mtgo/wiki/macOS:-installing-MTGO-using-Wine

## Usage

Run the docker image using the [run-mtgo](./run-mtgo?raw=true) helper script
```
./run-mtgo
```

Depending on your configuration, you may want to adjust the resolution of the game, or even switch to desktop emulation which may fix some graphics issues.
```
./run-mtgo --winecfg
```
It will launch a configuration tool prior to launching MTGO. There you may be interested in the Graphics tab.

Sound is disabled by default, but adventurous users can give a try to
```
./run-mtgo --sound
```
do not hesitate to report issues.

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

* `run-mtgo` got permission denied while trying to connect to the Docker daemon socket:

Add yourself to the docker group:
```
sudo usermod -aG docker $USER
```
You need to logout/login for the changes to take effect.

* `run-mtgo` never exits, even after <kbd>Ctrl</kbd>+<kbd>C</kbd>:
```
docker kill mtgo_running
```

* Poor performance on Linux (game hangs regularly)

If you are using an Nvidia graphics card, check https://github.com/pauleve/docker-mtgo/issues/132
Alternatively try
```
./run-mtgo panard/mtgo:wine-4.9
```


## FAQ

* [Change game resolution](https://github.com/pauleve/docker-mtgo/issues/12#issuecomment-355844711)
* [Access host files](https://github.com/pauleve/docker-mtgo/issues/11#issuecomment-355766306) (import/export decks)
