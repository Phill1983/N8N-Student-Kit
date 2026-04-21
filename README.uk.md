<div align="right">

[English](README.md) · **Українська**

</div>

# N8N Student Kit

Self-hosted **n8n**-стек у форматі Windows-застосунку з GUI "на одну кнопку". Зроблено
для студентів і ентузіастів, які хочуть підняти локальний n8n, виставлений назовні через
**ngrok**, з **Docker Desktop** у ролі робочого коня.

> Наразі лише під Windows (PowerShell + WPF). macOS / Linux — у roadmap.

---

## Що всередині

```
N8N-Workstation/
├── n8n-student-kit/            # бекенд: скрипти install/start/stop + state
│   ├── install.bat             # ставить Docker, ngrok, n8n image (авто-завантаження)
│   ├── start.bat               # запускає стек
│   ├── stop.bat                # м'яке вимкнення
│   ├── uninstall-local.bat
│   ├── gui-run.cmd             # headless-обгортка для GUI
│   ├── compose/                # docker-compose для n8n + ngrok
│   ├── templates/              # env-шаблони
│   ├── tools/                  # ngrok.exe + Docker installer (gitignore, авто-завант.)
│   ├── state/                  # runtime .env, cfg, логи (gitignore)
│   └── N8N-Student-Kit-GUI.ps1 # класичний WinForms GUI
│
└── n8n-student-kit-preview/    # фронтенд: сучасний WPF GUI (Fluent dark)
    ├── MainWindow.xaml
    ├── N8N-Student-Kit-WPF.ps1
    ├── start-wpf.bat
    ├── start-wpf.vbs           # тихий запуск без чорної консолі
    └── README.md
```

## Вимоги

- **Windows 10 1607+** або **Windows 11** (x64 чи ARM64)
- **PowerShell 5.1** (вбудований) або PowerShell 7+
- Права адміністратора (для встановлення Docker Desktop і WSL2)
- Безкоштовний акаунт [ngrok](https://dashboard.ngrok.com/) — потрібні зарезервований домен і authtoken

## Швидкий старт

1. Склонуй репозиторій:
   ```bash
   git clone https://github.com/Phill1983/N8N-Student-Kit.git
   cd N8N-Student-Kit
   ```
2. Запусти WPF-GUI:
   ```cmd
   n8n-student-kit-preview\start-wpf.vbs
   ```
3. У GUI: заповни поля → **Save** → **Install (Admin)**.
   - Інсталятор сам завантажить **Docker Desktop** (~600 MB) і **ngrok** (~15 MB) з офіційних джерел, якщо їх немає в `tools/`. Для офлайн-установки можна покласти їх туди вручну.
   - **Install (Admin)** треба натиснути двічі — спочатку встановиться Docker Desktop (можливе перезавантаження), потім налаштується ngrok, створиться `.env` і завантажиться n8n image з Docker Hub.
4. Натисни **Start**, відкрий у браузері ngrok-URL, залогінься через BASIC_AUTH.

### Офлайн-встановлення

Якщо на машині немає інтернету, поклади у `n8n-student-kit/tools/` вручну:

- `Docker Desktop Installer.exe` — з https://www.docker.com/products/docker-desktop/
- `ngrok.exe` — з https://ngrok.com/download
- Опціонально: `images/n8n-<версія>.tar`, створений командою
  ```bash
  docker save n8nio/n8n:<версія> -o n8n-<версія>.tar
  ```
  на онлайн-машині

Інсталятор побачить файли і пропустить крок завантаження. n8n image буде підхоплений
через `docker load -i` замість `docker pull`.

## Два GUI, один бекенд

Обидва GUI використовують ту саму папку `state/` і той самий `.bat`-бекенд. Можна
переключатися між ними в будь-який момент — читаючи і пишучи один і той же конфіг.

| GUI                           | Стек               | Вигляд                        |
|-------------------------------|--------------------|-------------------------------|
| `N8N-Student-Kit-GUI.ps1`     | WinForms + GDI+    | класичний, компактний         |
| `N8N-Student-Kit-WPF.ps1`     | WPF + XAML         | сучасна Fluent dark-тема      |

## Конфігурація

GUI зберігає `n8n-student-kit/state/install.cfg` з:

- **Drive letter** — диск, на якому буде `<Диск>:\n8n-data` (монтується в контейнер)
- **NGROK_DOMAIN** — твій зарезервований ngrok-домен (напр. `my-n8n.ngrok-free.dev`)
- **NGROK_AUTHTOKEN** — з ngrok dashboard
- **BASIC_AUTH_USER** / **BASIC_AUTH_PASSWORD** — логін-пароль на вхід в n8n UI

Під час установки ці значення запікаються у `state/.env`, який читає docker-compose.

> **Увага**: папку `state/` і всі `*.env` навмисне виключено з git. Ніколи не комітьте
> свої токени.

## Типові проблеми

- **"Docker daemon not reachable"** одразу після встановлення — Docker Desktop ще
  піднімається. Зачекай до 5 хвилин; інсталятор сам пінгує `docker info` кожні 3 секунди.
- **Потрібне перезавантаження** — коли інсталятор вмикає компоненти WSL2, Windows
  зазвичай просить ребут. Після нього знову запусти `Install (Admin)`.
- **`start.bat` падає з "state\.env not found"** — ти пропустив `Install`. WPF-GUI у
  цьому випадку одразу блокує `Start` і показує попередження.

## Roadmap

- [ ] Версія під macOS (Avalonia UI або Tauri)
- [ ] Збірка під Linux
- [ ] Авто-оновлення ngrok-бінарника
- [ ] Бекап / відновлення workflow-ів в один клік

## Ліцензія

TBD.
