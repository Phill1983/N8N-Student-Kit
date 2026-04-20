Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class DpiAware {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
    [DllImport("shcore.dll")]
    public static extern int SetProcessDpiAwareness(int value);
    public static void Enable() {
        try { SetProcessDpiAwareness(2); } catch { try { SetProcessDPIAware(); } catch {} }
    }
}
public static class ThemeHelper {
    [DllImport("uxtheme.dll", CharSet=CharSet.Unicode)]
    public static extern int SetWindowTheme(IntPtr hWnd, string app, string idList);
    public static void Disable(IntPtr hWnd) { SetWindowTheme(hWnd, " ", " "); }
}
"@ -ErrorAction SilentlyContinue
    [DpiAware]::Enable()
} catch {}

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# --- theme (light, modern) - ASCII-only strings for PS 5.1 compatibility ---
$script:ColBg       = [System.Drawing.Color]::FromArgb(245, 247, 250)
$script:ColSurface  = [System.Drawing.Color]::White
$script:ColAccent   = [System.Drawing.Color]::FromArgb(79, 70, 229)
$script:ColAccentHi = [System.Drawing.Color]::FromArgb(99, 102, 241)
$script:ColText     = [System.Drawing.Color]::FromArgb(30, 41, 59)
$script:ColMuted    = [System.Drawing.Color]::FromArgb(100, 116, 139)
$script:ColOk       = [System.Drawing.Color]::FromArgb(5, 150, 105)
$script:ColBad      = [System.Drawing.Color]::FromArgb(220, 38, 38)
$script:ColLogBg    = [System.Drawing.Color]::FromArgb(252, 252, 253)
$script:ColHeader   = [System.Drawing.Color]::FromArgb(51, 65, 85)

$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateDir = Join-Path $baseDir "state"
$toolsDir = Join-Path $baseDir "tools"
$configPath = Join-Path $stateDir "install.cfg"
$installBat = Join-Path $baseDir "install.bat"
$guiRunCmd = Join-Path $baseDir "gui-run.cmd"
$startBat = Join-Path $baseDir "start.bat"
$stopBat = Join-Path $baseDir "stop.bat"
$cleanupBat = Join-Path $baseDir "uninstall-local.bat"

if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir | Out-Null }

function Read-Config {
    $map = @{}
    if (Test-Path $configPath) {
        Get-Content -LiteralPath $configPath | ForEach-Object {
            if ($_ -match "^(.*?)=(.*)$") { $map[$matches[1]] = $matches[2] }
        }
    }
    $map
}

function Save-Config($drive, $domain, $token, $user, $pass) {
    $d = $drive.Trim().ToUpper()
    if (-not $d) { $d = "D" }
    $lines = @(
        "INSTALL_DRIVE=$d"
        "N8N_DATA=$d`:\n8n-data"
        "NGROK_DOMAIN=$domain"
        "NGROK_AUTHTOKEN=$token"
        "N8N_BASIC_AUTH_USER=$user"
        "N8N_BASIC_AUTH_PASSWORD=$pass"
    )
    Set-Content -Path $configPath -Value $lines -Encoding ASCII
}

function Set-Status($label, $ok, $text) {
    $label.Text = $text
    $label.ForeColor = if ($ok) { $script:ColOk } else { $script:ColBad }
}

function Apply-ButtonPrimary($btn) {
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = $script:ColAccent
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btn.Add_MouseEnter({ $this.BackColor = $script:ColAccentHi })
    $btn.Add_MouseLeave({ $this.BackColor = $script:ColAccent })
}

function Apply-ButtonSecondary($btn) {
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(203, 213, 225)
    $btn.BackColor = $script:ColSurface
    $btn.ForeColor = $script:ColText
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
}

