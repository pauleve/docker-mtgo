# Sound: how it works, and how to fix it when it breaks

MTGO's audio code does not work under wine.  The `--sound` option therefore does
two things: it wires the container to the host sound server, and it rewrites a
few methods of the MTGO client installed in your docker volume.  This document
describes the whole mechanism, the evidence behind each patch, and how to
re-derive the patches when a client update invalidates them.

Origin: <https://github.com/pauleve/docker-mtgo/issues/217>.  That issue
contains a working recipe based on hardcoded file offsets for one specific
build of `SharedResources.dll`; the implementation here locates the same code
through metadata and code patterns instead, so it survives client updates.

Last verified: MTGO `3.4.158.4691` (and `3.4.157.4686`), image based on
`panard/mtgo:latest` (wine 9.8), PipeWire on the host.

## Quick start

```
make sound-local                              # sound image + patch, on top of panard/mtgo:latest
./run-mtgo --sound panard/mtgo:sound-local    # patches the client, then starts MTGO
sound/tests/verify-audio.sh                   # proves audio works, without logging in
```

## The sound path

```
host PipeWire/PulseAudio server
  └─ /run/user/<uid>/pulse/native      bind mounted by run-mtgo (--sound)
      └─ /etc/pulse/client.conf        from sound/, points at the socket, disables shm+autospawn
          └─ wine winmm, HKCU\Software\Wine\Drivers\Audio = "pulse"
              └─ NAudio WaveOutEvent   (NAudio.WinMM.dll, shipped by MTGO)
                  └─ MixingSampleProvider   one per MTGO sound queue
                      └─ VolumeSampleProvider ← RawSourceWaveStream ← Audio/**/*.wav
```

Inside the client (`SharedResources.dll`), `Shiny.Utilities.AudioManager` is a
static class that owns four `SoundQueue` instances (UI, Card, InDuel, Alerts).
Each queue owns a `MixingSampleProvider` and a `WaveOutEvent`; each sound played
becomes an `ActiveSample` added to the queue's mixer.  When audio works you see
exactly four PulseAudio streams named `Magic Online`, `float32le 2ch 44100Hz`.

`gstreamer` and `wmp=builtin` (installed by the sound image and by
`extra/mtgo.sh`) are *not* involved in these sounds: MTGO reads the wav files
itself and feeds raw PCM to NAudio.

## Why it did not work

