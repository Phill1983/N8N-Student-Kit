<div align="right">

**English** · [Українська](README.uk.md)

</div>

# N8N Student Kit

Self-hosted **n8n** automation stack wrapped in a one-click Windows GUI. Designed for
students and hobbyists who want a local n8n instance exposed through **ngrok**, with
**Docker Desktop** doing the heavy lifting underneath.

> Currently Windows-only (PowerShell + WPF). macOS / Linux ports are on the roadmap.

---

## What's inside

```
N8N-Workstation/
├── n8n-student-kit/            # backend: install / start / stop scripts + state
│   ├── install.bat             # sets up Docker, ngrok, n8n image (auto-downloads tools)
│   ├── start.bat               # launches the stack
│   ├── stop.bat                # graceful shutdown
│   ├── uninstall-local.bat
│   ├── gui-run.cmd             # headless wrapper used by the GUIs
│   ├── compose/                # docker-compose for n8n + ngrok
│   ├── templates/              # env templates
│   ├── tools/                  # ngrok.exe + Docker installer (gitignored, auto-fetched)
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

- **Windows 10 1607+** or **Windows 11** (x64 or ARM64)
- **PowerShell 5.1** (built-in) or PowerShell 7+
- Admin rights (for Docker Desktop install and WSL2)
- Free [ngrok account](https://dashboard.ngrok.com/) for a reserved domain and authtoken

## Quick start

1. Clone this repo:
   ```bash
   git clone https://github.com/Phill1983/N8N-Student-Kit.git
   cd N8N-Student-Kit
   ```
2. Run the WPF GUI:
   ```cmd
   n8n-student-kit-preview\start-wpf.vbs
   ```
3. In the GUI: fill the fields → **Save** → **Install (Admin)**.
   - The installer auto-downloads **Docker Desktop** (~600 MB) and **ngrok** (~15 MB) from their official sources if they're missing in `tools/`. You can also drop them in manually for offline install.
   - Expect to click **Install (Admin)** twice — first pass installs Docker Desktop (may require a reboot), second pass sets up ngrok, `.env`, and pulls the n8n image from Docker Hub.
4. Click **Start**, open the printed ngrok URL in your browser, and log in with your BASIC_AUTH creds.

### Offline install

If the target machine has no internet, put these files into `n8n-student-kit/tools/` manually:

- `Docker Desktop Installer.exe` — from https://www.docker.com/products/docker-desktop/
- `ngrok.exe` — from https://ngrok.com/download
- Optional: `images/n8n-<version>.tar` produced by
  ```bash
  docker save n8nio/n8n:<ver> -o n8n-<ver>.tar
  ```
  on an online machine

The installer will detect them and skip the download step. The n8n image will be loaded
via `docker load -i` instead of `docker pull`.

## Two GUIs, one backend

Both GUIs share the same `state/` folder and the same `.bat` backend. You can switch
between them at any time — they read and write the same config.

| GUI                           | Stack              | Look                          |
|-------------------------------|--------------------|-------------------------------|
| `N8N-Student-Kit-GUI.ps1`     | WinForms + GDI+    | classic, compact              |
| `N8N-Student-Kit-WPF.ps1`     | WPF + XAML         | modern Fluent dark theme      |

## Configuration

The GUI writes `n8n-student-kit/state/install.cfg` with:

- **Drive letter** — where `<Drive>:\n8n-data` will live (bind-mounted into the container)
- **NGROK_DOMAIN** — your reserved ngrok domain (e.g. `my-n8n.ngrok-free.dev`)
- **NGROK_AUTHTOKEN** — from the ngrok dashboard
- **BASIC_AUTH_USER** / **BASIC_AUTH_PASSWORD** — credentials guarding the n8n UI

On install these get baked into `state/.env` which is consumed by docker-compose.

> **Heads-up**: `state/` and all `*.env` files are gitignored by design. Never commit
> your tokens.

## Troubleshooting

- **"Docker daemon not reachable"** right after install — Docker Desktop still booting.
  Wait up to 5 minutes; the installer polls `docker info` every 3 seconds.
- **Reboot needed** — when the installer enables WSL2 features, Windows typically asks
  for a restart. After reboot, run `Install (Admin)` again.
- **`start.bat` fails with "state\.env not found"** — you skipped `Install`. The WPF GUI
  now blocks `Start` in this case with a clear message.

## Roadmap

- [ ] macOS version (Avalonia UI or Tauri)
- [ ] Linux build
- [ ] Auto-update ngrok binary
- [ ] One-click backup / restore of workflows

## License

TBD.
