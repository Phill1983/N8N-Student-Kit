# N8N Student Kit — WPF edition

Паралельний варіант GUI на WPF. Повна функціональність WinForms-версії з сусідньої теки `n8n-student-kit/`, але з модерним темним дизайном: Fluent-типографіка, glass cards, Segoe MDL2 іконки, stage-stepper, status pills, анімований progress-бар.

**Важливо:** ця версія не має власних `.bat`-скриптів і не ставить нічого самостійно. Вона викликає ті самі `gui-run.cmd`, `install.bat`, `start.bat`, `stop.bat`, `uninstall-local.bat` з сусідньої теки `..\n8n-student-kit\`. Тож обидва GUI (WinForms і WPF) керують одним тим самим інсталяційним набором і однією конфігурацією `state\install.cfg`.

## Структура

| Файл | Призначення |
|---|---|
| `MainWindow.xaml` | WPF-розмітка (темна тема, стилі, стейти) |
| `N8N-Student-Kit-WPF.ps1` | PowerShell, який вантажить XAML і підв'язує логіку |
| `start-wpf.bat` | Запуск з BAT (закриває консоль одразу) |
| `start-wpf.vbs` | Абсолютно тихий запуск (без миготіння консолі) |

## Як запустити

1. Впевнись, що поряд лежить оригінальна тека `n8n-student-kit/` з `gui-run.cmd` та рештою файлів (вона потрібна).
2. Подвійний клік по `start-wpf.vbs` (найтихіше) або `start-wpf.bat`.
3. Або з PowerShell:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\N8N-Student-Kit-WPF.ps1
   ```

## Функціональність

Усе те саме, що в WinForms-версії:
- Зчитування / запис `state\install.cfg` (5 полів конфігу)
- Поля `NGROK_AUTHTOKEN` та `BASIC_AUTH_PASSWORD` замасковано (PasswordBox)
- 11 кнопок: Save / Install (Admin) / Start / Start (no browser) / Stop / Cleanup / Open URL / Refresh / Doctor / Install log / CMD
- Двоетапний Install з модальним діалогом після `[NEXT]` в логу (Docker → друге натискання → ngrok + n8n)
- Приховані CMD-вікна для фонових процесів (`ProcessStartInfo.CreateNoWindow = true` / `WindowStyle = Hidden`)
- Тайлінг логу в реальному часі (раз в секунду DispatcherTimer)
- `Doctor` діагностика: `docker --version`, `docker info`, стан контейнера `n8n`
- `Refresh` перевіряє наявність інсталятора Docker, ngrok.exe та n8n-образа

## Візуальні фічі понад WinForms

- **Темна тема** Fluent-стиль з glass cards (`CornerRadius=14`, drop-shadow, напівпрозора рамка)
- **Градієнтна шапка** `#1B2236 → #3A1F56` з SegoeMDL2 spark-іконкою
- **Кастомний GO|IT лого** — відмальований `Path`+`Rectangle` прямо в XAML (без зображень)
- **Stage stepper** з 4 станів: Configure → Install → Finalize → Launch n8n; активний крок має фіолетовий accent-glow, пройдений — зелений круг з галочкою
- **Status pills** з кольоровими dot-індикаторами (OK зелений / MISSING червоний)
- **Анімований progress bar** — accent-градієнт з drop-shadow, плавно рухається під час виконання задач (замість маркі-стилю WinForms)
- **Header pill "Idle / Installing / Running / Stopping / Cleaning"** — у правому верхньому куті
- **Live indicator** біля заголовка Activity — крапка + слово ("idle" / "live")
- **Monospace log** на темній підкладці `#0A0D16` з горизонтальним скролом
- **Focus highlight** на полях вводу — рамка змінюється на accent при фокусі
- **Hover/pressed стани** для всіх кнопок

## Файли конфігурації

`install.cfg` та всі `gui-*.log` зберігаються в `..\n8n-student-kit\state\` — спільно з WinForms-версією. Можеш відкривати обидва GUI по черзі, конфіг не загубиться.

## Наступні можливі покращення (не реалізовано)

- Toast-повідомлення замість `MessageBox` для ненав'язливих сповіщень
- Анімація переходів між стадіями stepper
- Темно-світла перемикачка теми
- Автоматичне оновлення status pills за розкладом
- Підтримка DPI-scaling тестів на 4K / 200%
- Рев'ю-ефекти від ModernWpf/MahApps (потребує DLL)