function Start-CommandWithLog($cmdLine, $asAdmin, $logPath, $statusLabel) {
    try {
        if (Test-Path $logPath) { Remove-Item $logPath -Force }
    } catch {}

    $script:tailPath = $logPath
    $script:tailLineCount = 0
    $script:lastFileLineCount = -1
    $script:stableLogTicks = 0
    $script:progressBar.Visible = $true
    $script:progressBar.Style = "Marquee"
    $timer.Start()

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/c " + $cmdLine
    $psi.WorkingDirectory = $baseDir
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    if ($asAdmin) {
        $psi.UseShellExecute = $true
        $psi.Verb = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            $statusLabel.Text = "Elevated task running - tailing log below."
        } catch [System.ComponentModel.Win32Exception] {
            $statusLabel.Text = "UAC was declined."
            Add-Log "UAC was declined - install cancelled."
            $timer.Stop()
            $script:progressBar.Visible = $false
        }
    } else {
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        $statusLabel.Text = "Task running - tailing log below."
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "N8N Student Kit"
$form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.ClientSize = New-Object System.Drawing.Size(780, 720)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = $script:ColBg
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$header = New-Object System.Windows.Forms.Panel
$header.Height = 78
$header.Dock = "Top"
$header.BackColor = $script:ColHeader
$ttl = New-Object System.Windows.Forms.Label
$ttl.Text = "N8N Student Kit"
$ttl.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11.5, [System.Drawing.FontStyle]::Bold)
$ttl.ForeColor = [System.Drawing.Color]::White
$ttl.Location = New-Object System.Drawing.Point(20, 12)
$ttl.AutoSize = $true

$ttlFor = New-Object System.Windows.Forms.Label
$ttlFor.Text = "for"
$ttlFor.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12, [System.Drawing.FontStyle]::Bold)
$ttlFor.ForeColor = [System.Drawing.Color]::White
$ttlFor.Location = New-Object System.Drawing.Point(20, 12)
$ttlFor.AutoSize = $true

$ttlLogo = New-Object System.Windows.Forms.Panel
$ttlLogo.Size = New-Object System.Drawing.Size(56, 24)
$ttlLogo.Location = New-Object System.Drawing.Point(20, 10)
$ttlLogo.BackColor = $script:ColHeader

try {
    $_dbProp = [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic,Instance')
    if ($_dbProp) { $_dbProp.SetValue($ttlLogo, $true, $null) }
} catch {}

$ttlLogo.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $w = [int]$sender.Width
    $h = [int]$sender.Height

    $parentBg = if ($sender.Parent) { $sender.Parent.BackColor } else { $sender.BackColor }
    $bgBrush = [System.Drawing.SolidBrush]::new($parentBg)
    $g.FillRectangle($bgBrush, 0, 0, $w, $h)
    $bgBrush.Dispose()

    $plaque    = [System.Drawing.Color]::White
    $textColor = [System.Drawing.Color]::FromArgb(40, 41, 51)
    $plaqueBrush = [System.Drawing.SolidBrush]::new($plaque)
    $textBrush   = [System.Drawing.SolidBrush]::new($textColor)

    $nib = [int]([math]::Max(8, [math]::Round($h * 0.55)))
    $gap = [int]([math]::Max(6, [math]::Round($h * 0.28)))
    $xR  = [int]((($w + $gap) / 2))
    $xL  = $xR - $gap
    $mid = [int]($h / 2)

    $ptsL = [System.Drawing.Point[]]@(
        [System.Drawing.Point]::new(0, 0),
        [System.Drawing.Point]::new($xL, 0),
        [System.Drawing.Point]::new(($xL + $nib), $mid),
        [System.Drawing.Point]::new($xL, $h),
        [System.Drawing.Point]::new(0, $h)
    )
    $g.FillPolygon($plaqueBrush, $ptsL)

    $g.FillRectangle($plaqueBrush, $xR, 0, ($w - $xR), $h)
    $plaqueBrush.Dispose()

    $fontPx = [single]([math]::Max(10, $h * 0.48))
    $font = [System.Drawing.Font]::new("Segoe UI", $fontPx, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $sf = [System.Drawing.StringFormat]::new()
    $sf.Alignment     = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $sf.FormatFlags   = [System.Drawing.StringFormatFlags]::NoClip

    $leftCx  = [single](($xL + $nib / 2.0) / 2.0)
    $rightCx = [single]($xR + ($w - $xR) / 2.0)
    $textH   = [single]$h
    $textW   = [single]$xL

    $rectL = [System.Drawing.RectangleF]::new(([single]($leftCx - $textW / 2)), [single]0, $textW, $textH)
    $rectR = [System.Drawing.RectangleF]::new(([single]($rightCx - $textW / 2)), [single]0, $textW, $textH)

    $g.DrawString("GO", $font, $textBrush, $rectL, $sf)
    $g.DrawString("IT", $font, $textBrush, $rectR, $sf)

    $font.Dispose()
    $sf.Dispose()
    $textBrush.Dispose()
})