Three independent failures, all confirmed by running MTGO's own code in the
container (see [Verifying](#verifying)):

### 1. The master volume reads as 0, so nothing is ever played

`AudioManager.PlaySound()` starts with:

```
  IL_0008: ldc.i4.s        54
  IL_000a: call            GetVolume (this assembly)      // MTGO's own slider
  IL_0010: ldarg.1
  IL_0011: ldc.r8          0.0
  IL_001a: ble.s           -> IL_0038                     // sample volume <= 0 → return
  IL_001c: call            GetWindowsVolume (this assembly)
  IL_0021: ldc.r8          0.0
  IL_002a: ble.s           -> IL_0038                     // windows volume <= 0 → return
```

and `GetWindowsVolume()` is

```
  IL_0000: call            IsMuted (this assembly)
  IL_0005: brfalse.s       -> IL_0011
  IL_0007: ldc.r8          0.0
  IL_0010: ret
  IL_0011: ldsfld          System.IntPtr::Zero
  IL_0016: ldloca.s        0
  IL_0018: call            waveOutGetVolume (this assembly)   // winmm P/Invoke
  IL_001d: pop                                                // return code ignored
  IL_001e: ldloc.0                                            // ... local stays 0
```

wine's `waveOutGetVolume()` does not fill the out parameter for the null handle
MTGO passes, and the return code is discarded, so the method returns 0 and every
single sound is dropped before it reaches a queue.  Measured directly on the
unpatched client: `GetWindowsVolume() = 0`.

**This is the one that matters most.**  Without it, nothing else is observable.

### 2. Every sample goes through Media Foundation, which wine does not have

`SoundQueue.ActiveSample..ctor`:

```
  IL_0034: ldarg.1
  IL_0035: ldfld           field format      // sample.format
  IL_003a: ldarg.3                           // the mixer's format
  IL_003b: beq.s           -> IL_0055        // reference comparison!
  IL_003d: ldarg.0
  IL_003e: ldarg.0
  IL_003f: ldfld           field stream
  IL_0044: ldarg.3
  IL_0045: newobj          NAudio.Wave.MediaFoundationResampler::.ctor
```

`beq` on two `WaveFormat` *references* is never true, so every sample is routed
through `MediaFoundationResampler`, whose MFT is not registered in wine:

```
COMException: Retrieving the COM class factory for component with CLSID
{F447B69E-1884-4A7E-8055-346F74D6EDB3} failed ... 0x80040154 (REGDB_E_CLASSNOTREG)
```

Worse, `AudioManager.PlaySoundSafe()` catches that exception and sets
`m_mediaPlayerNotAvailable = true`, which disables audio for the rest of the
session, so a single failure is terminal.

### 3. `IsMuted()` casts wine COM objects to `ISimpleAudioVolume`

`IsMuted()` enumerates WASAPI sessions (`IMMDeviceEnumerator`,
`IAudioSessionManager2`, `IAudioSessionControl2`) and casts the current
process's session to `ISimpleAudioVolume`.  On wine 9.8 the enumeration bails
out early and the method harmlessly returns `false`; on wine 11 it reaches the
cast, gets `E_NOINTERFACE` and throws `InvalidCastException` (this is what
issue #217 reports).  It is patched defensively.

### 4. Consequence: the mixer format must match the sound files

Once the resampler is bypassed, a sample can only be added to the mixer if it
already has the mixer's sample rate and channel count.  MTGO builds the mixer as
**mono** 44100:

```
  IL_0052: ldc.i4          44100
  IL_0057: ldc.i4.1                                             // channels
  IL_0058: call            NAudio.Wave.WaveFormat::CreateIeeeFloatWaveFormat
```

while 96 of its 98 wav files are stereo 44100.  So the mixer is switched to
stereo, and the two odd files (`Audio/Duel/WIN.wav`, `Audio/Duel/LOSE.wav`, mono
22050) are converted on disk.

## What the patch changes

All of it is applied to the *installed* client inside your docker volume. No
patched binary is distributed, and nothing is modified in the image.

| Method | Change | Reason |
| --- | --- | --- |
| `Shiny.Utilities.AudioManager.IsMuted()` | body replaced by `ldc.i4.0; ret` | avoids the `ISimpleAudioVolume` cast |
| `Shiny.Utilities.AudioManager.GetWindowsVolume()` | body replaced by `ldc.r8 1.0; ret` | wine reports 0, which mutes everything |
| `SoundQueue..ctor` | `ldc.i4.1` → `ldc.i4.2` before `CreateIeeeFloatWaveFormat` | stereo mixer, matching the sound files |
| `SoundQueue.ActiveSample..ctor` | the 4 comparison instructions → `br.s` to the "formats match" arm | never build a `MediaFoundationResampler` |
| `Audio/**/*.wav` not in mixer format | converted to 2ch/44100/16 bit | required by the bypass above |
| `AudioManager.GetVolume(...)` | `ldc.r8 1.0; ret`, **only with `--force-volume`** | MTGO's own sliders keep working by default |

Original files are kept in the volume, outside the ClickOnce directory:

```
<volume>/wine/AppData/Local/mtgo-audio-patch/<app dir name>/
    SharedResources.dll.orig
    state.json          patched/original sha256, sample rate, converted wavs
    wav/Audio/Duel/WIN.wav ...
```

`mtgo-audio-patch --restore` puts everything back.

## Rules for IL patching here

Learned by breaking them; the JIT check in `sound/tests/` catches each one.

* **A method body cannot be resized.**  Its length is in the method header and
  bodies are packed back to back.  Patches pad with `nop` (0x00) instead.
* **A body must not fall off its end.**  Padding a replaced body with trailing
  `nop`s produces `InvalidProgramException`, because execution runs past the last
  byte.  `Body.replace_all()` therefore writes the padding *first* and lets the
  new code end exactly on the last byte with its `ret`.
* **The evaluation stack must be empty where control flow is rewritten.**  The
  resampler bypass replaces the whole `ldarg/ldfld/ldarg/beq` group, not just the
  branch, and refuses to patch unless the preceding instruction is a store or a
  `pop`.
* **Do not rewrite exception handling sections.**  When a body with handlers is
  replaced wholesale, clearing `CorILMethod_MoreSects` (0x08) in the fat header
  makes the CLR ignore the clauses; the bytes stay where they are.
* **Match the return type before returning a constant.**  `ldc.r8` for
  `float64`, `ldc.r4` for `float32`; the patcher reads the method signature.
* **The only real verifier is the JIT.**  IL that disassembles perfectly can
  still be rejected.  Always run `sound/tests/verify-audio.sh`.

## The patcher

`extra/mtgo-audio-patch.py`, standard library only (python3 is present in the
base image, and `sound/Dockerfile` installs `python3-minimal` explicitly).

Structure:

| Part | What it does |
| --- | --- |
| `Assembly` | PE headers → CLI header → `#~` metadata; sizes tables 0x00-0x0A and reads `TypeDef`, `MethodDef`, `MemberRef`, the `#Strings`/`#Blob` heaps |
| `disasm()` / `Insn` | full single-byte and `0xFE`-prefixed CIL decoder |
| `Body` | method header (tiny/fat), code window, `write()`, `replace_all()`, `drop_exception_handlers()` |
| `patch_*()` | one function per patch, each locating its target by pattern and raising `PatchError` rather than guessing |
| `convert_wav()` | 16 bit PCM resample/upmix with `wave` + `array` |
| `patch_app_dir()` | backups, state file, idempotency, restore |

Everything is keyed on **names and code patterns**, never on file offsets:
`find_methods('SoundQueue', '.ctor')` walks the metadata, and the mixer patch
looks for "push a sample rate, push 1, call something" rather than a fixed
address.  If a pattern is absent or ambiguous the patcher aborts that
installation with a message and leaves the client untouched.

Command line:

```
mtgo-audio-patch                     # patch every installation under $WINEPREFIX
mtgo-audio-patch --app-dir DIR       # just this one
mtgo-audio-patch --dry-run           # say what would happen
mtgo-audio-patch --restore           # undo
mtgo-audio-patch --force-volume      # also force GetVolume() to 1.0
mtgo-audio-patch --no-wav            # do not convert sound files
mtgo-audio-patch --dump [Type::Method ...]   # disassemble (see below)
mtgo-audio-patch --dump --dll ./SharedResources.dll Type::Method
```

Integration points:

| File | Role |
| --- | --- |
| `Dockerfile` | installs the script as `/usr/local/bin/mtgo-audio-patch` |
| `sound/Dockerfile` | gstreamer, pulse client config, `python3-minimal`; `BASE` build arg |
| `sound/local.Dockerfile` | sound image + patch on top of an existing base (`make sound-local`) |
| `extra/mtgo.sh` | `--sound` runs the patch before launching, and again in the 6 s watchdog loop so a self-updated client is patched for the next start |
| `run-mtgo` | `--sound`, `--no-audio-patch`, `--force-volume`; mounts the pulse socket |

## Verifying

```
sound/tests/verify-audio.sh [IMAGE] [DOCKER_VOLUME]
```

Requires `docker`, `pactl`, `parec`, `python3` on the host.  It never touches
the real installation: it copies the newest MTGO application directory out of
the (read-only mounted) volume, restores the pristine DLL from the backup if
there is one, and works on that copy.  Steps:

1. compiles `sound/tests/JitCheck.cs` and `sound/tests/PlayTest.cs` with the
   `csc.exe` of the wine prefix (.NET Framework 4.8 is installed in the image);
2. **`JitCheck`** loads the assembly and calls `RuntimeHelpers.PrepareMethod()`
   on every method of `AudioManager`, `SoundQueue` and `ActiveSample`, which
   forces the JIT to import the IL, so invalid IL surfaces here as
   `InvalidProgramException`, then calls `IsMuted()` and `GetWindowsVolume()`;
3. applies the patch and repeats (2);
4. **`PlayTest`** rebuilds MTGO's pipeline with MTGO's own NAudio and plays real
   MTGO wav files into a throw-away null sink, which is recorded and measured;
5. replays the same thing the way MTGO ships it (mono mixer +
   `MediaFoundationResampler`), which must fail.

Expected tail:

```
=== unpatched client (baseline: valid IL, and audio effectively muted)
JIT: 44 ok, 0 failed
IsMuted() = False
GetWindowsVolume() = 0
=== patched client (must JIT and report a usable volume)
JIT: 44 ok, 0 failed
GetWindowsVolume() = 1
captured 4.8 s, peak=30999 rms=5045.9
=== control: the pipeline as MTGO ships it (must fail under wine)
FAILED GAME_BEGIN.wav -> COMException: ... REGDB_E_CLASSNOTREG
ALL CHECKS PASSED
```

With MTGO actually running, the host side should show four uncorked streams:

```
pactl list sink-inputs | grep -B22 'Magic Online' \
    | grep -E 'Sample Specification|Corked|Mute'
        Sample Specification: float32le 2ch 44100Hz
        Corked: no
        Mute: no
```

`1ch` there means the mixer patch did not take effect.  To measure one of those
streams: `parec --monitor-stream=<index> --format=s16le --rate=44100 --channels=2`.

## When a client update breaks the patch

`run-mtgo --sound` prints

```
mtgo-audio-patch: <app dir>: <what could not be found>
mtgo-audio-patch: this MTGO version is not supported by the audio patch; sound may not work.
```

and starts MTGO unpatched.  To fix it:

1. get the new DLL out of the volume:

   ```
   docker run --rm -v mtgo64-data-$USER:/data -v "$PWD":/out alpine sh -c \
     'cp "$(ls -t $(find /data -name SharedResources.dll) | head -1)" /out/'
   ```

2. disassemble the methods involved and compare with the excerpts above:

   ```
   python3 extra/mtgo-audio-patch.py --dump --dll ./SharedResources.dll
   python3 extra/mtgo-audio-patch.py --dump --dll ./SharedResources.dll 'SoundQueue::.ctor'
   ```

   `--dump` resolves call targets and field names, so the code reads like the
   listings in this document.  Method names are `[Namespace.]Type::Method`;
   nested types are addressed by their own name (`ActiveSample::.ctor`).

3. adapt the matcher in the relevant `patch_*()` function.  Keep the pattern
   descriptive (opcode sequence, resolved call target) rather than positional,
   and keep it failing loudly when it does not match.

4. re-read [Rules for IL patching here](#rules-for-il-patching-here), then run
   `sound/tests/verify-audio.sh`.  A patch is not done until `JIT: … 0 failed`
   and a non-zero capture.

5. if MTGO changed something structural (a new audio backend, WASAPI instead of
   winmm, encoded assets instead of wav), re-check whether the patch is still
   needed at all: run the control step first, since wine may also have gained
   the missing pieces in the meantime.

## Known limitations

* A client update that lands while MTGO is running is patched by the watchdog
  loop, but the running process keeps the code it loaded: sound comes back at
  the next start.
* The resampler bypass assumes every sound file matches the mixer format; the
  patcher converts the ones that do not, and would need extending if MTGO ever
  ships something other than PCM wav.
* `--force-volume` disables MTGO's own volume sliders; it exists only as a
  fallback if the settings path also misbehaves.
* Only tested on Linux with PulseAudio/PipeWire.  The macOS path in `run-mtgo`
  (TCP PulseAudio) is untested for the patch.
* `mtgo-audio-patch` rewrites managed code of a client you are licensed to run,
  locally; do not redistribute patched DLLs.
