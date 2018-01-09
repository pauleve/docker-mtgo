# MTGO docker image

This image provides a ready-to-play Magic The Gathering Online (MTGO) for Linux
and macOS.

Join the "WineHQ Players" clan! (Account > Buddies, Clan, Chat > Look for WineHQ Players and contact the captain, or send a mail to panard at inzenet dot org with your MTGO user name)

It is based on [i386/debian:stretch-slim](https://hub.docker.com/r/i386/debian/) and wine-staging 2.20.

See https://appdb.winehq.org/objectManager.php?sClass=version&iId=32007 for more information.

### Note for macOS users

MacOS support is still under test.
Using [Homebrew](https://brew.sh/), install XQuartz, socat, and the GNU version of getopt:

```
brew cask install xquartz 
brew install socat gnu-getopt 
```
Then *restart* your session and follow the standard usage.
Please give us feedback on https://github.com/pauleve/docker-mtgo/issues/3 (being positive or negative, with the full output of the `run-mtgo` script).

## Usage

Here are basic usage instructions.
You may want to have a look at the [wiki](https://github.com/pauleve/docker-mtgo/wiki) as well.


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
