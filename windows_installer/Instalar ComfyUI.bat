@echo off
chcp 65001 >nul
title Instalador do ComfyUI
set "SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=[IO.File]::ReadAllText($env:SELF,[Text.Encoding]::UTF8); $i=$c.IndexOf('##'+'PS-BEGIN##'); $sb=[scriptblock]::Create($c.Substring($i+12)); & $sb %*"
if errorlevel 1 (
    echo.
    echo ==========================================
    echo  Ocorreu um erro na instalacao. Leia a mensagem acima.
    echo  Rodar este arquivo de novo costuma resolver ^(o download continua de onde parou^).
    echo ==========================================
)
echo.
pause
exit /b
##PS-BEGIN##
<#
  Instalador de um clique do ComfyUI (Windows portable oficial).
  Uso normal: dar dois cliques em "Instalar ComfyUI.bat".

  Parametros (opcionais, para uso avancado):
    -InstallDir    pasta de instalacao (padrao: C:\ComfyUI, ou o disco com mais espaco livre)
    -Gpu           auto | nvidia | amd | intel | cpu   (padrao: auto = detecta a placa de video)
    -LocalArchive  usa um .7z ja baixado em vez de baixar de novo
    -NoLaunch      nao abre o ComfyUI no final
    -SkipModel     nao baixa o modelo inicial (SD 1.5, ~2 GB)
    -DryRun        so mostra o que seria feito (detecta placa, escolhe pacote, checa disco)
#>
param(
    [string]$InstallDir,
    [ValidateSet('auto', 'nvidia', 'amd', 'intel', 'cpu')][string]$Gpu = 'auto',
    [string]$LocalArchive,
    [switch]$NoLaunch,
    [switch]$SkipModel,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$Repo = 'Comfy-Org/ComfyUI'
$FallbackTag = 'v0.45.0'   # usado se a API do GitHub estiver indisponivel
$FallbackSizes = @{
    'ComfyUI_windows_portable_nvidia.7z'      = 2071479423
    'ComfyUI_windows_portable_nvidia_cu126.7z' = 1962803660
    'ComfyUI_windows_portable_amd.7z'         = 1688825308
    'ComfyUI_windows_portable_intel.7z'       = 1503750967
}

function Say($msg, $color = 'White') { Write-Host $msg -ForegroundColor $color }
function Step($n, $msg) { Write-Host ""; Write-Host "[$n/7] $msg" -ForegroundColor Cyan }
function Fail($msg) { throw $msg }

# Baixa um arquivo grande com retomada e confere o tamanho final.
function Get-BigFile($url, $dest, [int64]$expected) {
    if ((Test-Path $dest) -and ((Get-Item $dest).Length -eq $expected)) { Say "  Ja baixado, reaproveitando."; return }
    Say "  Se a conexao cair, e so rodar o instalador de novo: ele continua de onde parou."
    for ($i = 1; $i -le 6; $i++) {
        if ($i -gt 1) { Say "  Tentativa $i de 6..." Yellow; Start-Sleep -Seconds 5 }
        $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
        try {
            if ($curl) {
                & $curl.Source -L --fail --retry 3 --retry-delay 3 -C - --connect-timeout 30 -o $dest $url
                if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 33) { throw "curl saiu com codigo $LASTEXITCODE" }
            } else {
                Import-Module BitsTransfer
                Start-BitsTransfer -Source $url -Destination $dest -DisplayName 'ComfyUI'
            }
        } catch { Say "  Falha no download: $($_.Exception.Message)" Yellow }
        if ((Test-Path $dest) -and ((Get-Item $dest).Length -eq $expected)) { return }
    }
    Fail "Nao consegui baixar o arquivo completo ($url). Verifique a internet/antivirus e rode o instalador de novo."
}

Clear-Host
Say "==========================================" Cyan
Say "   Instalador do ComfyUI - um clique" Cyan
Say "==========================================" Cyan
Say "Pode deixar esta janela aberta e fazer outra coisa."
Say "O download total e de ~4 GB e leva de 10 a 60 minutos, conforme sua internet."

# ---------------------------------------------------------------- 1. pre-requisitos da maquina
Step 1 "Conferindo os pre-requisitos do seu computador..."

# Windows 10/11 64 bits
if ($env:OS -ne 'Windows_NT' -or -not [Environment]::Is64BitOperatingSystem -or [Environment]::OSVersion.Version.Major -lt 10) {
    Fail "Este instalador precisa de Windows 10 ou 11 (64 bits)."
}
Say "  [ok] Windows 10/11 64 bits"