$sub = New-Object System.Windows.Forms.Label
$sub.Text = "Self-hosted stack: Docker, n8n, ngrok"
$sub.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$sub.ForeColor = [System.Drawing.Color]::FromArgb(203, 213, 225)
$sub.Location = New-Object System.Drawing.Point(20, 46)
$sub.AutoSize = $true
$header.Controls.Add($ttl)
$header.Controls.Add($ttlFor)
$header.Controls.Add($ttlLogo)
$header.Controls.Add($sub)
$form.Controls.Add($header)

$script:ContentW = 728

$main = New-Object System.Windows.Forms.Panel
$main.Dock = "Fill"
$main.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
$main.BackColor = $script:ColBg
$form.Controls.Add($main)

$contentHost = New-Object System.Windows.Forms.Panel
$contentHost.Width = $script:ContentW
$contentHost.BackColor = $script:ColBg
$contentHost.Top = 92
$main.Controls.Add($contentHost)

function Update-CenteredLayout {
    $mw = $main.ClientSize.Width
    $contentHost.Left = [math]::Max(0, [int](($mw - $contentHost.Width) / 2))
    if ($txtLog) {
        $contentHost.Height = $txtLog.Bottom + 4
    }
    if ($ttl -and $sub -and $header) {
        $hw = $header.ClientSize.Width
        if ($ttlFor -and $ttlLogo) {
            $titleTextW = [System.Windows.Forms.TextRenderer]::MeasureText($ttl.Text, $ttl.Font).Width
            $forTextW   = [System.Windows.Forms.TextRenderer]::MeasureText($ttlFor.Text, $ttlFor.Font).Width
            $gapWord = 6
            $gapLogo = 10
            $total = $titleTextW + $gapWord + $forTextW + $gapLogo + $ttlLogo.Width
            $startX = [int](($hw - $total) / 2)
            $ttl.AutoSize = $false
            $ttl.Size = New-Object System.Drawing.Size($titleTextW, $ttl.Height)
            $ttlFor.AutoSize = $false
            $ttlFor.Size = New-Object System.Drawing.Size($forTextW, $ttlFor.Height)
            $ttl.Left = $startX
            $ttlFor.Left = $startX + $titleTextW + $gapWord
            $ttlLogo.Left = $ttlFor.Left + $forTextW + $gapLogo
            $ttlFor.Top = $ttl.Top + [int](($ttl.Height - $ttlFor.Height) / 2)
            $ttlLogo.Top = $ttl.Top + [int](($ttl.Height - $ttlLogo.Height) / 2)
        } else {
            $ttl.Left = [int](($hw - $ttl.Width) / 2)
        }
        $sub.Left = [int](($hw - $sub.Width) / 2)
    }
}

function Add-Label($parent, $text, $x, $y, $w = 200) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text
    $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, 22)
    $l.ForeColor = $script:ColText
    $parent.Controls.Add($l)
    $l
}

function Add-Text($parent, $x, $y, $w = 430, $masked = $false) {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x, $y)
    $t.Size = New-Object System.Drawing.Size($w, 26)
    $t.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $t.BackColor = $script:ColSurface
    $t.ForeColor = $script:ColText
    if ($masked) { $t.UseSystemPasswordChar = $true }
    $parent.Controls.Add($t)
    $t
}

$boxCfg = New-Object System.Windows.Forms.GroupBox
$boxCfg.Text = " Configuration "
$boxCfg.Location = New-Object System.Drawing.Point(0, 8)
$boxCfg.Size = New-Object System.Drawing.Size($script:ContentW, 242)
$boxCfg.ForeColor = $script:ColMuted
$boxCfg.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$boxCfg.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)
$contentHost.Controls.Add($boxCfg)

