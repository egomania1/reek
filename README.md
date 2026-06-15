# Reek — Anti-Cheat Scanner

Desktop forensic scanner for Windows. Detects cheat traces across 35 verification sections using native Windows artifacts.

## What it checks

| Category | Sections |
|----------|----------|
| Forensic artifacts | Prefetch, Amcache, Shimcache, UserAssist, BAM, DAM, Jump Lists |
| Files & folders | Recent files, Temp, Downloads, Recycle Bin, known folders |
| Persistence | Run/RunOnce registry, Services, Startup folders |
| Processes | Active processes, loaded DLLs, injections, handle counts |
| Drivers | Unsigned drivers, recent drivers, kernel services |
| Network | DNS cache, TCP connections, firewall rules, hosts file |
| System | Windows Defender integrity, virtualization, Windows event logs |
| Tools | Debuggers, memory editors, packet sniffers |

## Stack

- **C#** + WinForms + WebView2 — borderless desktop window
- **PowerShell** — 35-section forensic scanner (`AntiCheat_AIO.ps1`)
- **HTML/CSS/JS** — liquid glass UI rendered inside WebView2

## Build

Requires .NET Framework 4 and WebView2 runtime.

```
powershell -ExecutionPolicy Bypass -File compiler.ps1
```

The DLLs (`Microsoft.Web.WebView2.*.dll`, `WebView2Loader.dll`) must be present in the same folder.

## Output levels

| Level | Meaning |
|-------|---------|
| `[HIGH]` | Strong indicator of cheat presence |
| `[MEDIUM]` | Suspicious — requires manual review |
| `[LOW]` | Informational |
| `[OK]` | Clean |

Scan results and history are stored locally in WebView2 localStorage.
