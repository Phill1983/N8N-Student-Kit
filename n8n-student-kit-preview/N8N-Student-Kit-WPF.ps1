Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

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
"@ -ErrorAction SilentlyContinue
    [DpiAware]::Enable()
} catch {}

# --- paths: this GUI lives in n8n-student-kit-preview, but all .bat/state/tools are in n8n-student-kit next to it
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Resolve-Path (Join-Path $scriptDir "..\n8n-student-kit")
$stateDir   = Join-Path $projectDir "state"
$toolsDir   = Join-Path $projectDir "tools"
$configPath = Join-Path $stateDir "install.cfg"
$guiRunCmd  = Join-Path $projectDir "gui-run.cmd"

if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir | Out-Null }

$xamlPath = Join-Path $scriptDir "MainWindow.xaml"
$xaml     = [IO.File]::ReadAllText($xamlPath, [Text.Encoding]::UTF8)
$xaml     = $xaml -replace 'x:Class="[^"]*"', ''

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# --- AppUserModelID so Windows treats this as its own taskbar app, not grouped with powershell.exe
try {
    Add-Type -Namespace Shell32 -Name Amid -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("shell32.dll", SetLastError=false)]
public static extern int SetCurrentProcessExplicitAppUserModelID([System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)] string AppID);
'@ -ErrorAction SilentlyContinue
    [void][Shell32.Amid]::SetCurrentProcessExplicitAppUserModelID("GoIT.N8N.StudentKit")
} catch {}

# --- programmatic taskbar/window icon (lightning bolt + gradient, no external files)
function New-AppIcon {
    param([int]$size = 128)
    $dv = New-Object System.Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()

    # background: rounded rect, same gradient as header
    $bg = New-Object System.Windows.Media.LinearGradientBrush
    $bg.StartPoint = New-Object System.Windows.Point(0, 0)
    $bg.EndPoint   = New-Object System.Windows.Point(1, 1)
    $c1 = [System.Windows.Media.ColorConverter]::ConvertFromString('#1B2236')
    $c2 = [System.Windows.Media.ColorConverter]::ConvertFromString('#25204A')
    $c3 = [System.Windows.Media.ColorConverter]::ConvertFromString('#3A1F56')
    $bg.GradientStops.Add((New-Object System.Windows.Media.GradientStop($c1, 0)))
    $bg.GradientStops.Add((New-Object System.Windows.Media.GradientStop($c2, 0.55)))
    $bg.GradientStops.Add((New-Object System.Windows.Media.GradientStop($c3, 1)))
    $rect = New-Object System.Windows.Rect(0, 0, $size, $size)
    $radius = [double]($size * 0.22)
    $dc.DrawRoundedRectangle($bg, $null, $rect, $radius, $radius)

    # soft glow behind the bolt
    $glowColor = [System.Windows.Media.ColorConverter]::ConvertFromString('#7C6CFF')
    $glowColor.A = 80
    $glow = New-Object System.Windows.Media.RadialGradientBrush
    $glow.GradientStops.Add((New-Object System.Windows.Media.GradientStop($glowColor, 0)))
    $glow.GradientStops.Add((New-Object System.Windows.Media.GradientStop(([System.Windows.Media.Color]::FromArgb(0, 124, 108, 255)), 1)))
    $glow.Center       = New-Object System.Windows.Point(0.5, 0.5)
    $glow.GradientOrigin = New-Object System.Windows.Point(0.5, 0.5)
    $glow.RadiusX = 0.55; $glow.RadiusY = 0.55
    $dc.DrawEllipse($glow, $null, (New-Object System.Windows.Point(($size/2), ($size/2))), ($size*0.55), ($size*0.55))

    # lightning bolt path (coords in 128-space; scale via PushTransform if $size differs)
    $k = [double]$size / 128.0
    $geomStr = "M 74,18 L 36,74 L 60,74 L 48,110 L 94,56 L 70,56 L 82,18 Z"
    $geom = [System.Windows.Media.Geometry]::Parse($geomStr)

    $boltBrush = New-Object System.Windows.Media.LinearGradientBrush
    $boltBrush.StartPoint = New-Object System.Windows.Point(0, 0)
    $boltBrush.EndPoint   = New-Object System.Windows.Point(0, 1)
    $b1 = [System.Windows.Media.ColorConverter]::ConvertFromString('#C7B9FF')
    $b2 = [System.Windows.Media.ColorConverter]::ConvertFromString('#7C6CFF')
    $boltBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop($b1, 0)))
    $boltBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop($b2, 1)))

    $edgePen = New-Object System.Windows.Media.Pen(([System.Windows.Media.Brushes]::White), ([double]($size * 0.02)))
    $edgePen.LineJoin = [System.Windows.Media.PenLineJoin]::Round

    # bolt goes first (behind), the "8" will be drawn on top
    $dc.PushTransform((New-Object System.Windows.Media.ScaleTransform($k, $k)))
    $dc.DrawGeometry($boltBrush, $edgePen, $geom)
    $dc.Pop()

    # "8" on top of the bolt, shifted slightly down and right
    try {
        $tf = New-Object System.Windows.Media.Typeface(
            (New-Object System.Windows.Media.FontFamily('Segoe UI')),
            [System.Windows.FontStyles]::Normal,
            [System.Windows.FontWeights]::Black,
            [System.Windows.FontStretches]::Normal
        )
        $eightBrush = New-Object System.Windows.Media.SolidColorBrush(
            [System.Windows.Media.ColorConverter]::ConvertFromString('#F4F6FB')
        )
        $ft = New-Object System.Windows.Media.FormattedText(
            '8',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Windows.FlowDirection]::LeftToRight,
            $tf,
            ([double]($size * 0.78)),
            $eightBrush,
            96.0
        )
        # Offset slightly down-right of center
        $tx = (($size - $ft.Width) / 2.0) + ($size * 0.11)
        $ty = (($size - $ft.Height) / 2.0) + ($size * 0.05)
        $dc.DrawText($ft, (New-Object System.Windows.Point($tx, $ty)))
    } catch {}

    $dc.Close()

    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($size, $size, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv)
    $rtb.Freeze()
    return $rtb
}