$lblCfgHint = New-Object System.Windows.Forms.Label
$lblCfgHint.Text = "n8n will store its data on the selected drive in the folder  \<Drive>:\n8n-data  (e.g. D:\n8n-data). Fill all fields, then Save and Install."
$lblCfgHint.ForeColor = $script:ColMuted
$lblCfgHint.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$lblCfgHint.Location = New-Object System.Drawing.Point(18, 22)
$lblCfgHint.Size = New-Object System.Drawing.Size(690, 32)
$boxCfg.Controls.Add($lblCfgHint)

$y = 56
Add-Label $boxCfg "Drive letter" 18 $y 160 | Out-Null
$txtDrive = Add-Text $boxCfg 190 $y 90 $false
$y += 36
Add-Label $boxCfg "NGROK_DOMAIN" 18 $y 160 | Out-Null
$txtDomain = Add-Text $boxCfg 190 $y 510
$y += 36
Add-Label $boxCfg "NGROK_AUTHTOKEN" 18 $y 160 | Out-Null
$txtToken = Add-Text $boxCfg 190 $y 510 $true
$y += 36
Add-Label $boxCfg "BASIC_AUTH_USER" 18 $y 160 | Out-Null
$txtUser = Add-Text $boxCfg 190 $y 510
$y += 36
Add-Label $boxCfg "BASIC_AUTH_PASSWORD" 18 $y 160 | Out-Null
$txtPass = Add-Text $boxCfg 190 $y 510 $true

$boxAct = New-Object System.Windows.Forms.GroupBox
$boxAct.Text = " Actions "
$boxAct.Location = New-Object System.Drawing.Point(0, 258)
$boxAct.Size = New-Object System.Drawing.Size($script:ContentW, 128)
$boxAct.ForeColor = $script:ColMuted
$boxAct.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$boxAct.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)
$contentHost.Controls.Add($boxAct)

$ay = 28
$gap = 6
$row1w = 108 + 124 + 88 + 138 + 72 + 88 + (5 * $gap)
$r1x = [int](($script:ContentW - $row1w) / 2)
$bx = $r1x
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save Config"
$btnSave.Location = New-Object System.Drawing.Point($bx, $ay)
$btnSave.Size = New-Object System.Drawing.Size(108, 32)
Apply-ButtonSecondary $btnSave
$boxAct.Controls.Add($btnSave)
$bx += 108 + $gap

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install (Admin)"
$btnInstall.Location = New-Object System.Drawing.Point($bx, $ay)
$btnInstall.Size = New-Object System.Drawing.Size(124, 32)
Apply-ButtonPrimary $btnInstall
$boxAct.Controls.Add($btnInstall)
$bx += 124 + $gap

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start"
$btnStart.Location = New-Object System.Drawing.Point($bx, $ay)
$btnStart.Size = New-Object System.Drawing.Size(88, 32)
Apply-ButtonSecondary $btnStart
$boxAct.Controls.Add($btnStart)
$bx += 88 + $gap

$btnStartNoBrowser = New-Object System.Windows.Forms.Button
$btnStartNoBrowser.Text = "Start (no browser)"
$btnStartNoBrowser.Location = New-Object System.Drawing.Point($bx, $ay)
$btnStartNoBrowser.Size = New-Object System.Drawing.Size(138, 32)
Apply-ButtonSecondary $btnStartNoBrowser
$boxAct.Controls.Add($btnStartNoBrowser)
$bx += 138 + $gap

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "Stop"
$btnStop.Location = New-Object System.Drawing.Point($bx, $ay)
$btnStop.Size = New-Object System.Drawing.Size(72, 32)
Apply-ButtonSecondary $btnStop
$boxAct.Controls.Add($btnStop)
$bx += 72 + $gap

$btnCleanup = New-Object System.Windows.Forms.Button
$btnCleanup.Text = "Cleanup"
$btnCleanup.Location = New-Object System.Drawing.Point($bx, $ay)
$btnCleanup.Size = New-Object System.Drawing.Size(88, 32)
Apply-ButtonSecondary $btnCleanup
$boxAct.Controls.Add($btnCleanup)