# Memoria RAM
try {
    $ramGB = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    if ($ramGB -lt 8) { Say ("  [!!] Memoria RAM: {0:N0} GB. O ComfyUI precisa de pelo menos 8 GB (ideal 16 GB); pode ficar lento ou travar." -f $ramGB) Yellow }
    else { Say ("  [ok] Memoria RAM: {0:N0} GB" -f $ramGB) }
} catch {}

# Internet / acesso aos sites de download
$sites = @('https://github.com', 'https://huggingface.co', 'https://www.7-zip.org')
$offline = @()
foreach ($s in $sites) {
    try { Invoke-WebRequest -Uri $s -Method Head -UseBasicParsing -TimeoutSec 20 | Out-Null }
    catch { if (-not $_.Exception.Response) { $offline += $s } }   # resposta HTTP (mesmo erro) = site alcancado
}
if ($offline.Count -gt 0) {
    Fail ("Sem acesso a: {0}. Verifique a internet, VPN, proxy ou antivirus/firewall e tente de novo." -f ($offline -join ', '))
}
Say "  [ok] Internet e sites de download acessiveis"

# Visual C++ Redistributable (o Python/PyTorch do ComfyUI precisa dele)
$vc = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' -ErrorAction SilentlyContinue).Installed
if ($vc -eq 1) { Say "  [ok] Visual C++ Redistributable" }
elseif ($DryRun) { Say "  [..] Visual C++ Redistributable: faltando (seria instalado agora)" Yellow }
else {
    Say "  [..] Visual C++ Redistributable: faltando. Baixando e instalando (o Windows vai pedir permissao de administrador - clique em Sim)..." Yellow
    try {
        $vcExe = Join-Path $env:TEMP 'vc_redist.x64.exe'
        Invoke-WebRequest -Uri 'https://aka.ms/vc14/vc_redist.x64.exe' -OutFile $vcExe -UseBasicParsing
        $p = Start-Process -FilePath $vcExe -ArgumentList '/install', '/quiet', '/norestart' -Verb RunAs -Wait -PassThru
        if ($p.ExitCode -in 0, 1638, 3010) { Say "  [ok] Visual C++ instalado" Green }
        else { Say "  [!!] Instalador do Visual C++ retornou codigo $($p.ExitCode); se o ComfyUI nao abrir, instale: https://aka.ms/vc14/vc_redist.x64.exe" Yellow }
    } catch { Say "  [!!] Nao foi possivel instalar o Visual C++ ($($_.Exception.Message)). Se o ComfyUI nao abrir, instale: https://aka.ms/vc14/vc_redist.x64.exe" Yellow }
}

# ---------------------------------------------------------------- 2. placa de video
Step 2 "Detectando sua placa de video..."
$gpuNames = @()
try { $gpuNames = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name }) } catch {}
Say ("  Encontrado: " + ($(if ($gpuNames) { $gpuNames -join ', ' } else { 'nenhuma placa identificada' })))

$mode = $Gpu
if ($mode -eq 'auto') {
    $all = $gpuNames -join ' | '
    if     ($all -match 'NVIDIA')                          { $mode = 'nvidia' }
    elseif ($all -match 'Radeon RX [79]\d{3}|Radeon (PRO|AI PRO)') { $mode = 'amd' }
    elseif ($all -match 'Intel.*Arc')                       { $mode = 'intel' }
    else                                                   { $mode = 'cpu' }
}

$assetName = $null
switch ($mode) {
    'nvidia' {
        # driver >= 580 usa o pacote CUDA 13; drivers mais antigos usam o CUDA 12.6
        $drv = 0
        $smi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
        if (-not $smi -and (Test-Path "$env:SystemRoot\System32\nvidia-smi.exe")) { $smi = "$env:SystemRoot\System32\nvidia-smi.exe" }
        if ($smi) {
            try {
                $v = (& $(if ($smi -is [string]) { $smi } else { $smi.Source }) --query-gpu=driver_version --format=csv,noheader | Select-Object -First 1).Trim()
                $drv = [int]($v.Split('.')[0])
                Say "  Driver NVIDIA: $v"
            } catch {}
        }
        $assetName = if ($drv -ge 580) { 'ComfyUI_windows_portable_nvidia.7z' } else { 'ComfyUI_windows_portable_nvidia_cu126.7z' }
        if ($drv -gt 0 -and $drv -lt 528) { Say "  [!!] Driver NVIDIA muito antigo ($drv). Atualize em https://www.nvidia.com/Download/index.aspx senao o ComfyUI nao usara a placa." Yellow }
        if ($drv -lt 580) { Say "  (driver antigo ou nao identificado: usando o pacote compativel CUDA 12.6)" Yellow }
    }
    'amd'    { $assetName = 'ComfyUI_windows_portable_amd.7z' }
    'intel'  { $assetName = 'ComfyUI_windows_portable_intel.7z' }
    'cpu' {
        $assetName = 'ComfyUI_windows_portable_nvidia_cu126.7z'
        Say "  Nenhuma placa compativel encontrada: vai rodar no processador (CPU)." Yellow
        Say "  Funciona, mas e MUITO mais lento que com placa NVIDIA." Yellow
    }
}
Say "  Modo escolhido: $mode"