$window.Icon = New-AppIcon 128

# --- find named elements
function Find($name) { $window.FindName($name) }

$txtDrive   = Find "txtDrive"
$txtDomain  = Find "txtDomain"
$txtToken   = Find "txtToken"
$txtUser    = Find "txtUser"
$txtPass    = Find "txtPass"

$btnSave           = Find "btnSave"
$btnInstall        = Find "btnInstall"
$btnStart          = Find "btnStart"
$btnStartNB        = Find "btnStartNB"
$btnStop           = Find "btnStop"
$btnCleanup        = Find "btnCleanup"
$btnOpenUrl        = Find "btnOpenUrl"
$btnRefresh        = Find "btnRefresh"
$btnDoctor         = Find "btnDoctor"
$btnOpenInstallLog = Find "btnOpenInstallLog"
$btnCmd            = Find "btnCmd"

$pillDockerDot  = Find "pillDockerDot"
$pillDockerText = Find "pillDockerText"
$pillNgrokDot   = Find "pillNgrokDot"
$pillNgrokText  = Find "pillNgrokText"
$pillImageDot   = Find "pillImageDot"
$pillImageText  = Find "pillImageText"

$dotStackState = Find "dotStackState"
$lblStackState = Find "lblStackState"
$liveDot       = Find "liveDot"
$lblLiveState  = Find "lblLiveState"
$lblFlow       = Find "lblFlow"
$progressBar   = Find "progressBar"
$txtLog        = Find "txtLog"

$step1Dot  = Find "step1Dot"
$step1Icon = Find "step1Icon"
$step1Sub  = Find "step1Sub"
$step2Dot  = Find "step2Dot"
$step2Icon = Find "step2Icon"
$step2Sub  = Find "step2Sub"
$step3Dot  = Find "step3Dot"
$step3Icon = Find "step3Icon"
$step3Sub  = Find "step3Sub"
$step4Dot  = Find "step4Dot"
$step4Icon = Find "step4Icon"
$step4Sub  = Find "step4Sub"

