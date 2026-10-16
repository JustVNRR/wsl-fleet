using System;
using System.Diagnostics;
using System.IO;

class Program {
    static int Main(string[] args) {
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

        // Double-click (no arguments): the window, and no console behind it.
        // With arguments: the command line, in a console that shows its own
        // output.
        bool headless = args.Length == 0;
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