# ---------------------------------------------------------------- versao e tamanho
$tag = $FallbackTag
$size = $FallbackSizes[$assetName]
$url = $null
try {
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent' = 'ComfyUI-OneClick-Installer' } -TimeoutSec 20
    $a = $rel.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
    if ($a) { $tag = $rel.tag_name; $size = [int64]$a.size; $url = $a.browser_download_url }
} catch { Say "  (nao consegui consultar a ultima versao; usando $tag)" DarkGray }
if (-not $url) { $url = "https://github.com/$Repo/releases/download/$tag/$assetName" }
Say ("  Versao do ComfyUI: {0}  ({1:N1} GB)" -f $tag, ($size / 1GB))

# ---------------------------------------------------------------- pasta de instalacao
$needBytes = [int64]($size + 9GB + $(if ($SkipModel) { 0 } else { 3GB }))   # arquivo + extraido + modelo (o .7z e apagado no fim)
if (-not $InstallDir) {
    $disks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Sort-Object FreeSpace -Descending)
    $pick = $disks | Where-Object { $_.DeviceID -eq 'C:' -and $_.FreeSpace -ge $needBytes } | Select-Object -First 1
    if (-not $pick) { $pick = $disks | Where-Object { $_.FreeSpace -ge $needBytes } | Select-Object -First 1 }
    if (-not $pick) {
        Fail ("Espaco em disco insuficiente. Libere pelo menos {0:N0} GB em algum disco e tente de novo." -f ($needBytes / 1GB))
    }
    $InstallDir = Join-Path ($pick.DeviceID + '\') 'ComfyUI'
}
$InstallDir = [IO.Path]::GetFullPath($InstallDir)
if ($InstallDir -match '[^\x00-\x7F]') {
    Say "  Aviso: a pasta tem acentos/caracteres especiais; pode dar problema. Prefira algo como C:\ComfyUI." Yellow
}
$root = Join-Path $InstallDir 'ComfyUI_windows_portable'
Say "  Instalar em: $InstallDir"

if ($DryRun) {
    Say ""; Say "DryRun: pacote=$assetName`n        url=$url`n        destino=$InstallDir" Green
    return
}

# ---------------------------------------------------------------- ja instalado?
$alreadyInstalled = Test-Path (Join-Path $root 'ComfyUI\main.py')

if (-not $alreadyInstalled) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $drive = (Get-Item $InstallDir).PSDrive
    if ($drive.Free -lt $needBytes) {
        Fail ("Pouco espaco livre em {0}: precisa de ~{1:N0} GB." -f $drive.Root, ($needBytes / 1GB))
    }

    # ------------------------------------------------------------ 2. download
    Step 3 "Baixando o ComfyUI..."
    if ($LocalArchive) {
        if (-not (Test-Path $LocalArchive)) { Fail "Arquivo nao encontrado: $LocalArchive" }
        $archive = (Resolve-Path $LocalArchive).Path
        Say "  Usando arquivo local: $archive"
    } else {
        $archive = Join-Path $InstallDir $assetName
        Get-BigFile $url $archive $size
    }

    # ------------------------------------------------------------ 3. extrator
    Step 4 "Preparando o extrator (7-Zip)..."
    $sevenZip = $null
    foreach ($p in @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe")) {
        if (Test-Path $p) { $sevenZip = $p; break }
    }
    if (-not $sevenZip) {
        $tools = Join-Path $InstallDir '_tools'
        New-Item -ItemType Directory -Force -Path $tools | Out-Null
        $sevenZip = Join-Path $tools '7zr.exe'
        # versao fixa do GitHub oficial do 7-Zip, com SHA256 conferido (o 7zr.exe nao tem assinatura digital)
        $sevenZipUrl  = 'https://github.com/ip7z/7zip/releases/download/26.06/7zr.exe'
        $sevenZipHash = 'E80DB2DAD715A6C5ADABE292D31ED54E11F4E9B99CA349827B50573B175891BC'
        if (-not (Test-Path $sevenZip)) {
            Invoke-WebRequest -Uri $sevenZipUrl -OutFile $sevenZip -UseBasicParsing
        }
        if ((Get-FileHash $sevenZip -Algorithm SHA256).Hash -ne $sevenZipHash) {
            Remove-Item $sevenZip -Force
            Fail "O extrator baixado nao confere com o checksum esperado. Por seguranca, instalacao cancelada."
        }
        Say "  7zr.exe baixado e checksum verificado."
    } else { Say "  Usando 7-Zip ja instalado." }

    # ------------------------------------------------------------ 4. extrair
    Step 5 "Extraindo os arquivos (pode demorar alguns minutos)..."
    if (Test-Path $root) { Remove-Item $root -Recurse -Force }   # sobra de extracao interrompida
    & $sevenZip x $archive "-o$InstallDir" -y -bsp1 -bso0
    if ($LASTEXITCODE -ne 0) { Fail "Falha ao extrair o arquivo (codigo $LASTEXITCODE). Disco cheio ou download corrompido? Apague '$archive' e rode de novo." }
    if (-not (Test-Path (Join-Path $root 'ComfyUI\main.py'))) { Fail "A extracao terminou, mas a pasta do ComfyUI nao foi encontrada." }

    # limpeza
    if (-not $LocalArchive) { Remove-Item $archive -Force -ErrorAction SilentlyContinue }
    Remove-Item (Join-Path $InstallDir '_tools') -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Step 3 "ComfyUI ja esta instalado em $root"
    Say "  Pulando download e extracao; so vou recriar os atalhos."
}