# --- brushes (resolved from XAML resources)
$brOk   = $window.FindResource("OkBrush")
$brBad  = $window.FindResource("BadBrush")
$brWarn = $window.FindResource("WarnBrush")
$brAcc  = $window.FindResource("AccentBrush")
$brSec  = $window.FindResource("TextSecBrush")
$brPri  = $window.FindResource("TextPriBrush")
$brBorder = $window.FindResource("BorderBrush")

# --- config I/O (identical to WinForms version)
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

# --- logging to the txtLog panel
function Add-Log($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    $txtLog.AppendText("[$ts] $msg`r`n")
    $txtLog.ScrollToEnd()
}

# --- pill styling
function Set-Pill($dotEl, $textEl, $ok, $text) {
    $textEl.Text = $text
    if ($null -eq $ok) {
        $dotEl.Fill = $brSec
    } elseif ($ok) {
        $dotEl.Fill = $brOk
    } else {
        $dotEl.Fill = $brBad
    }
}

# --- stage stepper state
$brStepPending = $window.FindResource("StepPendingBrush")

function Set-Step($dot, $icon, $sub, $num, $state, $subText) {
    # state: pending | active | done
    switch ($state) {
        'done' {
            $dot.Background  = $brOk
            $dot.BorderBrush = $brOk
            $icon.Text       = [char]0x2713  # unicode check mark - works in any font
            $icon.Foreground = [System.Windows.Media.Brushes]::White
            $dot.Effect      = $null
        }
        'active' {
            $dot.Background  = $brAcc
            $dot.BorderBrush = $brAcc
            $icon.Text       = "$num"
            $icon.Foreground = [System.Windows.Media.Brushes]::White
            $dot.Effect = (New-Object System.Windows.Media.Effects.DropShadowEffect -Property @{
                BlurRadius = 12; ShadowDepth = 0; Opacity = 0.9
                Color = [System.Windows.Media.ColorConverter]::ConvertFromString("#7C6CFF")
            })
        }
        default {
            $dot.Background  = $brStepPending
            $dot.BorderBrush = $brBorder
            $icon.Text       = "$num"
            $icon.Foreground = $brSec
            $dot.Effect      = $null
        }
    }
    if ($subText) { $sub.Text = $subText }
}

function Set-HeaderState($state, $color) {
    $lblStackState.Text = $state
    $dotStackState.Fill = $color
}

function Set-LiveState($txt, $color) {
    $lblLiveState.Text = $txt
    $liveDot.Fill = $color
}

