# N8N Student Kit

Self-hosted **n8n** automation stack wrapped in a one-click Windows GUI. Designed for
students and hobbyists who want a local n8n instance exposed through **ngrok**, with
**Docker Desktop** doing the heavy lifting underneath.

> Currently Windows-only (PowerShell + WPF). macOS/Linux ports are on the roadmap.

---

## What's inside

```
N8N-Workstation/
├── n8n-student-kit/            # backend: install / start / stop scripts + state
│   ├── install.bat             # sets up Docker, ngrok, n8n image
│   ├── start.bat               # launches the stack
│   ├── stop.bat                # graceful shutdown
│   ├── uninstall-local.bat
│   ├── gui-run.cmd             # headless wrapper used by the GUIs
│   ├── compose/                # docker-compose for n8n + ngrok
│   ├── templates/              # env templates
│   ├── tools/                  # ngrok.exe + Docker installer (gitignored)
│   ├── state/                  # runtime .env, cfg, logs (gitignored)
│   └── N8N-Student-Kit-GUI.ps1 # classic WinForms GUI
│
└── n8n-student-kit-preview/    # frontend: modern WPF GUI (Fluent dark theme)
    ├── MainWindow.xaml
    ├── N8N-Student-Kit-WPF.ps1
    ├── start-wpf.bat
    ├── start-wpf.vbs           # silent launcher (no console window)
    └── README.md
```

## Requirements

- **Windows 10 1607+** or **Windows 11**
- **PowerShell 5.1** (built-in) or PowerShell 7+
- Admin rights (for Docker Desktop install + WSL2)
- Free [ngrok account](https://dashboard.ngrok.com/) for a reserved domain + authtoken

## Quick start

1. Clone this repo:
   ```bash
   git clone https://github.com/Phill1983/N8N-Student-Kit.git
   cd N8N-Student-Kit
   ```
2. Download `ngrok.exe` into `n8n-student-kit/tools/` (or let `install.bat` fetch it).
3. Run the WPF GUI:
   ```cmd
   n8n-student-kit-preview\start-wpf.vbs
   ```
4. In the GUI: fill the fields → **Save** → **Install (Admin)** (twice — Docker, then the rest) → **Start**.
5. Open the printed ngrok URL in your browser and log in with your BASIC_AUTH creds.

## Two GUIs, one backend

Both GUIs share the same `state/` folder and the same `.bat` backend:

| GUI                           | Stack              | Look                          |
|-------------------------------|--------------------|-------------------------------|
| `N8N-Student-Kit-GUI.ps1`     | WinForms + GDI+    | classic, compact              |
| `N8N-Student-Kit-WPF.ps1`     | WPF + XAML         | modern Fluent dark theme      |

Pick whichever you prefer — switching is safe, they read/write the same config.

## Configuration

The GUI writes `n8n-student-kit/state/install.cfg` with:

- **Drive letter** — where `<Drive>:\n8n-data` will live
- **NGROK_DOMAIN** — your reserved ngrok domain (e.g. `my-n8n.ngrok-free.dev`)
- **NGROK_AUTHTOKEN** — from ngrok dashboard
- **BASIC_AUTH_USER / PASSWORD** — the login prompt guarding the n8n UI

On install these get baked into `state/.env` which is consumed by docker-compose.

## Roadmap

- [ ] macOS version (Avalonia UI or Tauri)
- [ ] Linux build
- [ ] Auto-update ngrok binary
- [ ] One-click backup / restore of workflows

## License

TBD.
