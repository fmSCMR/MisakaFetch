using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("MisakaFetch 启动器")]
[assembly: AssemblyProduct("MisakaFetch")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0")]
[assembly: AssemblyInformationalVersion("1.0.0")]

internal static class WindowsLauncher
{
    [STAThread]
    private static void Main()
    {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string[] locations = {
            Path.Combine(root, "app", "Windows"),
            Path.Combine(root, "source", "build", "windows", "x64", "runner", "Release"),
            Path.Combine(root, "build", "dist", "windows-package", "MisakaFetch"),
            Path.Combine(root, "build", "windows", "x64", "runner", "Release")
        };

        foreach (string directory in locations)
        {
            string executable = Path.Combine(directory, "MisakaFetch.exe");
            if (!File.Exists(executable) ||
                !File.Exists(Path.Combine(directory, "flutter_windows.dll")) ||
                !File.Exists(Path.Combine(directory, "data", "app.so")))
                continue;

            try
            {
                Process.Start(new ProcessStartInfo(executable) {
                    WorkingDirectory = directory,
                    UseShellExecute = false
                });
            }
            catch (Exception)
            {
                MessageBox.Show("MisakaFetch 启动失败，请检查运行包是否完整，以及 Windows 运行库是否已安装。",
                    "MisakaFetch", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            return;
        }

        MessageBox.Show("没有找到完整运行包。请保留启动器旁的app文件夹，或在 source 源码目录构建 Windows Release 后重试。",
            "MisakaFetch", MessageBoxButtons.OK, MessageBoxIcon.Information);
    }
}