# --- runtime status checks (live state, not artifact presence)
function Test-DockerDaemon {
    # Fast: presence of the named pipe implies docker daemon is accepting connections
    try { return ([System.IO.Directory]::GetFiles('\\.\pipe\', 'docker_engine')).Length -gt 0 }
    catch { return $false }
}

function Test-NgrokRunning {
    return $null -ne (Get-Process -Name 'ngrok' -ErrorAction SilentlyContinue)
}

function Test-TcpPort($hostname, $port, $timeoutMs = 250) {
    $cli = $null
    try {
        $cli = New-Object System.Net.Sockets.TcpClient
        $async = $cli.BeginConnect($hostname, $port, $null, $null)
        $ok = $async.AsyncWaitHandle.WaitOne($timeoutMs, $false)
        if ($ok -and $cli.Connected) { $cli.EndConnect($async); return $true }
        return $false
    } catch { return $false }
    finally { if ($cli) { $cli.Close() } }
}

function Refresh-Checks {
    $dockerOk = Test-DockerDaemon
    $ngrokOk  = Test-NgrokRunning
    $n8nOk    = Test-TcpPort '127.0.0.1' 5678

    Set-Pill $pillDockerDot $pillDockerText $dockerOk ($(if ($dockerOk) { "daemon running" } else { "not running" }))
    Set-Pill $pillNgrokDot  $pillNgrokText  $ngrokOk  ($(if ($ngrokOk)  { "tunnel active" }  else { "offline" }))
    Set-Pill $pillImageDot  $pillImageText  $n8nOk    ($(if ($n8nOk)    { "listening :5678" } else { "not running" }))
}

# periodic auto-refresh so pills track live state without manual clicks
$script:statusTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:statusTimer.Interval = [TimeSpan]::FromSeconds(2)
$script:statusTimer.Add_Tick({ try { Refresh-Checks } catch {} })
$script:statusTimer.Start()

# --- process launching (identical pattern, adapted to WPF)
$script:tailPath           = $null
$script:tailLineCount      = 0
$script:lastFileLineCount  = -1
$script:stableLogTicks     = 0
$script:installNextNotified = $false
$script:wingetStart         = $null
$script:autoContinueTimer   = $null
$script:autoContinueSeconds = 0

function Show-Progress {
    $progressBar.Visibility = [System.Windows.Visibility]::Visible
    $progressBar.Width = 80
    if (-not $script:progressAnim) {
        $da = New-Object System.Windows.Media.Animation.DoubleAnimation
        $da.From = 40
        $da.To = 620
        $da.Duration = [System.Windows.Duration]::new([TimeSpan]::FromSeconds(1.6))
        $da.AutoReverse = $true
        $da.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
        $script:progressAnim = $da
    }
    $progressBar.BeginAnimation([System.Windows.Controls.Border]::WidthProperty, $script:progressAnim)
    Set-LiveState "live" ([System.Windows.Media.ColorConverter]::ConvertFromString("#A78BFA") | ForEach-Object { New-Object System.Windows.Media.SolidColorBrush $_ })
}

function Hide-Progress {
    $progressBar.BeginAnimation([System.Windows.Controls.Border]::WidthProperty, $null)
    $progressBar.Visibility = [System.Windows.Visibility]::Collapsed
    Set-LiveState "idle" ([System.Windows.Media.ColorConverter]::ConvertFromString("#3A3E4E") | ForEach-Object { New-Object System.Windows.Media.SolidColorBrush $_ })
}

function Start-CommandWithLog($cmdLine, $asAdmin, $logPath) {
    try { if (Test-Path $logPath) { Remove-Item $logPath -Force } } catch {}

    $script:tailPath          = $logPath
    $script:tailLineCount     = 0
    $script:lastFileLineCount = -1
    $script:stableLogTicks    = 0

    Show-Progress
    $timer.Start()

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName         = "cmd.exe"
    $psi.Arguments        = "/c " + $cmdLine
    $psi.WorkingDirectory = $projectDir
    $psi.WindowStyle      = [System.Diagnostics.ProcessWindowStyle]::Hidden

    if ($asAdmin) {
        $psi.UseShellExecute = $true
        $psi.Verb            = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            $lblFlow.Text = "Elevated task running - tailing log below."
        } catch [System.ComponentModel.Win32Exception] {
            $lblFlow.Text = "UAC declined."
            Add-Log "UAC declined - cancelled."
            $timer.Stop()
            Hide-Progress
        }
    } else {
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow  = $true
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        $lblFlow.Text = "Task running - tailing log below."
    }
}

# --- timer that tails the log file (identical logic)
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    if (-not $script:tailPath) {
        Hide-Progress
        return
    }
    if (-not (Test-Path $script:tailPath)) {
        $lblFlow.Text = "Waiting for log file (confirm UAC if prompted)..."
        return
    }
    $all = @(Get-Content -LiteralPath $script:tailPath -Encoding utf8 -ErrorAction SilentlyContinue)
    if ($all.Count -eq 0) {
        $lblFlow.Text = "Log file starting..."
        return
    }
    if ($all.Count -eq $script:lastFileLineCount) {
        $script:stableLogTicks++
        if ($script:stableLogTicks -ge 4 -and -not $script:wingetStart) {
            Hide-Progress
        } elseif ($script:wingetStart) {
            Show-Progress
        }
    } else {
        $script:lastFileLineCount = $all.Count
        $script:stableLogTicks = 0
        Show-Progress
    }

    $lastLine = $all[$all.Count - 1]
    if ($lastLine -and $lastLine.Length -gt 120) { $lastLine = $lastLine.Substring(0, 117) + "..." }

    $hasNext = $false
    $hasWingetStart = $false
    $hasWingetDone  = $false
    foreach ($ln in $all) {
        if ($ln -match '\[NEXT\]') { $hasNext = $true }
        if ($ln -match 'Installing Docker Desktop via winget') { $hasWingetStart = $true }
        if ($ln -match 'Docker Desktop installed via winget|ACTION REQUIRED\] Docker Desktop installed') { $hasWingetDone = $true }
    }

    if ($hasWingetStart -and -not $hasWingetDone) {
        if (-not $script:wingetStart) { $script:wingetStart = Get-Date }
    } elseif ($hasWingetDone -and $script:wingetStart) {
        $script:wingetStart = $null
    }

    if ($hasNext -and ($script:tailPath -match 'gui-install\.log$')) {
        Set-Step $step2Dot $step2Icon $step2Sub 2 'done' "docker installed"
        Set-Step $step3Dot $step3Icon $step3Sub 3 'active' "auto-continuing"
        if (-not $script:installNextNotified) {
            $script:installNextNotified = $true
            $script:autoContinueSeconds = 5
            $lblFlow.Text = "Docker installed. Auto-continuing install in 5s..."
            Add-Log "Docker Desktop installed. Auto-continuing install in 5 seconds (no reboot needed)."
            if (-not $script:autoContinueTimer) {
                $script:autoContinueTimer = New-Object System.Windows.Threading.DispatcherTimer
                $script:autoContinueTimer.Interval = [TimeSpan]::FromSeconds(1)
                $script:autoContinueTimer.Add_Tick({
                    $script:autoContinueSeconds--
                    if ($script:autoContinueSeconds -le 0) {
                        $script:autoContinueTimer.Stop()
                        Add-Log "Auto-continue: launching Install (Admin) second pass..."
                        try { Start-InstallAdmin } catch { Add-Log ("Auto-continue failed: " + $_.Exception.Message) }
                    } else {
                        $lblFlow.Text = ("Docker installed. Auto-continuing install in {0}s..." -f $script:autoContinueSeconds)
                    }
                })
            }
            $script:autoContinueTimer.Start()
        }
    } elseif ($script:wingetStart) {
        $elapsed = (Get-Date) - $script:wingetStart
        $lblFlow.Text = ("Installing Docker Desktop (silent, ~3-5 min) - elapsed {0:mm\:ss} | {1}" -f $elapsed, $lastLine)
    } else {
        $lblFlow.Text = ("Log: {0} lines | {1}" -f $all.Count, $lastLine)
    }

    if ($all.Count -gt $script:tailLineCount) {
        for ($i = $script:tailLineCount; $i -lt $all.Count; $i++) {
            if ($all[$i]) { $txtLog.AppendText("[log] " + $all[$i] + "`r`n") }
        }
        $script:tailLineCount = $all.Count
        $txtLog.ScrollToEnd()
    }
})

