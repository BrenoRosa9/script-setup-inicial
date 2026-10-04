# ============================================================
#  Setup do PC pós-formatação (winget)
#  Uso: abra o PowerShell como Administrador e rode:
#     Set-ExecutionPolicy Bypass -Scope Process -Force; .\install.ps1
#  Simular sem instalar nada:
#     .\install.ps1 -DryRun
#  É idempotente: o que já estiver instalado é pulado.
# ============================================================
param([switch]$DryRun)

# Para desativar um app, basta comentar a linha com #
# Formato: 'ID'  ou  'ID|origem'  (origem padrão: winget)
$apps = @(
    # --- Dev ---
    'Git.Git'
    'Microsoft.VisualStudioCode'
    'Anysphere.Cursor'
    'Anthropic.ClaudeCode'
    'Microsoft.DotNet.SDK.10'
    'Microsoft.DotNet.DesktopRuntime.10'
    'OpenJS.NodeJS'                       # versão "Current"; troque por OpenJS.NodeJS.LTS se preferir a LTS
    'Python.Python.3.14'
    'EclipseAdoptium.Temurin.26.JDK'
    'Oracle.JDK.26'
    'PremiumSoft.NavicatPremium'

    # --- Utilitários ---
    'Notepad++.Notepad++'
    'Bopsoft.Listary'
    'WinDirStat.WinDirStat'
    '7zip.7zip'
    'Skillbrains.Lightshot'
    'CPUID.CPU-Z'

    # --- Comunicação / mídia ---
    'Spotify.Spotify'
    'Discord.Discord'

    # --- Jogos ---
    'Valve.Steam'
    'EpicGames.EpicGamesLauncher'
    'ElectronicArts.EADesktop'
    'RockstarGames.Launcher'
    'Ubisoft.Connect'
    'Oracle.JavaRuntimeEnvironment'       # Java 8 (java.com), usado pelo Minecraft

    # --- Hardware ---
    'MCHOSE.MCHOSEHUB'                    # mouse V9 Pro
    'XP8CLZL93F5Z4P|msstore'              # NVIDIA App (driver de vídeo)
)

# Sem pacote no winget, mas com instalador no GitHub Releases (sempre baixa a última versão)
# Nome = nome que aparece em "Aplicativos instalados" (usado pra pular se já existir)
$github = @(
    @{ Name = 'Go Live'; Repo = 'Nem-Tudo/group-sharescreen'; Asset = '^Go-Live-Setup-.*\.exe$'; Args = '/S' }
)

# Sem pacote nenhum: abre a página oficial pra baixar na mão
$manual = [ordered]@{
    # 'Nome' = 'https://site-oficial/download'
}

$ok = @(); $skip = @(); $fail = @()
$timer = [Diagnostics.Stopwatch]::StartNew()
$i = 0
foreach ($entry in $apps) {
    $id, $source = $entry -split '\|'
    if (-not $source) { $source = 'winget' }
    $i++
    Write-Host "[$i/$($apps.Count)] $id" -ForegroundColor Cyan
    $Host.UI.RawUI.WindowTitle = "Instalando $i/$($apps.Count): $id"

    winget list --id $id -e --accept-source-agreements --disable-interactivity *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host '   ja instalado, pulando' -ForegroundColor DarkGray
        $skip += $id; continue
    }
    if ($DryRun) {
        Write-Host '   (dry-run) seria instalado' -ForegroundColor Yellow
        $ok += $id; continue
    }

    winget install --id $id -e --source $source --silent `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -eq 0) { $ok += $id } else { $fail += "$id (codigo $LASTEXITCODE)" }
}

$uninstallKeys = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
foreach ($app in $github) {
    Write-Host "[GitHub] $($app.Name)" -ForegroundColor Cyan

    $installed = Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "$($app.Name)*" }
    if ($installed) {
        Write-Host '   ja instalado, pulando' -ForegroundColor DarkGray
        $skip += $app.Name; continue
    }
    try {
        $release = Invoke-RestMethod "https://api.github.com/repos/$($app.Repo)/releases/latest"
        $asset = $release.assets | Where-Object { $_.name -match $app.Asset } | Select-Object -First 1
        if (-not $asset) { throw "nenhum arquivo bate com '$($app.Asset)' na release $($release.tag_name)" }
        if ($DryRun) {
            Write-Host "   (dry-run) seria instalado: $($asset.name)" -ForegroundColor Yellow
            $ok += $app.Name; continue
        }
        $file = Join-Path $env:TEMP $asset.name
        Invoke-WebRequest $asset.browser_download_url -OutFile $file -UseBasicParsing
        $p = Start-Process $file -ArgumentList $app.Args -Wait -PassThru
        Remove-Item $file -ErrorAction SilentlyContinue
        if ($p.ExitCode -eq 0) { $ok += $app.Name } else { $fail += "$($app.Name) (codigo $($p.ExitCode))" }
    } catch {
        $fail += "$($app.Name) ($_)"
    }
}

$tempo = '{0:hh\:mm\:ss}' -f $timer.Elapsed
$Host.UI.RawUI.WindowTitle = 'Instalacao concluida'

Write-Host "`n===== Resumo =====" -ForegroundColor Green
Write-Host "Instalados: $($ok.Count)   Pulados: $($skip.Count)   Falhas: $($fail.Count)   Tempo: $tempo"
if ($fail) {
    Write-Host 'Falharam:' -ForegroundColor Red
    $fail | ForEach-Object { Write-Host "  - $_" }
}

if ($manual.Count) {
    Write-Host "`nInstalar manualmente:" -ForegroundColor Yellow
    foreach ($name in $manual.Keys) {
        Write-Host "  - $name -> $($manual[$name])"
        if (-not $DryRun) { Start-Process $manual[$name] }
    }
}

# Aviso de fim: bipe + janela pop-up por cima de tudo
$msg = "Instalados: $($ok.Count)`nPulados: $($skip.Count)`nFalhas: $($fail.Count)`nTempo: $tempo"
if ($fail) { $msg += "`n`nFalharam:`n" + ($fail -join "`n") }
if ($manual.Count) { $msg += "`n`nInstalar manualmente: " + ($manual.Keys -join ', ') }
$icone = if ($fail) { 48 } else { 64 }   # 48 = alerta, 64 = informacao
1..3 | ForEach-Object { [Console]::Beep(880, 200) }
$null = (New-Object -ComObject WScript.Shell).Popup($msg, 0, 'Script de formatacao terminou', $icone + 0x40000)
