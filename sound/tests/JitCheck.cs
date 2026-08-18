using System;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;

// Forces the CLR to JIT every method of MTGO's audio types.  Invalid IL shows
// up here as InvalidProgramException / VerificationException.
class JitCheck {
    static string appdir;

    static Assembly Resolve(object sender, ResolveEventArgs e) {
        string n = new AssemblyName(e.Name).Name;
        string p = Path.Combine(appdir, n + ".dll");
        if (File.Exists(p)) return Assembly.LoadFrom(p);
        return null;
    }

    static int Main(string[] args) {
        string dll = args[0];
        appdir = args[1];
        AppDomain.CurrentDomain.AssemblyResolve += Resolve;
        Assembly asm = Assembly.LoadFrom(dll);
        Console.WriteLine("loaded " + asm.FullName);
        string[] want = { "AudioManager", "SoundQueue", "ActiveSample", "SoundManager" };
        int prepared = 0, failed = 0;
        foreach (Type t in asm.GetTypes()) {
            bool match = false;
            foreach (string w in want) if (t.Name == w) match = true;
            if (!match) continue;
            Console.WriteLine("type " + t.FullName);
            var flags = BindingFlags.Public | BindingFlags.NonPublic |
                        BindingFlags.Instance | BindingFlags.Static |
                        BindingFlags.DeclaredOnly;
            foreach (MethodBase m in t.GetMethods(flags)) { if (Prepare(t, m)) prepared++; else failed++; }
            foreach (MethodBase m in t.GetConstructors(flags)) { if (Prepare(t, m)) prepared++; else failed++; }
        }
        Console.WriteLine("JIT: " + prepared + " ok, " + failed + " failed");

        // and actually call the two patched leaf methods
        foreach (Type t in asm.GetTypes()) {
            if (t.Name != "AudioManager") continue;
            var f = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static;
            try {
                Console.WriteLine("IsMuted() = " + t.GetMethod("IsMuted", f).Invoke(null, null));
            } catch (Exception e) { Console.WriteLine("IsMuted() threw " + Inner(e)); failed++; }
            try {
                Console.WriteLine("GetWindowsVolume() = " + t.GetMethod("GetWindowsVolume", f).Invoke(null, null));
            } catch (Exception e) { Console.WriteLine("GetWindowsVolume() threw " + Inner(e)); failed++; }
        }
        Console.WriteLine(failed == 0 ? "RESULT: OK" : "RESULT: FAILED");
        return failed == 0 ? 0 : 1;
    }

    static string Inner(Exception e) {
        while (e.InnerException != null) e = e.InnerException;
        return e.GetType().Name + ": " + e.Message;
    }

    static bool Prepare(Type t, MethodBase m) {
        if (m.IsAbstract || m.ContainsGenericParameters || t.ContainsGenericParameters)
            return true;
        try {
            RuntimeHelpers.PrepareMethod(m.MethodHandle);
            return true;
        } catch (Exception e) {
            Console.WriteLine("  JIT FAILED " + t.FullName + "." + m.Name + " -> " + Inner(e));
            return false;
        }
    }
}