# --- initial load: populate fields from config
$cfg = Read-Config
$txtDrive.Text  = if ($cfg.ContainsKey("INSTALL_DRIVE"))        { $cfg["INSTALL_DRIVE"] }        else { "D" }
$txtDomain.Text = if ($cfg.ContainsKey("NGROK_DOMAIN"))         { $cfg["NGROK_DOMAIN"] }         else { "" }
if ($cfg.ContainsKey("NGROK_AUTHTOKEN"))       { $txtToken.Password = $cfg["NGROK_AUTHTOKEN"] }
$txtUser.Text   = if ($cfg.ContainsKey("N8N_BASIC_AUTH_USER"))  { $cfg["N8N_BASIC_AUTH_USER"] }  else { "" }
if ($cfg.ContainsKey("N8N_BASIC_AUTH_PASSWORD")) { $txtPass.Password = $cfg["N8N_BASIC_AUTH_PASSWORD"] }

# --- button handlers
$btnSave.Add_Click({
    if (-not $txtDomain.Text.Trim())   { [void][System.Windows.MessageBox]::Show("Enter NGROK_DOMAIN");   return }
    if (-not $txtToken.Password.Trim()) { [void][System.Windows.MessageBox]::Show("Enter NGROK_AUTHTOKEN"); return }
    if (-not $txtUser.Text.Trim())     { [void][System.Windows.MessageBox]::Show("Enter BASIC_AUTH_USER"); return }
    if (-not $txtPass.Password.Trim()) { [void][System.Windows.MessageBox]::Show("Enter BASIC_AUTH_PASSWORD"); return }
    Save-Config $txtDrive.Text $txtDomain.Text.Trim() $txtToken.Password.Trim() $txtUser.Text.Trim() $txtPass.Password.Trim()
    Add-Log "Config saved to state/install.cfg"
    Set-Step $step1Dot $step1Icon $step1Sub 1 'done' "fields saved"
    Set-Step $step2Dot $step2Icon $step2Sub 2 'active' "ready to install"
})

