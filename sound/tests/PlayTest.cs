using System;
using System.IO;
using System.Threading;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;

// Reproduces MTGO's SoundQueue/ActiveSample pipeline with NAudio, so the audio
// stack can be exercised without logging into MTGO.
//   mode "patched" : stereo mixer, no resampler   (what the patch produces)
//   mode "orig"    : mono mixer + MediaFoundationResampler (what MTGO ships)
class PlayTest {
    static int Main(string[] args) {
        string mode = args[0];
        int channels = mode == "patched" ? 2 : 1;
        var format = WaveFormat.CreateIeeeFloatWaveFormat(44100, channels);
        var mixer = new MixingSampleProvider(format);
        mixer.ReadFully = true;
        var output = new WaveOutEvent();
        output.DesiredLatency = 200;
        try {
            output.Init(new SampleToWaveProvider(mixer));
            output.Play();
            Console.WriteLine("output started: " + output.PlaybackState);
        } catch (Exception e) {
            Console.WriteLine("OUTPUT FAILED: " + e.GetType().Name + ": " + e.Message);
            return 1;
        }

        int played = 0, failed = 0;
        for (int i = 1; i < args.Length; i++) {
            string path = args[i];
            try {
                byte[] data;
                WaveFormat wf;
                using (var r = new WaveFileReader(path)) {
                    wf = r.WaveFormat;
                    data = new byte[r.Length];
                    r.Read(data, 0, data.Length);
                }
                var stream = new RawSourceWaveStream(data, 0, data.Length, wf);
                IWaveProvider source = stream;
                if (!wf.Equals(format) && mode != "patched") {
                    source = new MediaFoundationResampler(stream, format);
                }
                mixer.AddMixerInput(new VolumeSampleProvider(source.ToSampleProvider()) { Volume = 1.0f });
                Console.WriteLine("playing " + Path.GetFileName(path) + " [" + wf + "]");
                played++;
                Thread.Sleep(1200);
            } catch (Exception e) {
                Console.WriteLine("FAILED " + Path.GetFileName(path) + " -> " +
                                  e.GetType().Name + ": " + e.Message);
                failed++;
            }
        }
        Thread.Sleep(1500);
        output.Stop();
        Console.WriteLine("played=" + played + " failed=" + failed);
        Console.WriteLine(failed == 0 && played > 0 ? "RESULT: OK" : "RESULT: FAILED");
        return failed == 0 && played > 0 ? 0 : 1;
    }
}