$ay2 = 70
$bx2 = $r1x
$btnOpen = New-Object System.Windows.Forms.Button
$btnOpen.Text = "Open URL"
$btnOpen.Location = New-Object System.Drawing.Point($bx2, $ay2)
$btnOpen.Size = New-Object System.Drawing.Size(108, 32)
Apply-ButtonSecondary $btnOpen
$boxAct.Controls.Add($btnOpen)
$bx2 += 108 + $gap

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh"
$btnRefresh.Location = New-Object System.Drawing.Point($bx2, $ay2)
$btnRefresh.Size = New-Object System.Drawing.Size(124, 32)
Apply-ButtonSecondary $btnRefresh
$boxAct.Controls.Add($btnRefresh)
$bx2 += 124 + $gap

$btnDoctor = New-Object System.Windows.Forms.Button
$btnDoctor.Text = "Doctor"
$btnDoctor.Location = New-Object System.Drawing.Point($bx2, $ay2)
$btnDoctor.Size = New-Object System.Drawing.Size(88, 32)
Apply-ButtonSecondary $btnDoctor
$boxAct.Controls.Add($btnDoctor)
$bx2 += 88 + $gap

$btnOpenInstallLog = New-Object System.Windows.Forms.Button
$btnOpenInstallLog.Text = "Open install log"
$btnOpenInstallLog.Location = New-Object System.Drawing.Point($bx2, $ay2)
$btnOpenInstallLog.Size = New-Object System.Drawing.Size(138, 32)
Apply-ButtonSecondary $btnOpenInstallLog
$boxAct.Controls.Add($btnOpenInstallLog)
$bx2 += 138 + $gap

$btnOpenCmd = New-Object System.Windows.Forms.Button
$btnOpenCmd.Text = "CMD"
$btnOpenCmd.Location = New-Object System.Drawing.Point($bx2, $ay2)
$btnOpenCmd.Size = New-Object System.Drawing.Size(72, 32)
Apply-ButtonSecondary $btnOpenCmd
$boxAct.Controls.Add($btnOpenCmd)
$bx2 += 72 + $gap

$statLeft = $bx2
$statW = ($r1x + $row1w) - $statLeft
$statBaseY = $boxAct.Location.Y + $ay2
$lblDocker = New-Object System.Windows.Forms.Label
$lblDocker.Location = New-Object System.Drawing.Point($statLeft, $statBaseY)
$lblDocker.Size = New-Object System.Drawing.Size($statW, 20)
$lblDocker.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblDocker.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lblDocker.BackColor = $script:ColBg
$contentHost.Controls.Add($lblDocker)
$lblDocker.BringToFront()

$lblNgrok = New-Object System.Windows.Forms.Label
$lblNgrok.Location = New-Object System.Drawing.Point($statLeft, ($statBaseY + 22))
$lblNgrok.Size = New-Object System.Drawing.Size($statW, 20)
$lblNgrok.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblNgrok.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lblNgrok.BackColor = $script:ColBg
$contentHost.Controls.Add($lblNgrok)
$lblNgrok.BringToFront()

$lblImage = New-Object System.Windows.Forms.Label
$lblImage.Location = New-Object System.Drawing.Point($statLeft, ($statBaseY + 44))
$lblImage.Size = New-Object System.Drawing.Size($statW, 20)
$lblImage.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
$lblImage.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$lblImage.BackColor = $script:ColBg
$contentHost.Controls.Add($lblImage)
$lblImage.BringToFront()

$flowPanel = New-Object System.Windows.Forms.Panel
$flowPanel.Location = New-Object System.Drawing.Point(0, 394)
$flowPanel.Size = New-Object System.Drawing.Size($script:ContentW, 52)
$contentHost.Controls.Add($flowPanel)