function Start-InstallAdmin {
    Save-Config $txtDrive.Text $txtDomain.Text.Trim() $txtToken.Password.Trim() $txtUser.Text.Trim() $txtPass.Password.Trim()
    $log = Join-Path $stateDir "gui-install.log"
    $script:installNextNotified = $false
    $script:wingetStart          = $null
    Add-Log "Starting install (admin)..."
    Add-Log "1) If UAC appears - click Yes."
    Add-Log "2) Live file: $log"
    Add-Log "3) Installer runs ONLY if docker is not in PATH yet."
    if (-not (Test-Path $guiRunCmd)) { Add-Log "ERROR: gui-run.cmd missing at $guiRunCmd"; return }
    Set-Step $step1Dot $step1Icon $step1Sub 1 'done' ""
    Set-Step $step2Dot $step2Icon $step2Sub 2 'active' "installing docker"
    Set-HeaderState "Installing" $brAcc
    $cmdLine = ('"{0}" install' -f $guiRunCmd)
    Start-CommandWithLog $cmdLine $true $log
}

$btnInstall.Add_Click({ Start-InstallAdmin })

$btnOpenInstallLog.Add_Click({
    $p = Join-Path $stateDir "gui-install.log"
    if (Test-Path $p) { Start-Process notepad.exe -ArgumentList $p }
    else { [void][System.Windows.MessageBox]::Show("No gui-install.log yet. Run Install (Admin) first.") }
})

$btnCmd.Add_Click({
    Start-Process -FilePath "cmd.exe" -WorkingDirectory $projectDir
    Add-Log "Opened CMD in $projectDir"
})

function Assert-InstallDone {
    $envPath = Join-Path $stateDir ".env"
    if (-not (Test-Path $envPath)) {
        Add-Log "Cannot Start: state\.env not found. Run Install (Admin) first."
        Set-Step $step2Dot $step2Icon $step2Sub 2 'active' "install required"
        $lblFlow.Text = "Install (Admin) required before Start."
        return $false
    }
    return $true
}

$btnStart.Add_Click({
    if (-not (Test-Path $guiRunCmd)) { Add-Log "ERROR: gui-run.cmd missing."; return }
    if (-not (Assert-InstallDone)) { return }
    $log = Join-Path $stateDir "gui-start.log"
    Add-Log "Starting start.bat..."
    Set-Step $step4Dot $step4Icon $step4Sub 4 'active' "launching n8n"
    Set-HeaderState "Running" $brOk
    $cmdLine = ('"{0}" start' -f $guiRunCmd)
    Start-CommandWithLog $cmdLine $false $log
})

$btnStartNB.Add_Click({
    if (-not (Test-Path $guiRunCmd)) { Add-Log "ERROR: gui-run.cmd missing."; return }
    if (-not (Assert-InstallDone)) { return }
    $log = Join-Path $stateDir "gui-start-no-browser.log"
    Add-Log "Starting start.bat --no-browser..."
    Set-Step $step4Dot $step4Icon $step4Sub 4 'active' "launching n8n"
    Set-HeaderState "Running" $brOk
    $cmdLine = ('"{0}" startnb' -f $guiRunCmd)
    Start-CommandWithLog $cmdLine $false $log
})

$btnStop.Add_Click({
    $log = Join-Path $stateDir "gui-stop.log"
    Add-Log "Starting stop.bat..."
    if (-not (Test-Path $guiRunCmd)) { Add-Log "ERROR: gui-run.cmd missing."; return }
    Set-HeaderState "Stopping" $brWarn
    $cmdLine = ('"{0}" stop' -f $guiRunCmd)
    Start-CommandWithLog $cmdLine $false $log
})

$btnCleanup.Add_Click({
    $log = Join-Path $stateDir "gui-cleanup.log"
    Add-Log "Starting uninstall-local.bat..."
    if (-not (Test-Path $guiRunCmd)) { Add-Log "ERROR: gui-run.cmd missing."; return }
    Set-HeaderState "Cleaning" $brWarn
    $cmdLine = ('"{0}" cleanup' -f $guiRunCmd)
    Start-CommandWithLog $cmdLine $false $log
})

