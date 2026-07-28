using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

namespace LaunchpadPicker
{
    internal static class Program
    {
        // Single-instance guard (the old HTA used SINGLEINSTANCE="yes").
        private static Mutex _instanceMutex;

        [STAThread]
        private static void Main(string[] args)
        {
            // Which page to host. Default is the folder picker. Kept as an
            // argument so the same host can serve additional pages later.
            string page = ResolvePage(args);

            bool createdNew;
            _instanceMutex = new Mutex(true, "KivunTerminalPicker_" + page.Replace('.', '_'), out createdNew);
            if (!createdNew) return; // already running

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            try
            {
                Application.Run(new MainForm(page));
            }
            finally
            {
                try { _instanceMutex.ReleaseMutex(); } catch { }
            }
        }

        // Accept only a safe local .html filename (no path, no traversal).
        private static string ResolvePage(string[] args)
        {
            if (args != null && args.Length > 0 && !string.IsNullOrWhiteSpace(args[0]))
            {
                string candidate = System.IO.Path.GetFileName(args[0].Trim());
                if (System.Text.RegularExpressions.Regex.IsMatch(candidate, "^[A-Za-z0-9._-]+\\.html$"))
                    return candidate;
            }
            return "folder-picker.html";
        }
    }

    internal sealed class MainForm : Form
    {
        // The install directory (Kivun-WSL) - folder-picker.html, webview-shim.js,
        // config.txt and VERSION all live next to the exe.
        private static readonly string AppDir =
            AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');

        private const string VirtualHost = "appassets.local";

        private readonly WebView2 _web = new WebView2();
        private readonly HostBridge _bridge;
        private readonly string _startPage;

        public MainForm(string page)
        {
            _bridge = new HostBridge(this);
            _startPage = "https://" + VirtualHost + "/" + page;

            Text = "Kivun Terminal - Pick Folder";
            try { Icon = System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
            FormBorderStyle = FormBorderStyle.FixedDialog; // BORDER="dialog"
            MaximizeBox = false;                            // MAXIMIZEBUTTON="no"
            MinimizeBox = false;                            // MINIMIZEBUTTON="no"
            ShowInTaskbar = true;                           // SHOWINTASKBAR="yes"
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new System.Drawing.Size(1040, 690); // baseline; JS re-fits
            BackColor = System.Drawing.Color.White;

            _web.Dock = DockStyle.Fill;
            Controls.Add(_web);

            Load += OnLoadAsync;
        }

        private async void OnLoadAsync(object sender, EventArgs e)
        {
            try
            {
                string userData = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Kivun-WSL", "WebView2");
                Directory.CreateDirectory(userData);

                var env = await CoreWebView2Environment.CreateAsync(null, userData);
                await _web.EnsureCoreWebView2Async(env);

                CoreWebView2 c = _web.CoreWebView2;

                c.Settings.AreHostObjectsAllowed = true;
                c.Settings.IsWebMessageEnabled = true;
                c.Settings.AreDefaultContextMenusEnabled = false; // CONTEXTMENU="no"
                c.Settings.AreDevToolsEnabled = false;
                c.Settings.IsStatusBarEnabled = false;
                c.Settings.IsZoomControlEnabled = false;
                c.Settings.IsBuiltInErrorPageEnabled = false;
                c.Settings.AreBrowserAcceleratorKeysEnabled = false;

                c.AddHostObjectToScript("host", _bridge);

                string appDirJs = AppDir.Replace("\\", "\\\\").Replace("\"", "\\\"");
                await c.AddScriptToExecuteOnDocumentCreatedAsync(
                    "window.__APP_DIR__ = \"" + appDirJs + "\";");

                c.SetVirtualHostNameToFolderMapping(
                    VirtualHost, AppDir, CoreWebView2HostResourceAccessKind.Allow);

                c.WindowCloseRequested += (s2, e2) =>
                {
                    try { BeginInvoke((Action)Close); } catch { Close(); }
                };

                c.NewWindowRequested += (s2, e2) =>
                {
                    e2.Handled = true;
                    try { Process.Start(new ProcessStartInfo(e2.Uri) { UseShellExecute = true }); } catch { }
                };

                c.Navigate(_startPage);
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "The picker could not start the Microsoft Edge WebView2 component.\n\n" +
                    "Please install the free 'Microsoft Edge WebView2 Runtime' from Microsoft, then try again.\n\n" +
                    "Details: " + ex.Message,
                    "Kivun Terminal",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
                Close();
            }
        }
    }
}