$lblFlow = New-Object System.Windows.Forms.Label
$lblFlow.Text = "Ready: Save Config, then Install (Admin), then Start."
$lblFlow.Location = New-Object System.Drawing.Point(0, 0)
$lblFlow.Size = New-Object System.Drawing.Size($script:ContentW, 22)
$lblFlow.ForeColor = $script:ColText
$lblFlow.Font = New-Object System.Drawing.Font("Segoe UI", 8.75)
$lblFlow.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$flowPanel.Controls.Add($lblFlow)

$script:progressBar = New-Object System.Windows.Forms.ProgressBar
$script:progressBar.Location = New-Object System.Drawing.Point(0, 28)
$script:progressBar.Size = New-Object System.Drawing.Size($script:ContentW, 18)
$script:progressBar.Style = "Marquee"
$script:progressBar.MarqueeAnimationSpeed = 35
$script:progressBar.Visible = $false
$script:progressBar.ForeColor = $script:ColHeader
$script:progressBar.BackColor = [System.Drawing.Color]::FromArgb(226, 230, 236)
$flowPanel.Controls.Add($script:progressBar)
$script:progressBar.Add_HandleCreated({ [ThemeHelper]::Disable($this.Handle) | Out-Null })

$lblLogTitle = New-Object System.Windows.Forms.Label
$lblLogTitle.Text = "Activity log"
$lblLogTitle.Location = New-Object System.Drawing.Point(0, 452)
$lblLogTitle.Size = New-Object System.Drawing.Size($script:ContentW, 20)
$lblLogTitle.ForeColor = $script:ColMuted
$lblLogTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9, [System.Drawing.FontStyle]::Bold)
$lblLogTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$contentHost.Controls.Add($lblLogTitle)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.Location = New-Object System.Drawing.Point(0, 476)
$txtLog.Size = New-Object System.Drawing.Size($script:ContentW, 134)
$txtLog.BackColor = $script:ColLogBg
$txtLog.ForeColor = $script:ColText
$txtLog.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$contentHost.Controls.Add($txtLog)

$form.Add_Load({ Update-CenteredLayout })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$script:tailPath = $null
$script:tailLineCount = 0
$script:lastFileLineCount = -1
$script:stableLogTicks = 0
$script:installNextNotified = $false

function Add-Log($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    $txtLog.AppendText("[$ts] $msg`r`n")
}

function Refresh-Checks {
    $dockerA = Join-Path $toolsDir "DockerDesktopInstaller.exe"
    $dockerB = Join-Path $toolsDir "Docker Desktop Installer.exe"
    $ngrok = Join-Path $toolsDir "ngrok.exe"
    $img = Join-Path $toolsDir "images\n8n-2.15.0.tar"
    $dockerOk = (Test-Path $dockerA) -or (Test-Path $dockerB)
    $ngrokOk  = Test-Path $ngrok
    $imgOk    = Test-Path $img
    Set-Status $lblDocker $dockerOk ("Docker: " + ($(if ($dockerOk) { "OK" } else { "MISSING" })))
    Set-Status $lblNgrok  $ngrokOk  ("ngrok: "  + ($(if ($ngrokOk)  { "OK" } else { "MISSING" })))
    Set-Status $lblImage  $imgOk    ("N8N: "    + ($(if ($imgOk)    { "OK" } else { "MISSING" })))
}