$btnOpenUrl.Add_Click({
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

# --- smooth mouse-wheel scrolling for main ScrollViewer
$mainScroll = Find "mainScroll"
$script:scrollCurrent = 0.0
$script:scrollTarget  = 0.0
$script:scrollTimer   = New-Object System.Windows.Threading.DispatcherTimer
$script:scrollTimer.Interval = [TimeSpan]::FromMilliseconds(14)
$script:scrollTimer.Add_Tick({
    $diff = $script:scrollTarget - $script:scrollCurrent
    if ([math]::Abs($diff) -lt 0.6) {
        $script:scrollCurrent = $script:scrollTarget
        $mainScroll.ScrollToVerticalOffset($script:scrollCurrent)
        $script:scrollTimer.Stop()
        return
    }
    # ease-out: move 22% of remaining distance each tick
    $script:scrollCurrent += $diff * 0.22
    $mainScroll.ScrollToVerticalOffset($script:scrollCurrent)
})

$mainScroll.Add_PreviewMouseWheel({
    param($sender, $e)
    $e.Handled = $true
    if (-not $script:scrollTimer.IsEnabled) {
        $script:scrollCurrent = $sender.VerticalOffset
        $script:scrollTarget  = $sender.VerticalOffset
    }
    $step  = 90.0  # pixels per wheel notch
    $delta = -($e.Delta / 120.0) * $step
    $new = $script:scrollTarget + $delta
    if ($new -lt 0)                         { $new = 0 }
    if ($new -gt $sender.ScrollableHeight)  { $new = $sender.ScrollableHeight }
    $script:scrollTarget = $new
    if (-not $script:scrollTimer.IsEnabled) { $script:scrollTimer.Start() }
})

# --- collapsible Configuration card
$btnCfgToggle  = Find "btnCfgToggle"
$cfgToggleIcon = Find "cfgToggleIcon"
$cfgContent    = Find "cfgContent"
$script:cfgCollapsed = $false
$btnCfgToggle.Add_Click({
    if ($script:cfgCollapsed) {
        $cfgContent.Visibility = [System.Windows.Visibility]::Visible
        $cfgToggleIcon.Text = [char]0xE70E  # ChevronUp
        $script:cfgCollapsed = $false
    } else {
        $cfgContent.Visibility = [System.Windows.Visibility]::Collapsed
        $cfgToggleIcon.Text = [char]0xE70D  # ChevronDown
        $script:cfgCollapsed = $true
    }
})

# --- initial state
Refresh-Checks
$envPath = Join-Path $stateDir ".env"
$cfgPath = Join-Path $stateDir "install.cfg"
if (Test-Path $envPath) {
    Set-Step $step1Dot $step1Icon $step1Sub 1 'done' "saved"
    Set-Step $step2Dot $step2Icon $step2Sub 2 'done' "installed"
    Set-Step $step3Dot $step3Icon $step3Sub 3 'done' ".env ready"
    Set-Step $step4Dot $step4Icon $step4Sub 4 'active' "ready to Start"
} elseif (Test-Path $cfgPath) {
    Set-Step $step1Dot $step1Icon $step1Sub 1 'done' "saved"
    Set-Step $step2Dot $step2Icon $step2Sub 2 'active' "run Install (Admin)"
    Set-Step $step3Dot $step3Icon $step3Sub 3 'pending' "pending"
    Set-Step $step4Dot $step4Icon $step4Sub 4 'pending' "pending"
} else {
    Set-Step $step1Dot $step1Icon $step1Sub 1 'active' "fill or check fields"
    Set-Step $step2Dot $step2Icon $step2Sub 2 'pending' "pending"
    Set-Step $step3Dot $step3Icon $step3Sub 3 'pending' "pending"
    Set-Step $step4Dot $step4Icon $step4Sub 4 'pending' "pending"
}
Set-HeaderState "Idle" $brSec
Add-Log "GUI ready. Project: $projectDir"
Add-Log "Recommended: Save -> Install (Admin) -> Start."

[void]$window.ShowDialog()
