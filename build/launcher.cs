using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

class Program {
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint GetConsoleProcessList(uint[] list, uint count);

    [DllImport("kernel32.dll")]
    static extern IntPtr GetConsoleWindow();

    [DllImport("kernel32.dll")]
    static extern bool ShowWindow(IntPtr window, int command);

    const int SW_HIDE = 0;

    static int Main(string[] args) {
        // A console exe: a shell that runs it waits for it, and everything it
        // starts writes into that same console. Double-clicked, Windows makes
        // a console for this exe alone - hide it at once, the window is the
        // interface then. A console shared with a caller is never touched.
        bool headless = args.Length == 0;
        if (headless) {
            uint[] owners = new uint[2];
            if (GetConsoleProcessList(owners, 2) == 1) {
                IntPtr window = GetConsoleWindow();
                if (window != IntPtr.Zero) { ShowWindow(window, SW_HIDE); }
            }
        }

        string rootDir = AppDomain.CurrentDomain.BaseDirectory;
        string scriptPath = Path.Combine(rootDir, "wsl-fleet.ps1");

        if (!File.Exists(scriptPath)) {
            System.Windows.Forms.MessageBox.Show(
                "The main script was not found:\n" + scriptPath,
                "wsl-fleet not found",
                System.Windows.Forms.MessageBoxButtons.OK,
                System.Windows.Forms.MessageBoxIcon.Error
            );
            return 1;
        }

        string forwardArgs = args.Length > 0 ? string.Join(" ", args) : "gui";

        ProcessStartInfo psi = new ProcessStartInfo {
            FileName = "pwsh.exe",
            Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + "\" " + forwardArgs,
            UseShellExecute = false,
            CreateNoWindow = headless,
            WindowStyle = headless ? ProcessWindowStyle.Hidden : ProcessWindowStyle.Normal
        };

        try {
            using (Process p = Process.Start(psi)) {
                p.WaitForExit();
                return p.ExitCode;
            }
        } catch (Exception ex) {
            System.Windows.Forms.MessageBox.Show(
                "PowerShell (pwsh.exe) could not be started:\n" + ex.Message,
                "wsl-fleet could not launch",
                System.Windows.Forms.MessageBoxButtons.OK,
                System.Windows.Forms.MessageBoxIcon.Error
            );
            return 1;
        }
    }
}