$timer.Add_Tick({
    if (-not $script:tailPath) {
        $script:progressBar.Visible = $false
        return
    }
    if (-not (Test-Path $script:tailPath)) {
        $lblFlow.Text = "Waiting for log file (confirm UAC if prompted)..."
        return
    }
    $all = @(Get-Content -LiteralPath $script:tailPath -Encoding utf8 -ErrorAction SilentlyContinue)
    if ($all.Count -eq 0) {
        $lblFlow.Text = "Log file starting... (installer can be quiet a few minutes)"
        return
    }
    if ($all.Count -eq $script:lastFileLineCount) {
        $script:stableLogTicks++
        if ($script:stableLogTicks -ge 4) {
            $script:progressBar.Visible = $false
        }
    } else {
        $script:lastFileLineCount = $all.Count
        $script:stableLogTicks = 0
        $script:progressBar.Visible = $true
    }

    $lastLine = $all[$all.Count - 1]
    if ($lastLine.Length -gt 120) { $lastLine = $lastLine.Substring(0, 117) + "..." }
    $hasNext = $false
    foreach ($ln in $all) { if ($ln -match '\[NEXT\]') { $hasNext = $true; break } }
    if ($hasNext -and ($script:tailPath -match 'gui-install\.log$')) {
        $lblFlow.Text = "Docker installed. Click Install (Admin) again to finish setup (ngrok / .env / n8n)."
        if (-not $script:installNextNotified) {
            $script:installNextNotified = $true
            $timer.Stop()
            $script:progressBar.Visible = $false
            $msg = "Docker Desktop was installed successfully." + [Environment]::NewLine + [Environment]::NewLine +
                   "The installer finished its first pass and needs a second run to complete the rest:" + [Environment]::NewLine +
                   "  - ngrok setup" + [Environment]::NewLine +
                   "  - .env generation" + [Environment]::NewLine +
                   "  - n8n container" + [Environment]::NewLine + [Environment]::NewLine +
                   "Click [Install (Admin)] once more to continue. Do NOT press Start yet."
            [void][System.Windows.Forms.MessageBox]::Show($form, $msg, "Docker installed - one more step",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information)
            $timer.Start()
        }
    } else {
        $lblFlow.Text = ("Log: {0} lines | {1}" -f $all.Count, $lastLine)
    }
    if ($all.Count -gt $script:tailLineCount) {
        for ($i = $script:tailLineCount; $i -lt $all.Count; $i++) {
            if ($all[$i]) { $txtLog.AppendText("[log] " + $all[$i] + "`r`n") }
        }
        $script:tailLineCount = $all.Count
    }
})

$cfg = Read-Config
$txtDrive.Text = if ($cfg.ContainsKey("INSTALL_DRIVE")) { $cfg["INSTALL_DRIVE"] } else { "D" }
$txtDomain.Text = if ($cfg.ContainsKey("NGROK_DOMAIN")) { $cfg["NGROK_DOMAIN"] } else { "" }
$txtToken.Text = if ($cfg.ContainsKey("NGROK_AUTHTOKEN")) { $cfg["NGROK_AUTHTOKEN"] } else { "" }
$txtUser.Text = if ($cfg.ContainsKey("N8N_BASIC_AUTH_USER")) { $cfg["N8N_BASIC_AUTH_USER"] } else { "" }
$txtPass.Text = if ($cfg.ContainsKey("N8N_BASIC_AUTH_PASSWORD")) { $cfg["N8N_BASIC_AUTH_PASSWORD"] } else { "" }

$btnSave.Add_Click({
    if (-not $txtDomain.Text.Trim()) { [System.Windows.Forms.MessageBox]::Show("Enter NGROK_DOMAIN"); return }
    if (-not $txtToken.Text.Trim()) { [System.Windows.Forms.MessageBox]::Show("Enter NGROK_AUTHTOKEN"); return }
    if (-not $txtUser.Text.Trim()) { [System.Windows.Forms.MessageBox]::Show("Enter BASIC_AUTH_USER"); return }
    if (-not $txtPass.Text.Trim()) { [System.Windows.Forms.MessageBox]::Show("Enter BASIC_AUTH_PASSWORD"); return }
    Save-Config $txtDrive.Text $txtDomain.Text.Trim() $txtToken.Text.Trim() $txtUser.Text.Trim() $txtPass.Text.Trim()
    Add-Log "Config saved to state/install.cfg"
})

