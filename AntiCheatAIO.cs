using System;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

public class MainForm : Form
{
    // ── P/Invoke ─────────────────────────────────────────────────────────
    [DllImport("user32.dll")] static extern bool   ReleaseCapture();
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, IntPtr l);
    [DllImport("dwmapi.dll")] static extern int    DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int sz);

    const int WM_NCLBUTTONDOWN   = 0xA1;
    const int HTCAPTION          = 2;
    const int HTLEFT             = 10;
    const int HTRIGHT            = 11;
    const int HTTOP              = 12;
    const int HTTOPLEFT          = 13;
    const int HTTOPRIGHT         = 14;
    const int HTBOTTOM           = 15;
    const int HTBOTTOMLEFT       = 16;
    const int HTBOTTOMRIGHT      = 17;
    const int DWMWA_BORDER_COLOR = 34;
    const int DWMWA_COLOR_NONE   = unchecked((int)0xFFFFFFFE);
    const int GRIP               = 6;

    WebView2 _wv;
    Process  _scanProc;
    bool     _scanRunning;

    // ── Entry point ──────────────────────────────────────────────────────
    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new MainForm());
    }

    // ── Constructor ──────────────────────────────────────────────────────
    public MainForm()
    {
        Text            = "Reek";
        Width           = 1100;
        Height          = 700;
        MinimumSize     = new Size(800, 560);
        StartPosition   = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.None;
        BackColor       = Color.FromArgb(184, 178, 170);
        Padding         = new Padding(0);

        _wv = new WebView2 { Dock = DockStyle.Fill };
        Controls.Add(_wv);
        _wv.CoreWebView2InitializationCompleted += OnWebViewReady;
        InitWebView();

        SetupResizeGrips();
    }

    // ── Init WebView2 sans cache disque ─────────────────────────────────
    async void InitWebView()
    {
        var opts = new CoreWebView2EnvironmentOptions("--disk-cache-size=1 --disable-application-cache");
        var env  = await CoreWebView2Environment.CreateAsync(null, null, opts);
        await _wv.EnsureCoreWebView2Async(env);
    }

    // ── Remove Windows 11 DWM white border ───────────────────────────────
    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        int val = DWMWA_COLOR_NONE;
        DwmSetWindowAttribute(Handle, DWMWA_BORDER_COLOR, ref val, 4);
    }

    // ── Resize grip panels ───────────────────────────────────────────────
    void SetupResizeGrips()
    {
        int W = ClientSize.Width;
        int H = ClientSize.Height;
        Color bg = Color.FromArgb(184, 178, 170);
        MakeGrip(0,      0,      GRIP,     GRIP,     AnchorStyles.Top    | AnchorStyles.Left,                        Cursors.SizeNWSE, HTTOPLEFT,     bg);
        MakeGrip(W-GRIP, 0,      GRIP,     GRIP,     AnchorStyles.Top    | AnchorStyles.Right,                       Cursors.SizeNESW, HTTOPRIGHT,    bg);
        MakeGrip(0,      H-GRIP, GRIP,     GRIP,     AnchorStyles.Bottom | AnchorStyles.Left,                        Cursors.SizeNESW, HTBOTTOMLEFT,  bg);
        MakeGrip(W-GRIP, H-GRIP, GRIP,     GRIP,     AnchorStyles.Bottom | AnchorStyles.Right,                       Cursors.SizeNWSE, HTBOTTOMRIGHT, bg);
        MakeGrip(GRIP,   0,      W-2*GRIP, GRIP,     AnchorStyles.Top    | AnchorStyles.Left | AnchorStyles.Right,   Cursors.SizeNS,   HTTOP,         bg);
        MakeGrip(GRIP,   H-GRIP, W-2*GRIP, GRIP,     AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right,   Cursors.SizeNS,   HTBOTTOM,      bg);
        MakeGrip(0,      GRIP,   GRIP,     H-2*GRIP, AnchorStyles.Left   | AnchorStyles.Top  | AnchorStyles.Bottom,  Cursors.SizeWE,   HTLEFT,        bg);
        MakeGrip(W-GRIP, GRIP,   GRIP,     H-2*GRIP, AnchorStyles.Right  | AnchorStyles.Top  | AnchorStyles.Bottom,  Cursors.SizeWE,   HTRIGHT,       bg);
    }

    void MakeGrip(int x, int y, int w, int h, AnchorStyles anchor, Cursor cursor, int ht, Color bg)
    {
        var p = new Panel { Location = new Point(x,y), Size = new Size(w,h),
                            BackColor = bg, Cursor = cursor, Anchor = anchor, Tag = ht };
        p.MouseDown += delegate(object s, MouseEventArgs e) {
            if (e.Button == MouseButtons.Left && WindowState != FormWindowState.Maximized) {
                ReleaseCapture();
                SendMessage(Handle, WM_NCLBUTTONDOWN, (IntPtr)(int)((Panel)s).Tag, IntPtr.Zero);
            }
        };
        Controls.Add(p);
        p.BringToFront();
    }

    // ── WebView2 initialised ─────────────────────────────────────────────
    async void OnWebViewReady(object sender, CoreWebView2InitializationCompletedEventArgs e)
    {
        if (_wv.CoreWebView2 == null) return;
        _wv.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
        _wv.CoreWebView2.Settings.IsStatusBarEnabled            = false;
        _wv.CoreWebView2.Settings.AreDevToolsEnabled            = false;
        _wv.CoreWebView2.WebMessageReceived += OnWebMessage;

        await _wv.CoreWebView2.AddScriptToExecuteOnDocumentCreatedAsync(
            "document.addEventListener('mousedown', function(e) {" +
            "  var el = e.target;" +
            "  if (!el.closest('.tb-tab') && !el.closest('.tb-wbtn') &&" +
            "      !el.closest('.tb-wbtn-close') && !el.closest('.tb-right') &&" +
            "      !el.closest('.tb-sysinfo') && el.closest('.tb-pill')) {" +
            "    window.chrome.webview.postMessage('DRAG');" +
            "  }" +
            "});"
        );

        string dir  = AppDomain.CurrentDomain.BaseDirectory;
        string html = System.IO.Path.Combine(dir, "interface.html");
        _wv.CoreWebView2.Navigate("file:///" + html.Replace('\\', '/'));
    }

    // ── JS -> C# messages ────────────────────────────────────────────────
    void OnWebMessage(object sender, CoreWebView2WebMessageReceivedEventArgs e)
    {
        string msg = e.TryGetWebMessageAsString();
        switch (msg)
        {
            case "DRAG":
                if (WindowState == FormWindowState.Normal) {
                    ReleaseCapture();
                    SendMessage(Handle, WM_NCLBUTTONDOWN, (IntPtr)HTCAPTION, IntPtr.Zero);
                }
                break;
            case "MINIMIZE": WindowState = FormWindowState.Minimized; break;
            case "MAXIMIZE":
                WindowState = WindowState == FormWindowState.Maximized
                    ? FormWindowState.Normal : FormWindowState.Maximized;
                break;
            case "CLOSE":      StopScan(); Close(); break;
            case "START_SCAN": StartScan(); break;
            case "STOP_SCAN":  StopScan(); ExecJS("scanStopped()"); break;
            case "GET_SYSINFO":
                string host = Environment.MachineName;
                string user = Environment.UserName;
                Version ver  = Environment.OSVersion.Version;
                string os   = "Windows " + (ver.Major == 10 && ver.Build >= 22000 ? "11" : ver.Major.ToString());
                string esc  = (host + " — " + user + " — " + os).Replace("'", "\\'");
                ExecJS("setSysInfo('" + esc + "')");
                break;
        }
    }

    // ── Scan : launch PS1, stream stdout line by line ────────────────────
    void StartScan()
    {
        StopScan();
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string ps1 = System.IO.Path.Combine(dir, "AntiCheat_AIO.ps1");

        _scanProc = new Process {
            StartInfo = new ProcessStartInfo {
                FileName               = "powershell.exe",
                Arguments              = "-ExecutionPolicy Bypass -NonInteractive -File \"" + ps1 + "\"",
                UseShellExecute        = false,
                CreateNoWindow         = true,
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
                StandardOutputEncoding = System.Text.Encoding.UTF8,
                StandardErrorEncoding  = System.Text.Encoding.UTF8,
            },
            EnableRaisingEvents = true
        };

        _scanProc.OutputDataReceived += OnScanOutput;
        _scanProc.ErrorDataReceived  += OnScanError;
        _scanProc.Start();
        _scanProc.BeginOutputReadLine();
        _scanProc.BeginErrorReadLine();
        _scanRunning = true;
    }

    void StopScan()
    {
        _scanRunning = false;
        if (_scanProc != null) {
            try { _scanProc.CancelOutputRead(); } catch { }
            try { _scanProc.CancelErrorRead();  } catch { }
            try { if (!_scanProc.HasExited) _scanProc.Kill(); } catch { }
            _scanProc = null;
        }
    }

    // stdout : chaque ligne du PS1 arrive ici en temps réel
    void OnScanOutput(object sender, DataReceivedEventArgs e)
    {
        if (e.Data == null) {
            // flux fermé = PS1 terminé
            _scanRunning = false;
            if (IsHandleCreated)
                BeginInvoke((Action)(() => ExecJS("scanFinished()")));
        } else {
            SendLineToJS(e.Data);
        }
    }

    // stderr : erreurs PowerShell (parse error, runtime error) visibles dans la console
    void OnScanError(object sender, DataReceivedEventArgs e)
    {
        if (e.Data == null || e.Data.Trim().Length == 0) return;
        SendLineToJS("  [HIGH] PS-ERREUR : " + e.Data);
    }

    void SendLineToJS(string line)
    {
        string esc = line
            .Replace("\\", "\\\\")
            .Replace("'",  "\\'")
            .Replace("\r", "")
            .Replace("\n", " ");
        if (IsHandleCreated)
            BeginInvoke((Action)(() => ExecJS("receiveLine('" + esc + "')")));
    }

    void ExecJS(string js)
    {
        if (_wv.CoreWebView2 != null)
            _wv.CoreWebView2.ExecuteScriptAsync(js);
    }
}
