# MTGO docker image

 <a title="Docker Hub" href="https://hub.docker.com/r/panard/mtgo"><img src="https://img.shields.io/docker/pulls/panard/mtgo.svg?longCache=true&style=flat-square&logo=docker&logoColor=fff"></a>
 
 > :warning: :warning:
 > **With the recent transition to Daybreak, you need to perform once**
 > ```
 > ./run-mtgo --reset --update
 > ```
 >

This image provides a ready-to-play Magic The Gathering Online (MTGO) for Linux
and macOS.

Join the "WineHQ Players" clan! (Account > Buddies, Clan, Chat > Look for WineHQ Players and contact the captain, or send a mail to panard at inzenet dot org with your MTGO user name)

It is based on an amd64 [debian:stable-slim](https://hub.docker.com/r/_/debian/) Linux distribution and [WineHQ](https://www.winehq.org/) with WOW64 support.

See https://appdb.winehq.org/objectManager.php?sClass=version&iId=32007 for more information.

You can buy me a beer using either
- Github [![Github-sponsors](https://img.shields.io/badge/sponsor-30363D?style=for-the-badge&logo=GitHub-Sponsors&logoColor=#EA4AAA)](https://github.com/sponsors/pauleve)
- Paypal [![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=Y27XTWGY3ZZFY)


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
It will launch a configuration tool prior to launching MTGO. There you may be interested in the Graphics tab and use settings like this:
![](https://private-user-images.githubusercontent.com/228657/289696255-36af1dee-bea0-4363-93af-0d9c7bc849a0.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MTAzMjI1MDUsIm5iZiI6MTcxMDMyMjIwNSwicGF0aCI6Ii8yMjg2NTcvMjg5Njk2MjU1LTM2YWYxZGVlLWJlYTAtNDM2My05M2FmLTBkOWM3YmM4NDlhMC5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjQwMzEzJTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI0MDMxM1QwOTMwMDVaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT00YzAwOGE1YmJlM2Q3OWZhYmM0ZTg5N2Q3MmNjZmQ3MTM4NDY5Yjk0ZjJiMGI1YjNmN2VkNjNhMGU2NjRmZjMyJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZhY3Rvcl9pZD0wJmtleV9pZD0wJnJlcG9faWQ9MCJ9.AmIjIl49KCDxX8juEb5wrT_e7CAZ2PogzpPlvDlC5z4)

### Sound

Sound is disabled by default.  To enable it:
```
./run-mtgo --sound
```
Until the patched image is published, build it locally on top of the image you
already use, and name it explicitly (`--sound` alone pulls the image from the
hub):
```
make sound-local
./run-mtgo --sound panard/mtgo:sound-local
```
This uses the `panard/mtgo:sound` image, which talks to the PulseAudio (or
PipeWire) server of the host, and patches the audio code of your local MTGO
installation, because the client's own audio path does not work under wine
(see [#217](https://github.com/pauleve/docker-mtgo/issues/217)):

* MTGO refuses to play anything when the Windows master volume reads as 0,
  which is what wine reports;
* MTGO enumerates WASAPI audio sessions through `ISimpleAudioVolume`, which
  wine does not implement;
* every sound is converted by the Media Foundation resampler, which wine does
  not provide, and MTGO disables its audio for the whole session on the first
  such failure.

[SOUND.md](./SOUND.md) documents the whole mechanism, the evidence behind each
patch and how to update it when a client release breaks it.

The patch is applied to the copy of the client stored in your docker volume,
right before MTGO starts, and again whenever the client updates itself (in that
case sound comes back at the next start).  The original files are backed up in
`AppData/Local/mtgo-audio-patch` inside the volume, and the MTGO volume sliders
keep working.  Related options:

```
./run-mtgo --sound --no-audio-patch   # leave the client untouched
./run-mtgo --sound --force-volume     # always play at 100%, ignore MTGO sliders
```

To undo the patch (for instance to check whether a client update fixed things
upstream):
```
./run-mtgo --cmd 'mtgo-audio-patch --restore'
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

* `run-mtgo` prompt for .NET installation:
```
./run-mtgo --reset # only once
```

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

* no sound, and `--sound` prints `this MTGO version is not supported by the
audio patch`:

the audio patch recognises the code it has to rewrite; if MTGO restructures it,
the patch refuses to touch the client rather than corrupting it.  Please report
it, mentioning the client version.


## FAQ

* [Change game resolution](https://github.com/pauleve/docker-mtgo/issues/12#issuecomment-355844711)

### Import/export deck files

By default, the folder `~/.local/share/mtgo/files` is bound to the Windows "Documents" folder.
You can change it using the `--bind` option: assuming your decks are in the `~/mtgo` folder
```
./run-mtgo --bind ~/mtgo
```
to have access to this folder from the Docker mtgo as the `Documents` folder.

See also [Access host files](https://github.com/pauleve/docker-mtgo/issues/11#issuecomment-355766306)

### Replace Docker with Podman

If you are using podman as an alternative  container manager, change the value of the "docker_client" parameter to podman. Also add the "--userns keepid" to the "opts" parameter, since default Podman behavior doesn't change file ownership when mounting a volume.