$btnInstall.Add_Click({
    Save-Config $txtDrive.Text $txtDomain.Text.Trim() $txtToken.Text.Trim() $txtUser.Text.Trim() $txtPass.Text.Trim()
    $log = Join-Path $stateDir "gui-install.log"
    $script:installNextNotified = $false
    Add-Log "Starting install (admin)..."
    Add-Log "1) If UAC appears - click Yes. After that gui-run.cmd writes the first line to the log."
    Add-Log "2) Live file: $log"
    Add-Log "3) Installer EXE runs ONLY if docker is not in PATH yet - then look for Docker Desktop Installer.exe."
    Add-Log "   If docker is already installed - we skip that EXE; look for Docker Desktop.exe / com.docker.backend."
    Add-Log "4) Button 'Open install log' opens this file in Notepad (refresh F5 there)."
    Add-Log "5) Docker silent install: usually a few minutes, log updates only when the installer exits."
    Add-Log "6) If the log ends after Docker Desktop install message - click Install (Admin) again (not Start). Start needs .env from a full install run."
    if (-not (Test-Path $guiRunCmd)) { Add-Log "ERROR: gui-run.cmd missing next to this GUI."; return }
    $cmdLine = ('"{0}" install' -f $guiRunCmd)
    Start-CommandWithLog $cmdLine $true $log $lblFlow
})

$btnOpenInstallLog.Add_Click({
    $p = Join-Path $stateDir "gui-install.log"
    if (Test-Path $p) { Start-Process notepad.exe -ArgumentList $p } else { [System.Windows.Forms.MessageBox]::Show("No gui-install.log yet. Run Install (Admin) first.") }
})

$btnOpenCmd.Add_Click({
    Start-Process -FilePath "cmd.exe" -WorkingDirectory $baseDir
    Add-Log "Opened CMD in $baseDir"
})

$btnStart.Add_Click({
    $log = Join-Path $stateDir "gui-start.log"
    Add-Log "Starting start.bat..."
    if (-not (Test-Path $guiRunCmd)) { Add-Log "ERROR: gui-run.cmd missing."; return }
    $cmdLine = ('"{0}" start' -f $guiRunCmd)
    Start-CommandWithLog $cmdLine $false $log $lblFlow
})

$btnStartNoBrowser.Add_Click({
    $log = Join-Path $stateDir "gui-start-no-browser.log"
    Add-Log "Starting start.bat --no-browser..."
    if (-not (Test-Path $guiRunCmd)) { Add-Log "ERROR: gui-run.cmd missing."; return }
    $cmdLine = ('"{0}" startnb' -f $guiRunCmd)
    Start-CommandWithLog $cmdLine $false $log $lblFlow
})

$btnStop.Add_Click({
    $log = Join-Path $stateDir "gui-stop.log"
    Add-Log "Starting stop.bat..."
    if (-not (Test-Path $guiRunCmd)) { Add-Log "ERROR: gui-run.cmd missing."; return }
    $cmdLine = ('"{0}" stop' -f $guiRunCmd)
    Start-CommandWithLog $cmdLine $false $log $lblFlow
})

$btnCleanup.Add_Click({
    $log = Join-Path $stateDir "gui-cleanup.log"
    Add-Log "Starting uninstall-local.bat..."
    if (-not (Test-Path $guiRunCmd)) { Add-Log "ERROR: gui-run.cmd missing."; return }
    $cmdLine = ('"{0}" cleanup' -f $guiRunCmd)
    Start-CommandWithLog $cmdLine $false $log $lblFlow
})

$btnOpen.Add_Click({
    if (-not $txtDomain.Text.Trim()) { return }
    Start-Process ("https://{0}/" -f $txtDomain.Text.Trim())
})

$btnRefresh.Add_Click({
    Refresh-Checks
    Add-Log "Checks refreshed."
})

$btnDoctor.Add_Click({
    Add-Log "Doctor check..."
    try { Add-Log ("docker --version: " + (cmd /c "docker --version" 2>&1)) } catch { Add-Log "docker --version: unavailable" }
    try {
        $null = cmd /c "docker info >nul 2>nul"
        if ($LASTEXITCODE -eq 0) { Add-Log "docker daemon: OK" } else { Add-Log "docker daemon: NOT READY" }
    } catch { Add-Log "docker daemon: check error" }
    try {
        $state = docker inspect -f "{{.State.Status}}" n8n 2>$null
        if ($state) { Add-Log ("container n8n: " + $state) } else { Add-Log "container n8n: not found" }
    } catch { Add-Log "container n8n: check error" }
})

Refresh-Checks
Add-Log "GUI ready."
Add-Log "Recommended flow: Save Config -> Install (Admin) -> Start."
[void]$form.ShowDialog()