# ---------------------------------------------------------------- 6. modelo inicial
Step 6 "Modelo inicial de imagens (Stable Diffusion 1.5)..."
$ckptDir = Join-Path $root 'ComfyUI\models\checkpoints'
$ckpt = Join-Path $ckptDir 'v1-5-pruned-emaonly-fp16.safetensors'
if ($SkipModel) { Say "  Pulado (-SkipModel)." }
elseif (Test-Path $ckpt) { Say "  Ja existe." }
else {
    Say "  ~2 GB. E o modelo do exemplo padrao do ComfyUI, para voce gerar a primeira imagem logo."
    New-Item -ItemType Directory -Force -Path $ckptDir | Out-Null
    try {
        Get-BigFile 'https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive/resolve/main/v1-5-pruned-emaonly-fp16.safetensors' "$ckpt.part" 2132696762
        Move-Item "$ckpt.part" $ckpt -Force
    } catch { Say "  Nao consegui baixar o modelo ($($_.Exception.Message)). O ComfyUI funciona, mas voce precisara colocar um checkpoint em $ckptDir." Yellow }
}

# ---------------------------------------------------------------- 7. atalhos
Step 7 "Criando atalhos na Area de Trabalho..."
$bat = $null
if ($mode -eq 'cpu') { $bat = Join-Path $root 'advanced\run_cpu.bat' }
else {
    $bat = Get-ChildItem $root -Filter 'run_*gpu*.bat' -File | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $bat -or -not (Test-Path $bat)) { Fail "Nao achei o arquivo de inicializacao dentro de $root." }

$desktop = [Environment]::GetFolderPath('Desktop')
$shell = New-Object -ComObject WScript.Shell
foreach ($dir in @($desktop, (Join-Path ([Environment]::GetFolderPath('Programs')) ''))) {
    try {
        $lnk = $shell.CreateShortcut((Join-Path $dir 'ComfyUI.lnk'))
        $lnk.TargetPath = $bat
        $lnk.WorkingDirectory = Split-Path $bat
        $lnk.IconLocation = "$env:SystemRoot\System32\shell32.dll,13"
        $lnk.Description = 'Abrir o ComfyUI'
        $lnk.Save()
    } catch { Say "  (nao consegui criar um atalho em $dir)" DarkGray }
}
$lnk2 = $shell.CreateShortcut((Join-Path $desktop 'ComfyUI - pasta de modelos.lnk'))
$lnk2.TargetPath = Join-Path $root 'ComfyUI\models'
$lnk2.Save()

Say ""
Say "==========================================" Green
Say "   Instalacao concluida!" Green
Say "==========================================" Green
Say "  Para abrir: use o atalho 'ComfyUI' na Area de Trabalho."
Say "  Ele abre uma janela preta (deixe aberta) e o navegador em http://127.0.0.1:8188"
Say "  A primeira abertura demora um pouco."
Say "  Modelos (checkpoints) vao em: $root\ComfyUI\models  (atalho na Area de Trabalho)"
Say "  Se o Windows perguntar sobre o Firewall, pode clicar em Cancelar: so voce acessa."

if (-not $NoLaunch) {
    Say ""; Say "Abrindo o ComfyUI agora..." Cyan
    Start-Process -FilePath $bat -WorkingDirectory (Split-Path $bat)
}
