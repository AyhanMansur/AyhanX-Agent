# ============================================================================
#   AyhanX-Agent · Windows PowerShell client for all LLMs
#   Repository:  https://github.com/AyhanMansur/AyhanX-Agent
#   Version:     5.0.0
#   24 providers: deepseek · openrouter · groq · google · mistral · together
#                 fireworks · deepinfra · perplexity · xai · cerebras · abacus
#                 novita · siliconcloud · bytedance · aliyun · minimax · edenai
#                 nvidia · ollama-cloud · ollama · lmstudio · vllm · llamacpp · localai
# ============================================================================
$ErrorActionPreference = "Stop"

# ---- argument parsing (no param() — survives `| iex`) ----
$scriptArgs = @()
if ($args) { $scriptArgs = @($args) }

$Command  = "chat"
$Rest     = @()
$Provider = ""

$i = 0
while ($i -lt $scriptArgs.Count) {
    $a = "$($scriptArgs[$i])"
    if ($a -eq "-Provider") {
        $i++
        if ($i -lt $scriptArgs.Count) { $Provider = "$($scriptArgs[$i])" }
    }
    elseif ($a -like "-Provider=*") {
        $Provider = $a -replace '^-Provider=', ''
    }
    elseif ($a -in @("ask","health","config","version","chat","tui","web","switch")) {
        $Command = $a
    }
    else {
        $Rest += $a
    }
    $i++
}

$VERSION      = "5.0.0"
$REPO_URL     = "https://github.com/AyhanMansur/AyhanX-Agent"
$DESIGN_URL   = "https://raw.githubusercontent.com/AyhanMansur/AyhanX-Agent/refs/heads/main/DESIGN.md"
$APP_DIR      = Join-Path $env:USERPROFILE ".ai_platform"
$VENV         = Join-Path $APP_DIR ".venv"
$VENV_PY      = Join-Path $VENV "Scripts\python.exe"
$VENV_PIP     = Join-Path $VENV "Scripts\pip.exe"
$RUNNER_DIR   = Join-Path $APP_DIR "runner"
$CONFIG_FILE  = Join-Path $APP_DIR "config.json"
$ENV_FILE     = Join-Path $APP_DIR ".env"
$HISTORY_FILE = Join-Path $APP_DIR "history.txt"
$CHATS_DIR    = Join-Path $APP_DIR "chats"
$LOG_FILE     = Join-Path $APP_DIR "install.log"
$PROVIDER_FILE= Join-Path $APP_DIR "provider"
$PROVIDERS_FILE= Join-Path $APP_DIR "providers.json"
$DESIGN_FILE  = Join-Path $APP_DIR "DESIGN.md"

$env:AI_RUNNER_VERSION = $VERSION
if ($Provider) { $env:AYHANX_PROVIDER = $Provider }

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }
$E = [char]27

# ============================================================================
#  PROVIDER HELPERS
# ============================================================================
function Test-LocalProvider {
    param([string]$p)
    return $p -in @("ollama","lmstudio","vllm","llamacpp","localai","ollama-cloud")
}

function Get-ProviderFromKey {
    param([string]$key)
    if (-not $key) { return "" }
    if ($key -like "sk-or-*")   { return "openrouter" }
    if ($key -like "gsk_*")     { return "groq" }
    if ($key -like "fw_*")      { return "fireworks" }
    if ($key -like "pplx-*")    { return "perplexity" }
    if ($key -like "xai-*")     { return "xai" }
    if ($key -like "csk-*")     { return "cerebras" }
    if ($key -like "nvapi-*")   { return "nvidia" }
    if ($key -like "AIza*")     { return "google" }
    if ($key -like "AQ.*")      { return "google" }
    if ($key -like "sk-*")      { return "deepseek" }
    return ""
}

function Get-ProviderUrl {
    param([string]$p)
    switch ($p) {
        "openrouter"   { return "https://openrouter.ai/api/v1" }
        "groq"         { return "https://api.groq.com/openai/v1" }
        "google"       { return "https://generativelanguage.googleapis.com/v1beta/openai" }
        "mistral"      { return "https://api.mistral.ai/v1" }
        "together"     { return "https://api.together.ai/v1" }
        "fireworks"    { return "https://api.fireworks.ai/inference/v1" }
        "deepinfra"    { return "https://api.deepinfra.com/v1/openai" }
        "perplexity"   { return "https://api.perplexity.ai/v1" }
        "xai"          { return "https://api.x.ai/v1" }
        "cerebras"     { return "https://api.cerebras.ai/v1" }
        "abacus"       { return "https://routellm.abacus.ai/v1" }
        "novita"       { return "https://api.novita.ai/openai/v1" }
        "siliconcloud" { return "https://api.siliconflow.cn/v1" }
        "bytedance"    { return "https://ark.cn-beijing.volces.com/api/v3" }
        "aliyun"       { return "https://dashscope.aliyuncs.com/compatible-mode/v1" }
        "minimax"      { return "https://api.minimax.io/v1" }
        "edenai"       { return "https://api.edenai.run/v3" }
        "nvidia"       { return "https://integrate.api.nvidia.com/v1" }
        "ollama-cloud" { return "https://ollama.com/v1" }
        "ollama"       { if ($env:OLLAMA_URL)   { return $env:OLLAMA_URL }   else { return "http://localhost:11434/v1" } }
        "lmstudio"     { if ($env:LMSTUDIO_URL) { return $env:LMSTUDIO_URL } else { return "http://localhost:1234/v1" } }
        "vllm"         { if ($env:VLLM_URL)     { return $env:VLLM_URL }     else { return "http://localhost:8000/v1" } }
        "llamacpp"     { if ($env:LLAMACPP_URL) { return $env:LLAMACPP_URL } else { return "http://localhost:8080/v1" } }
        "localai"      { if ($env:LOCALAI_URL)  { return $env:LOCALAI_URL }  else { return "http://localhost:8080/v1" } }
        default        { return "https://api.deepseek.com" }
    }
}

function Get-ProviderDefaultModel {
    param([string]$p)
    switch ($p) {
        "openrouter"   { return "deepseek/deepseek-chat" }
        "groq"         { return "llama-3.3-70b-versatile" }
        "google"       { return "gemini-2.5-flash" }
        "mistral"      { return "mistral-large-latest" }
        "together"     { return "meta-llama/Llama-3.3-70B-Instruct-Turbo" }
        "fireworks"    { return "accounts/fireworks/models/llama-v3p1-8b-instruct" }
        "deepinfra"    { return "meta-llama/Meta-Llama-3.1-70B-Instruct" }
        "perplexity"   { return "sonar-pro" }
        "xai"          { return "grok-2-latest" }
        "cerebras"     { return "llama3.1-8b" }
        "abacus"       { return "gpt-4o" }
        "novita"       { return "meta-llama/llama-3.1-8b-instruct" }
        "siliconcloud" { return "Qwen/Qwen2.5-7B-Instruct" }
        "bytedance"    { return "doubao-pro-4k" }
        "aliyun"       { return "qwen-plus" }
        "minimax"      { return "abab6.5s-chat" }
        "edenai"       { return "openai/gpt-4o" }
        "nvidia"       { return "meta/llama-3.1-8b-instruct" }
        "ollama-cloud" { return "llama3.2" }
        "ollama"       { return "qwen2.5:3b" }
        "lmstudio"     { return "local-model" }
        "vllm"         { return "local-model" }
        "llamacpp"     { return "local-model" }
        "localai"      { return "local-model" }
        default        { return "deepseek-chat" }
    }
}

function Get-ProviderLabel {
    param([string]$p)
    switch ($p) {
        "openrouter"   { return "OpenRouter" }
        "groq"         { return "Groq" }
        "google"       { return "Google AI Studio" }
        "mistral"      { return "Mistral" }
        "together"     { return "Together AI" }
        "fireworks"    { return "Fireworks AI" }
        "deepinfra"    { return "DeepInfra" }
        "perplexity"   { return "Perplexity" }
        "xai"          { return "xAI (Grok)" }
        "cerebras"     { return "Cerebras" }
        "abacus"       { return "Abacus AI" }
        "novita"       { return "Novita AI" }
        "siliconcloud" { return "SiliconCloud" }
        "bytedance"    { return "ByteDance Ark" }
        "aliyun"       { return "Aliyun DashScope" }
        "minimax"      { return "MiniMax" }
        "edenai"       { return "EdenAI" }
        "nvidia"       { return "NVIDIA NIM" }
        "ollama-cloud" { return "Ollama Cloud" }
        "ollama"       { return "Ollama" }
        "lmstudio"     { return "LM Studio" }
        "vllm"         { return "vLLM" }
        "llamacpp"     { return "llama.cpp" }
        "localai"      { return "LocalAI" }
        default        { return "DeepSeek" }
    }
}

function Test-LocalServer {
    param([string]$url)
    try {
        $uri = "$($url.TrimEnd('/'))/models"
        $resp = Invoke-WebRequest -Uri $uri -TimeoutSec 2 -UseBasicParsing `
            -Headers @{ Authorization = "Bearer local" } -ErrorAction Stop
        return $resp.StatusCode -eq 200
    } catch { return $false }
}

function Find-LocalProvider {
    $pairs = @(
        @{ name="ollama";   url=$(if ($env:OLLAMA_URL)   { $env:OLLAMA_URL }   else { "http://localhost:11434/v1" }) },
        @{ name="lmstudio"; url=$(if ($env:LMSTUDIO_URL) { $env:LMSTUDIO_URL } else { "http://localhost:1234/v1" }) },
        @{ name="vllm";     url=$(if ($env:VLLM_URL)     { $env:VLLM_URL }     else { "http://localhost:8000/v1" }) },
        @{ name="llamacpp"; url=$(if ($env:LLAMACPP_URL) { $env:LLAMACPP_URL } else { "http://localhost:8080/v1" }) },
        @{ name="localai";  url=$(if ($env:LOCALAI_URL)  { $env:LOCALAI_URL }  else { "http://localhost:8080/v1" }) }
    )
    foreach ($p in $pairs) {
        if (Test-LocalServer $p.url) { return $p.name }
    }
    return ""
}

# ============================================================================
#  UI PRIMITIVES
# ============================================================================
function Get-TermWidth {
    try {
        $w = [Console]::WindowWidth
        if ($w -gt 96) { return 96 }
        if ($w -lt 50) { return 50 }
        return $w
    } catch { return 80 }
}

function Write-Rule {
    $w = Get-TermWidth
    Write-Host "  " -NoNewline
    Write-Host ("─" * ($w - 4)) -ForegroundColor DarkCyan
}

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "  ▍ " -ForegroundColor Cyan -NoNewline
    Write-Host $Text -ForegroundColor White
}
function Write-Ok    { param([string]$Text) Write-Host "  ✔ " -ForegroundColor Green -NoNewline; Write-Host $Text }
function Write-Warn  { param([string]$Text) Write-Host "  ! " -ForegroundColor Yellow -NoNewline; Write-Host $Text }
function Write-Err   { param([string]$Text) Write-Host "  ✘ " -ForegroundColor Red -NoNewline; Write-Host $Text }
function Write-Info  { param([string]$Text) Write-Host "  · " -ForegroundColor DarkGray -NoNewline; Write-Host $Text -ForegroundColor DarkGray }

function Write-Logo {
    $lines = @(
'     ░███               ░██                              ░██    ░██            ░███                                        ░██    '
'  ░██░██              ░██                               ░██  ░██            ░██░██                                       ░██    '
' ░██  ░██  ░██    ░██ ░████████   ░██████   ░████████    ░██░██            ░██  ░██   ░████████  ░███████  ░████████  ░████████ '
'░█████████ ░██    ░██ ░██    ░██       ░██  ░██    ░██    ░███    ░██████ ░█████████ ░██    ░██ ░██    ░██ ░██    ░██    ░██    '
'░██    ░██ ░██    ░██ ░██    ░██  ░███████  ░██    ░██   ░██░██           ░██    ░██ ░██    ░██ ░█████████ ░██    ░██    ░██    '
'░██    ░██ ░██   ░███ ░██    ░██ ░██   ░██  ░██    ░██  ░██  ░██          ░██    ░██ ░██   ░███ ░██        ░██    ░██    ░██    '
'░██    ░██  ░█████░██ ░██    ░██  ░█████░██ ░██    ░██ ░██    ░██         ░██    ░██  ░█████░██  ░███████  ░██    ░██     ░████ '
'                  ░██                                                                       ░██                                 '
'            ░███████                                                                  ░░███████                                '
    )
    $ramp = @(30, 36, 37, 43, 44, 80, 87)
    $max = 0
    foreach ($l in $lines) { if ($l.Length -gt $max) { $max = $l.Length } }
    Write-Host ""
    foreach ($l in $lines) {
        $out = ""
        for ($k = 0; $k -lt $l.Length; $k++) {
            $c = $ramp[[math]::Min([math]::Floor($k * $ramp.Length / $max), $ramp.Length - 1)]
            $out += "$E[1;38;5;${c}m$($l[$k])"
        }
        Write-Host "$out$E[0m"
    }
    Write-Host ""
}

function Write-Tagline {
    Write-Host "  ◆ " -ForegroundColor Cyan -NoNewline
    Write-Host "AyhanX-Agent" -ForegroundColor White -NoNewline
    Write-Host "  · " -ForegroundColor DarkGray -NoNewline
    Write-Host "$(Get-ProviderLabel $env:AYHANX_PROVIDER)" -ForegroundColor DarkGray -NoNewline
    Write-Host " · v$VERSION" -ForegroundColor DarkGray
    Write-Rule
}

function Write-Outro {
    Write-Host ""
    Write-Rule
    Write-Host "  ◆ " -ForegroundColor Cyan -NoNewline
    Write-Host "thanks for using AyhanX-Agent" -ForegroundColor White
    Write-Host "  $REPO_URL" -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================================
#  ENVIRONMENT
# ============================================================================
function Find-Python {
    $candidates = @(
        @{ exe="py"; args=@("-3.12") },
        @{ exe="py"; args=@("-3.11") },
        @{ exe="py"; args=@("-3.10") },
        @{ exe="py"; args=@("-3.13") },
        @{ exe="python"; args=@() },
        @{ exe="python3"; args=@() }
    )
    foreach ($c in $candidates) {
        try {
            $check = & $c.exe @($c.args) --version 2>&1
            if ("$check" -match 'Python 3\.(\d+)\.') {
                $minor = [int]$matches[1]
                if ($minor -ge 10 -and $minor -le 13) { return $c }
            }
        } catch { continue }
    }
    return $null
}

function Install-Python {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "trying winget..."
        try {
            & winget install --id Python.Python.3.12 --silent `
                --accept-package-agreements --accept-source-agreements 2>&1 |
                Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "installed via winget"
                $env:PATH = [Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                            [Environment]::GetEnvironmentVariable("PATH","User")
                return $true
            }
        } catch { Write-Info "winget failed, falling back to direct download" }
    }
    $url = "https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe"
    $tmp = Join-Path $env:TEMP "python-3.12.7-amd64.exe"
    try {
        Write-Info "downloading Python 3.12 installer..."
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
        $proc = Start-Process -FilePath $tmp -Wait -PassThru `
            -ArgumentList "/quiet","InstallAllUsers=0","PrependPath=1","Include_test=0"
        if ($proc.ExitCode -eq 0) {
            Write-Ok "Python 3.12 installed"
            $env:PATH = [Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                        [Environment]::GetEnvironmentVariable("PATH","User")
            return $true
        }
    } catch { Write-Err "download failed: $_" }
    return $false
}

function Invoke-Step {
    param([string]$Label, [scriptblock]$Action)
    Write-Host "  · $Label ... " -NoNewline
    try {
        & $Action 2>&1 | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
        if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
            Write-Host "✔" -ForegroundColor Green; return $true
        } else {
            Write-Host "✘" -ForegroundColor Red; return $false
        }
    } catch {
        Write-Host "✘" -ForegroundColor Red
        Write-Host "    $_" -ForegroundColor DarkGray; return $false
    }
}

function Test-PypiMirror {
    param([string]$url)
    try {
        $resp = Invoke-WebRequest -Uri "$($url.TrimEnd('/'))/" -TimeoutSec 6 `
            -UseBasicParsing -Method Head -ErrorAction Stop
        return $resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400
    } catch { return $false }
}

function Get-PypiMirror {
    $mirrors = @(
        "https://pypi.org/simple",
        "https://mirror-pypi.runflare.com/simple",
        "https://mirrors.aliyun.com/pypi/simple",
        "https://pypi.tuna.tsinghua.edu.cn/simple"
    )
    foreach ($m in $mirrors) { if (Test-PypiMirror $m) { return $m } }
    return ""
}

function Fetch-DesignMd {
    if (Test-Path $DESIGN_FILE) { return }
    Write-Info "fetching DESIGN.md from repo..."
    try {
        Invoke-WebRequest -Uri $DESIGN_URL -OutFile $DESIGN_FILE -UseBasicParsing -TimeoutSec 10
        Write-Ok "DESIGN.md cached"
    } catch {
        Write-Warn "could not fetch DESIGN.md"
    }
}

function Initialize-Environment {
    Write-Section "Environment"
    New-Item -ItemType Directory -Force -Path $APP_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path $RUNNER_DIR | Out-Null
    New-Item -ItemType Directory -Force -Path $CHATS_DIR | Out-Null

    $py = Find-Python
    if (-not $py) {
        Write-Warn "no Python 3.10–3.13 found — installing"
        if (-not (Install-Python)) {
            Write-Err "could not install Python automatically"
            Write-Info "install Python 3.12 from https://www.python.org/downloads/"
            exit 1
        }
        $py = Find-Python
        if (-not $py) { Write-Err "Python still not found"; exit 1 }
    }
    $version = & $py.exe @($py.args) --version 2>&1
    Write-Ok "python → $version"

    $rebuild = $false
    if (-not (Test-Path $VENV_PY)) { $rebuild = $true }
    if (-not $rebuild) {
        try {
            & $VENV_PY -c "import httpx,rich,prompt_toolkit,fastapi,uvicorn" 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { $rebuild = $true }
        } catch { $rebuild = $true }
    }

    if ($rebuild) {
        $mirror = Get-PypiMirror
        if (-not $mirror) { Write-Err "no PyPI mirror reachable"; exit 1 }
        $hostName = ([System.Uri]$mirror).Host
        Write-Ok "package index → $hostName"

        if (Test-Path $VENV) { Remove-Item -Recurse -Force $VENV }
        $created = Invoke-Step "creating virtual environment" {
            & $py.exe @($py.args) -m venv $VENV
        }
        if (-not $created) { Write-Err "venv creation failed"; exit 1 }

        Invoke-Step "upgrading pip" {
            & $VENV_PIP install -q --upgrade pip --timeout 10 --retries 1
        } | Out-Null

        $installed = Invoke-Step "installing packages" {
            & $VENV_PIP install --index-url $mirror --trusted-host $hostName `
                --timeout 20 --retries 3 httpx rich prompt_toolkit fastapi uvicorn pyreadline3
        }
        if (-not $installed) { Write-Err "package install failed — see $LOG_FILE"; exit 1 }
    } else {
        Write-Ok "runtime ready"
    }

    Fetch-DesignMd
}

function Read-EnvFile {
    if (-not (Test-Path $ENV_FILE)) { return }
    Get-Content $ENV_FILE | ForEach-Object {
        if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim().Trim('"',"'"), "Process")
        }
    }
}

function Initialize-Credentials {
    Write-Section "Credentials"
    Read-EnvFile

    $prov = ""
    if ($env:AYHANX_PROVIDER -and $env:AYHANX_PROVIDER -ne "auto") { $prov = $env:AYHANX_PROVIDER }
    if (-not $prov -and $env:DEEPSEEK_BASE_URL) {
        $u = $env:DEEPSEEK_BASE_URL
        if     ($u -match "openrouter")    { $prov = "openrouter" }
        elseif ($u -match "groq")          { $prov = "groq" }
        elseif ($u -match "generativelanguage") { $prov = "google" }
        elseif ($u -match "mistral")       { $prov = "mistral" }
        elseif ($u -match "together")      { $prov = "together" }
        elseif ($u -match "fireworks")     { $prov = "fireworks" }
        elseif ($u -match "deepinfra")     { $prov = "deepinfra" }
        elseif ($u -match "perplexity")    { $prov = "perplexity" }
        elseif ($u -match "x\.ai")         { $prov = "xai" }
        elseif ($u -match "cerebras")      { $prov = "cerebras" }
        elseif ($u -match "abacus")        { $prov = "abacus" }
        elseif ($u -match "novita")        { $prov = "novita" }
        elseif ($u -match "siliconflow")   { $prov = "siliconcloud" }
        elseif ($u -match "volces")        { $prov = "bytedance" }
        elseif ($u -match "dashscope")     { $prov = "aliyun" }
        elseif ($u -match "minimax")       { $prov = "minimax" }
        elseif ($u -match "edenai")        { $prov = "edenai" }
        elseif ($u -match "nvidia")        { $prov = "nvidia" }
        elseif ($u -match "ollama\.com")   { $prov = "ollama-cloud" }
        elseif ($u -match ":11434")        { $prov = "ollama" }
        elseif ($u -match ":1234")         { $prov = "lmstudio" }
        elseif ($u -match ":8000")         { $prov = "vllm" }
        elseif ($u -match ":8080")         { $prov = "llamacpp" }
        elseif ($u -match "deepseek")      { $prov = "deepseek" }
    }

    if (-not $prov -or $env:AYHANX_PROVIDER -eq "auto") {
        $detected = Find-LocalProvider
        if ($detected) {
            $prov = $detected
            Write-Ok "detected local server → $(Get-ProviderLabel $prov)"
        }
    }
    if (-not $prov) { $prov = Get-ProviderFromKey $env:DEEPSEEK_API_KEY }
    if (-not $prov -and (Test-Path $PROVIDER_FILE)) {
        $prov = (Get-Content $PROVIDER_FILE -ErrorAction SilentlyContinue | Select-Object -First 1)
    }
    if (-not $prov) { $prov = "deepseek" }

    if (Test-LocalProvider $prov) {
        if (-not $env:DEEPSEEK_API_KEY) { $env:DEEPSEEK_API_KEY = "local" }
        Write-Ok "local provider — no API key required"
    } else {
        if (-not $env:DEEPSEEK_API_KEY) {
            Write-Warn "no API key found for $(Get-ProviderLabel $prov)"
            $secure = Read-Host "  paste your key" -AsSecureString
            $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
            if (-not $plain) { Write-Err "a key is required"; exit 1 }
            $env:DEEPSEEK_API_KEY = $plain
            "DEEPSEEK_API_KEY=$plain" | Out-File -FilePath $ENV_FILE -Encoding UTF8 -NoNewline
            Write-Ok "key saved"
        } else { Write-Ok "key loaded" }
    }

    $prov | Out-File -FilePath $PROVIDER_FILE -Encoding UTF8 -NoNewline
    $env:AYHANX_PROVIDER = $prov
    if (-not $env:DEEPSEEK_BASE_URL) { $env:DEEPSEEK_BASE_URL = Get-ProviderUrl $prov }
    if (-not $env:DEEPSEEK_MODEL)    { $env:DEEPSEEK_MODEL    = Get-ProviderDefaultModel $prov }

    if (-not (Test-Path $PROVIDERS_FILE)) {
        $data = @{
            $prov = @{
                key   = $env:DEEPSEEK_API_KEY
                url   = $env:DEEPSEEK_BASE_URL
                model = $env:DEEPSEEK_MODEL
            }
        }
        $data | ConvertTo-Json -Depth 5 | Out-File -FilePath $PROVIDERS_FILE -Encoding UTF8
    }

    Write-Ok "provider → $(Get-ProviderLabel $prov)"
    Write-Info "endpoint → $env:DEEPSEEK_BASE_URL"
    Write-Info "model    → $env:DEEPSEEK_MODEL"
}

# ============================================================================
#  WRITE: runner/tools.py
# ============================================================================
function Write-Tools {
    $c = @'
"""AyhanX-Agent — full-power tools."""
import json, os, subprocess, tempfile
from datetime import datetime, timezone
from pathlib import Path

TOOL_SPECS = [
    {"type": "function", "function": {"name": "get_current_time",
        "description": "Get the current UTC date and time in ISO 8601 format.",
        "parameters": {"type": "object", "properties": {}}}},
    {"type": "function", "function": {"name": "calculate",
        "description": "Evaluate a simple arithmetic expression.",
        "parameters": {"type": "object", "properties": {"expression": {"type": "string"}}, "required": ["expression"]}}},
    {"type": "function", "function": {"name": "list_directory",
        "description": "List files in a directory under the user's home.",
        "parameters": {"type": "object", "properties": {"path": {"type": "string"}}}}},
    {"type": "function", "function": {"name": "read_file",
        "description": "Read the full content of a text file under the user's home.",
        "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}}},
    {"type": "function", "function": {"name": "write_file",
        "description": "Create or overwrite a text file. Creates parent directories. Actually writes and runs code.",
        "parameters": {"type": "object", "properties": {
            "path": {"type": "string"}, "content": {"type": "string"}}, "required": ["path", "content"]}}},
    {"type": "function", "function": {"name": "edit_file",
        "description": "Replace an exact string in a file. old_string must be unique.",
        "parameters": {"type": "object", "properties": {
            "path": {"type": "string"}, "old_string": {"type": "string"},
            "new_string": {"type": "string"}}, "required": ["path", "old_string", "new_string"]}}},
    {"type": "function", "function": {"name": "make_dir",
        "description": "Create a directory (and parents).",
        "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}}},
    {"type": "function", "function": {"name": "delete_file",
        "description": "Delete a file (not a directory).",
        "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}}},
    {"type": "function", "function": {"name": "run_shell",
        "description": "Run a shell command in the user's home directory. Returns stdout+stderr+exit code.",
        "parameters": {"type": "object", "properties": {
            "command": {"type": "string"}, "timeout": {"type": "integer"}}, "required": ["command"]}}},
    {"type": "function", "function": {"name": "run_python",
        "description": "Run Python code via python3 (temp file). Returns output.",
        "parameters": {"type": "object", "properties": {"code": {"type": "string"}}, "required": ["code"]}}},
]

def _safe_resolve(p):
    base = Path.home()
    if not p: return base
    t = (base / p).expanduser().resolve()
    if t != base and base not in t.parents:
        raise ValueError(f"path escapes home: {p}")
    return t

def _err(m): return json.dumps({"error": m})
def _ok(m, **ex): return json.dumps({"ok": True, "message": m, **ex})

BLOCKED = ("rm -rf /", "rm -rf /*", "mkfs", ":(){", "dd if=/dev/zero",
           "> /dev/sda", "chmod -R 000 /", ":(){:|:&};:",
           "del /f /s /q c:\\", "format c:", "rd /s /q c:\\")
def _is_destructive(cmd):
    c = cmd.lower()
    return any(p in c for p in BLOCKED)

def tool_get_current_time(_a): return datetime.now(timezone.utc).isoformat()

def tool_calculate(a):
    e = a.get("expression", "").strip()
    if not e: return _err("empty")
    if any(ch not in "0123456789+-*/(). " for ch in e): return _err(f"bad char in {e!r}")
    try: return str(eval(e, {"__builtins__": {}}, {}))
    except Exception as ex: return _err(str(ex))

def tool_list_directory(a):
    rel = a.get("path", "").strip()
    try: t = _safe_resolve(rel)
    except ValueError as e: return _err(str(e))
    if not t.exists(): return _err(f"not found: {t}")
    if not t.is_dir(): return _err(f"not a dir: {t}")
    try: items = sorted(t.iterdir())
    except PermissionError: return _err("permission denied")
    result = []
    for p in items[:300]:
        try:
            st = p.stat()
            result.append({"name": p.name, "type": "dir" if p.is_dir() else "file",
                            "size": st.st_size if p.is_file() else None,
                            "modified": datetime.fromtimestamp(st.st_mtime).isoformat()})
        except Exception:
            result.append({"name": p.name, "type": "unknown"})
    return json.dumps(result, indent=2)

def tool_read_file(a):
    rel = a.get("path", "").strip()
    if not rel: return _err("path required")
    try: t = _safe_resolve(rel)
    except ValueError as e: return _err(str(e))
    if not t.exists(): return _err(f"not found: {t}")
    if not t.is_file(): return _err(f"not a file: {t}")
    try: data = t.read_text(encoding="utf-8", errors="replace")
    except PermissionError: return _err("permission denied")
    if len(data) > 200*1024: data = data[:200*1024] + "\n... [truncated]"
    return data

def tool_write_file(a):
    rel = a.get("path", "").strip(); content = a.get("content", "")
    if not rel: return _err("path required")
    try: t = _safe_resolve(rel)
    except ValueError as e: return _err(str(e))
    if t.exists() and t.is_dir(): return _err(f"is a directory: {t}")
    try:
        t.parent.mkdir(parents=True, exist_ok=True)
        t.write_text(content, encoding="utf-8")
        return _ok(f"wrote {t.stat().st_size} bytes to {t}", path=str(t), size=t.stat().st_size)
    except PermissionError: return _err(f"permission denied: {t}")
    except Exception as e: return _err(f"{type(e).__name__}: {e}")

def tool_edit_file(a):
    rel = a.get("path", "").strip(); old = a.get("old_string", ""); new = a.get("new_string", "")
    if not rel: return _err("path required")
    if not old: return _err("old_string required")
    try: t = _safe_resolve(rel)
    except ValueError as e: return _err(str(e))
    if not t.exists(): return _err(f"not found: {t}")
    if not t.is_file(): return _err(f"not a file: {t}")
    try: content = t.read_text(encoding="utf-8")
    except PermissionError: return _err("permission denied")
    count = content.count(old)
    if count == 0: return _err(f"old_string not found in {t}")
    if count > 1: return _err(f"old_string appears {count} times — must be unique")
    try:
        t.write_text(content.replace(old, new, 1), encoding="utf-8")
        return _ok(f"edited {t}", path=str(t))
    except PermissionError: return _err("permission denied")

def tool_make_dir(a):
    rel = a.get("path", "").strip()
    if not rel: return _err("path required")
    try: t = _safe_resolve(rel)
    except ValueError as e: return _err(str(e))
    try:
        t.mkdir(parents=True, exist_ok=True)
        return _ok(f"created {t}", path=str(t))
    except PermissionError: return _err("permission denied")
    except Exception as e: return _err(f"{type(e).__name__}: {e}")

def tool_delete_file(a):
    rel = a.get("path", "").strip()
    if not rel: return _err("path required")
    try: t = _safe_resolve(rel)
    except ValueError as e: return _err(str(e))
    if not t.exists(): return _err(f"not found: {t}")
    if t.is_dir(): return _err(f"is a directory: {t}")
    try:
        t.unlink(); return _ok(f"deleted {t}", path=str(t))
    except PermissionError: return _err("permission denied")

def tool_run_shell(a):
    cmd = a.get("command", "").strip()
    if not cmd: return _err("command required")
    if _is_destructive(cmd): return _err("refused: destructive")
    try: timeout = max(1, min(int(a.get("timeout", 30)), 300))
    except (ValueError, TypeError): timeout = 30
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                            timeout=timeout, cwd=str(Path.home()))
        out = r.stdout; err = r.stderr; combined = ""
        if out: combined += out
        if err:
            if combined: combined += "\n"
            combined += f"[stderr]\n{err}"
        if r.returncode != 0: combined += f"\n[exit code: {r.returncode}]"
        return combined[:10000] or "(no output)"
    except subprocess.TimeoutExpired: return _err(f"timed out ({timeout}s)")
    except FileNotFoundError as e: return _err(f"not found: {e}")
    except Exception as e: return _err(f"{type(e).__name__}: {e}")

def tool_run_python(a):
    code = a.get("code", "")
    if not code: return _err("code required")
    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False,
                                          prefix="ai_agent_", encoding="utf-8") as f:
            f.write(code); tmp = f.name
        try:
            r = subprocess.run(["python3", tmp], capture_output=True, text=True,
                                timeout=60, cwd=str(Path.home()))
            out = r.stdout; err = r.stderr; combined = ""
            if out: combined += out
            if err:
                if combined: combined += "\n"
                combined += f"[stderr]\n{err}"
            if r.returncode != 0: combined += f"\n[exit code: {r.returncode}]"
            return combined[:10000] or "(no output)"
        finally:
            try: os.unlink(tmp)
            except Exception: pass
    except subprocess.TimeoutExpired: return _err("timed out (60s)")
    except Exception as e: return _err(f"{type(e).__name__}: {e}")

TOOL_IMPLS = {
    "get_current_time": tool_get_current_time, "calculate": tool_calculate,
    "list_directory": tool_list_directory, "read_file": tool_read_file,
    "write_file": tool_write_file, "edit_file": tool_edit_file,
    "make_dir": tool_make_dir, "delete_file": tool_delete_file,
    "run_shell": tool_run_shell, "run_python": tool_run_python,
}
'@
    [System.IO.File]::WriteAllText((Join-Path $RUNNER_DIR "tools.py"), $c,
        (New-Object System.Text.UTF8Encoding($false)))
}

# ============================================================================
#  WRITE: runner/tui.py (24 providers)
# ============================================================================
function Write-Tui {
    $c = @'
"""AyhanX-Agent — terminal chat with 24 providers."""
import html, json, os, sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
import httpx
from prompt_toolkit import PromptSession
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.formatted_text import HTML
from prompt_toolkit.history import FileHistory
from prompt_toolkit.key_binding import KeyBindings
from prompt_toolkit.styles import Style
from rich import box
from rich.console import Console, Group
from rich.live import Live
from rich.markdown import Markdown
from rich.panel import Panel
from rich.spinner import Spinner
from rich.table import Table
from rich.text import Text
from .tools import TOOL_IMPLS, TOOL_SPECS

VERSION = os.environ.get("AI_RUNNER_VERSION", "5.0.0")
APP_DIR = Path(os.environ.get("APP_DIR", Path.home() / ".ai_platform"))
CONFIG_PATH = APP_DIR / "config.json"
HISTORY_PATH = APP_DIR / "history.txt"
CHATS_DIR = APP_DIR / "chats"
PROVIDERS_FILE = APP_DIR / "providers.json"
DESIGN_FILE = APP_DIR / "DESIGN.md"
CHATS_DIR.mkdir(parents=True, exist_ok=True)

PROVIDER = os.environ.get("AYHANX_PROVIDER", "deepseek")
LOCAL_PROVIDERS = {"ollama", "lmstudio", "vllm", "llamacpp", "localai", "ollama-cloud"}

PROVIDER_DEFAULTS = {
    "deepseek":   {"url": "https://api.deepseek.com", "model": "deepseek-chat"},
    "openrouter": {"url": "https://openrouter.ai/api/v1", "model": "deepseek/deepseek-chat"},
    "groq":       {"url": "https://api.groq.com/openai/v1", "model": "llama-3.3-70b-versatile"},
    "google":     {"url": "https://generativelanguage.googleapis.com/v1beta/openai", "model": "gemini-2.5-flash"},
    "mistral":    {"url": "https://api.mistral.ai/v1", "model": "mistral-large-latest"},
    "together":   {"url": "https://api.together.ai/v1", "model": "meta-llama/Llama-3.3-70B-Instruct-Turbo"},
    "fireworks":  {"url": "https://api.fireworks.ai/inference/v1", "model": "accounts/fireworks/models/llama-v3p1-8b-instruct"},
    "deepinfra":  {"url": "https://api.deepinfra.com/v1/openai", "model": "meta-llama/Meta-Llama-3.1-70B-Instruct"},
    "perplexity": {"url": "https://api.perplexity.ai/v1", "model": "sonar-pro"},
    "xai":        {"url": "https://api.x.ai/v1", "model": "grok-2-latest"},
    "cerebras":   {"url": "https://api.cerebras.ai/v1", "model": "llama3.1-8b"},
    "abacus":     {"url": "https://routellm.abacus.ai/v1", "model": "gpt-4o"},
    "novita":     {"url": "https://api.novita.ai/openai/v1", "model": "meta-llama/llama-3.1-8b-instruct"},
    "siliconcloud": {"url": "https://api.siliconflow.cn/v1", "model": "Qwen/Qwen2.5-7B-Instruct"},
    "bytedance":  {"url": "https://ark.cn-beijing.volces.com/api/v3", "model": "doubao-pro-4k"},
    "aliyun":     {"url": "https://dashscope.aliyuncs.com/compatible-mode/v1", "model": "qwen-plus"},
    "minimax":    {"url": "https://api.minimax.io/v1", "model": "abab6.5s-chat"},
    "edenai":     {"url": "https://api.edenai.run/v3", "model": "openai/gpt-4o"},
    "nvidia":     {"url": "https://integrate.api.nvidia.com/v1", "model": "meta/llama-3.1-8b-instruct"},
    "ollama-cloud": {"url": "https://ollama.com/v1", "model": "llama3.2"},
    "ollama":     {"url": "http://localhost:11434/v1", "model": "qwen2.5:3b"},
    "lmstudio":   {"url": "http://localhost:1234/v1", "model": "local-model"},
    "vllm":       {"url": "http://localhost:8000/v1", "model": "local-model"},
    "llamacpp":   {"url": "http://localhost:8080/v1", "model": "local-model"},
    "localai":    {"url": "http://localhost:8080/v1", "model": "local-model"},
}

PROVIDER_MODELS = {
    "deepseek": ["deepseek-chat", "deepseek-reasoner"],
    "openrouter": ["deepseek/deepseek-chat", "deepseek/deepseek-chat-v3-0324:free",
                   "deepseek/deepseek-r1:free", "meta-llama/llama-3.3-70b-instruct:free",
                   "qwen/qwen-2.5-72b-instruct:free", "microsoft/phi-4:free"],
    "groq": ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768", "gemma2-9b-it"],
    "google": ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-flash-latest", "gemini-flash-lite-latest"],
    "mistral": ["mistral-large-latest", "mistral-small-latest", "codestral-latest", "open-mistral-nemo"],
    "together": ["meta-llama/Llama-3.3-70B-Instruct-Turbo", "meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo",
                 "Qwen/Qwen2.5-72B-Instruct-Turbo", "deepseek-ai/DeepSeek-R1"],
    "fireworks": ["accounts/fireworks/models/llama-v3p1-8b-instruct",
                  "accounts/fireworks/models/llama-v3p1-70b-instruct",
                  "accounts/fireworks/models/qwen2p5-72b-instruct"],
    "deepinfra": ["meta-llama/Meta-Llama-3.1-70B-Instruct", "meta-llama/Meta-Llama-3.1-8B-Instruct",
                  "Qwen/Qwen2.5-72B-Instruct", "deepseek-ai/DeepSeek-V3"],
    "perplexity": ["sonar-pro", "sonar", "sonar-reasoning", "sonar-reasoning-pro"],
    "xai": ["grok-2-latest", "grok-2-vision-latest", "grok-beta"],
    "cerebras": ["llama3.1-8b", "llama3.1-70b", "llama-3.3-70b"],
    "abacus": ["gpt-4o", "gpt-4o-mini", "claude-3-5-sonnet", "llama-3.1-405b"],
    "novita": ["meta-llama/llama-3.1-8b-instruct", "meta-llama/llama-3.1-70b-instruct",
               "qwen/qwen-2.5-72b-instruct"],
    "siliconcloud": ["Qwen/Qwen2.5-7B-Instruct", "Qwen/Qwen2.5-72B-Instruct",
                     "deepseek-ai/DeepSeek-V3", "meta-llama/Meta-Llama-3.1-8B-Instruct"],
    "bytedance": ["doubao-pro-4k", "doubao-pro-32k", "doubao-lite-4k"],
    "aliyun": ["qwen-plus", "qwen-turbo", "qwen-max", "qwen-long"],
    "minimax": ["abab6.5s-chat", "abab6.5-chat", "abab5.5-chat"],
    "edenai": ["openai/gpt-4o", "anthropic/claude-3-5-sonnet", "google/gemini-2.5-flash"],
    "nvidia": ["meta/llama-3.1-8b-instruct", "meta/llama-3.3-70b-instruct",
               "meta/llama-3.1-70b-instruct", "nvidia/llama-3.1-nemotron-70b-instruct",
               "qwen/qwen2.5-coder-32b-instruct", "deepseek-ai/deepseek-r1"],
    "ollama-cloud": ["llama3.2", "llama3.1", "qwen2.5", "deepseek-r1"],
    "ollama": [], "lmstudio": [], "vllm": [], "llamacpp": [], "localai": [],
}

LABELS = {
    "deepseek": "DeepSeek", "openrouter": "OpenRouter", "groq": "Groq",
    "google": "Google AI Studio", "mistral": "Mistral", "together": "Together AI",
    "fireworks": "Fireworks AI", "deepinfra": "DeepInfra", "perplexity": "Perplexity",
    "xai": "xAI (Grok)", "cerebras": "Cerebras", "abacus": "Abacus AI",
    "novita": "Novita AI", "siliconcloud": "SiliconCloud", "bytedance": "ByteDance Ark",
    "aliyun": "Aliyun DashScope", "minimax": "MiniMax", "edenai": "EdenAI",
    "nvidia": "NVIDIA NIM",
    "ollama-cloud": "Ollama Cloud",
    "ollama": "Ollama", "lmstudio": "LM Studio", "vllm": "vLLM",
    "llamacpp": "llama.cpp", "localai": "LocalAI",
}

def provider_label(name=None): return LABELS.get(name or PROVIDER, (name or PROVIDER))
def is_local(name=None): return (name or PROVIDER) in LOCAL_PROVIDERS

def load_providers():
    if PROVIDERS_FILE.exists():
        try: return json.loads(PROVIDERS_FILE.read_text())
        except Exception: pass
    name = PROVIDER
    d = PROVIDER_DEFAULTS.get(name, PROVIDER_DEFAULTS["deepseek"])
    return {name: {"key": os.environ.get("DEEPSEEK_API_KEY", "local" if is_local(name) else ""),
                    "url": os.environ.get("DEEPSEEK_BASE_URL", d["url"]),
                    "model": os.environ.get("DEEPSEEK_MODEL", d["model"])}}

def save_providers(data):
    PROVIDERS_FILE.write_text(json.dumps(data, indent=2))
    try: os.chmod(PROVIDERS_FILE, 0o600)
    except Exception: pass

def switch_provider(name, providers, cfg):
    global PROVIDER, IS_LOCAL, MODELS, PROVIDER_LABEL
    if name not in providers: return False
    p = providers[name]
    os.environ["DEEPSEEK_API_KEY"] = p["key"]
    os.environ["DEEPSEEK_BASE_URL"] = p["url"]
    os.environ["DEEPSEEK_MODEL"] = p["model"]
    os.environ["AYHANX_PROVIDER"] = name
    try: (APP_DIR / "provider").write_text(name)
    except Exception: pass
    PROVIDER = name
    PROVIDER_LABEL = provider_label(name)
    IS_LOCAL = is_local(name)
    MODELS = PROVIDER_MODELS.get(name, [])
    cfg.model = p["model"]; cfg.save()
    return True

PROVIDER_LABEL = provider_label()
IS_LOCAL = is_local()
MODELS = PROVIDER_MODELS.get(PROVIDER, PROVIDER_MODELS["deepseek"])
START = os.environ.get("AYHANX_START", "new")

def all_models(cfg): return MODELS + [m for m in cfg.custom_models if m not in MODELS]
def save_last(conv):
    if conv.messages: (CHATS_DIR / "last.json").write_text(json.dumps(conv.messages, indent=2))

def fetch_server_models(base_url, api_key):
    h = {"Authorization": f"Bearer {api_key}"}
    if PROVIDER == "openrouter":
        h["HTTP-Referer"] = "https://github.com/AyhanMansur/AyhanX-Agent"
        h["X-Title"] = "AyhanX-Agent"
    try:
        r = httpx.get(f"{base_url.rstrip('/')}/models", headers=h, timeout=6)
        if r.status_code == 200: return [m["id"] for m in r.json().get("data", [])]
    except Exception: pass
    return []

def refresh_local_models(cfg):
    if not IS_LOCAL: return []
    base = os.environ.get("DEEPSEEK_BASE_URL", "")
    key = os.environ.get("DEEPSEEK_API_KEY", "local")
    ids = fetch_server_models(base, key)
    if ids:
        for m in ids:
            if m not in cfg.custom_models and m not in MODELS: cfg.custom_models.append(m)
        cfg.save()
        if cfg.model not in ids: cfg.model = ids[0]; cfg.save()
    return ids

VIOLET = "#40e0d0"; VIOLET_DEEP = "#0f9d9a"; CYAN = "#5eead4"
GOLD = "#fbbf24"; MINT = "#34d399"; RED = "#f87171"
MUTED = "#64748b"; SOFT = "#94a3b8"; TEXT = "#e2e8f0"
console = Console(highlight=False)

@dataclass
class Config:
    model: str = "deepseek-chat"
    system_prompt: str = ""
    agent_mode: bool = False
    max_context_messages: int = 40
    custom_models: list = field(default_factory=list)
    @classmethod
    def load(cls):
        if CONFIG_PATH.exists():
            try:
                d = json.loads(CONFIG_PATH.read_text())
                return cls(**{k: v for k, v in d.items() if k in cls.__annotations__})
            except Exception: pass
        return cls()
    def save(self):
        CONFIG_PATH.write_text(json.dumps(self.__dict__, indent=2))
        try: os.chmod(CONFIG_PATH, 0o600)
        except Exception: pass

@dataclass
class Conversation:
    messages: list = field(default_factory=list)
    created: str = field(default_factory=lambda: datetime.now().isoformat())
    def add_user(self, t): self.messages.append({"role": "user", "content": t})
    def add_assistant(self, t): self.messages.append({"role": "assistant", "content": t})
    def trim(self, n):
        s = [m for m in self.messages if m["role"] == "system"]
        d = [m for m in self.messages if m["role"] != "system"]
        if len(d) > n: d = d[-n:]
        self.messages = s + d
    def save(self, name):
        p = CHATS_DIR / f"{name}.json"; p.write_text(json.dumps(self.messages, indent=2)); return p
    @classmethod
    def load(cls, name):
        p = CHATS_DIR / f"{name}.json"
        if not p.exists(): raise FileNotFoundError(f"no chat named '{name}'")
        c = cls(); c.messages = json.loads(p.read_text()); return c
    def to_api(self): return [m for m in self.messages if m.get("content", "").strip()]

class DeepSeekClient:
    def __init__(self, key, base, model, provider="deepseek"):
        self.api_key = key; self.base_url = base.rstrip("/")
        self.model = model; self.provider = provider
    def _headers(self):
        h = {"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"}
        if self.provider == "openrouter":
            h["HTTP-Referer"] = "https://github.com/AyhanMansur/AyhanX-Agent"
            h["X-Title"] = "AyhanX-Agent"
        return h
    def _hint(self, s):
        b = {401: "invalid key", 402: "no balance", 404: "model not found — try /model",
             429: "rate limited"}.get(s, "")
        if not b: return ""
        if self.provider == "openrouter": return b + " — openrouter.ai/keys"
        if self.provider == "google": return b + " — aistudio.google.com/apikey"
        if self.provider == "mistral": return b + " — console.mistral.ai"
        if self.provider == "together": return b + " — api.together.ai"
        if self.provider == "xai": return b + " — console.x.ai"
        if self.provider == "perplexity": return b + " — perplexity.ai/settings/api"
        if self.provider == "cerebras": return b + " — cloud.cerebras.ai"
        if self.provider == "nvidia": return b + " — build.nvidia.com"
        if self.provider in LOCAL_PROVIDERS: return b + " — is the server running?"
        return b + " — platform.deepseek.com/api_keys"
    def _error(self, s, body):
        msg = body
        try: msg = json.loads(body).get("error", {}).get("message", body)
        except Exception: pass
        h = self._hint(s)
        return f"HTTP {s}: {msg}" + (f"\n→ {h}" if h else "")
    def chat(self, messages, tools=None, stream=True):
        p = {"model": self.model, "messages": messages, "stream": stream}
        if tools: p["tools"] = tools; p["tool_choice"] = "auto"
        c = httpx.Client(timeout=180)
        return self._stream(c, p) if stream else self._nonstream(c, p)
    def _stream(self, client, payload):
        def gen():
            try:
                with client.stream("POST", f"{self.base_url}/chat/completions",
                                   headers=self._headers(), json=payload) as r:
                    if r.status_code >= 400:
                        yield {"error": self._error(r.status_code, r.read().decode(errors="replace"))}; return
                    for line in r.iter_lines():
                        if not line.startswith("data:"): continue
                        d = line[5:].strip()
                        if d == "[DONE]": break
                        try: o = json.loads(d)
                        except json.JSONDecodeError: continue
                        delta = o.get("choices", [{}])[0].get("delta", {})
                        if c := delta.get("content"): yield {"text": c}
            finally: client.close()
        return gen()
    def _nonstream(self, client, payload):
        try:
            r = client.post(f"{self.base_url}/chat/completions", headers=self._headers(), json=payload)
            if r.status_code >= 400: return {"error": self._error(r.status_code, r.text)}
            return r.json()
        finally: client.close()

def _rgb(h): return tuple(int(h[i:i+2], 16) for i in (1, 3, 5))

def gradient(text, s=VIOLET_DEEP, e=CYAN):
    a, b = _rgb(s), _rgb(e); out = Text(); n = max(len(text)-1, 1)
    for i, ch in enumerate(text):
        k = i/n; c = "#" + "".join(f"{round(a[j]+(b[j]-a[j])*k):02x}" for j in range(3))
        out.append(ch, style=f"bold {c}")
    return out

def model_chip(n): return Text(f" {n} ", style=f"bold #0f0a1f on {VIOLET}")
def mode_chip(a): return Text(" AGENT ", style=f"bold #1c1600 on {GOLD}") if a else Text(" CHAT ", style=f"bold #04221a on {MINT}")
def provider_chip():
    l = f" {PROVIDER_LABEL} "
    return Text(l, style="bold #1c1600 on #fbbf24") if IS_LOCAL else Text(l, style=f"bold #0a0f1c on {CYAN}")

def show_header(cfg):
    left = Text.assemble(("◆ ", VIOLET), gradient("AyhanX-Agent"), ("   ", ""), (f"v{VERSION}", MUTED))
    right = Text.assemble(provider_chip(), ("  ", ""), model_chip(cfg.model), ("  ", ""), mode_chip(cfg.agent_mode))
    g = Table.grid(expand=True); g.add_column(ratio=1); g.add_column(justify="right"); g.add_row(left, right)
    console.print(Panel(g, box=box.ROUNDED, border_style=VIOLET_DEEP, padding=(0, 2)))
    console.print(Text("  type a message · /help · /provider · Ctrl+D exit", style=MUTED))
    console.print()

def notice(m, c=MINT): console.print(Text(f"  {m}", style=c))
def error_panel(m): return Panel(Text(m, style=RED), title=Text("error", style=f"bold {RED}"),
                                   title_align="left", box=box.ROUNDED, border_style=RED, padding=(0, 2))
def assistant_panel(t, thinking=False):
    title = Text.assemble(("◆ ", VIOLET), (PROVIDER_LABEL, f"bold {VIOLET}"),
                          ("  thinking…" if thinking else "", MUTED))
    return Panel(Markdown(t or ""), title=title, title_align="left", box=box.ROUNDED,
                 border_style=VIOLET_DEEP, padding=(0, 2))
def print_user(t):
    console.print()
    console.print(Text.assemble((" you ", f"bold #0f0a1f on {CYAN}"), ("  ", ""), (t, TEXT)))
    console.print()
def tool_card(n, a, r):
    ag = json.dumps(a, ensure_ascii=False)[:90]; pv = r[:140].replace("\n", " ")
    if len(r) > 140: pv += "…"
    console.print(Text.assemble(("  ⚙ ", GOLD), (n, f"bold {GOLD}"), ("  ", ""), (ag, MUTED)))
    console.print(Text.assemble(("    └ ", "#334155"), (pv, SOFT)))

def help_panel():
    rows = [("/new","new"),("/clear","clear"),("/model [name]","models"),
            ("/model refresh","refresh local"),("/model add <n>","add model"),
            ("/provider [name]","list/switch provider"),("/provider add <n>","add provider"),
            ("/provider remove <n>","remove provider"),("/system [text]","set system prompt"),
            ("/agent","toggle agent (full terminal access)"),
            ("/save [n]","save"),("/load <n>","load"),("/chats","list saved"),
            ("/history","print"),("/info","config"),("/exit","quit")]
    t = Table.grid(padding=(0, 3)); t.add_column(style=f"bold {CYAN}", no_wrap=True); t.add_column(style=SOFT)
    for c, d in rows: t.add_row(c, d)
    keys = Text.assemble(("Enter", f"bold {TEXT}"),(" send   ", MUTED),
                         ("Esc+Enter", f"bold {TEXT}"),(" newline   ", MUTED),
                         ("↑ ↓", f"bold {TEXT}"), (" history   ", MUTED),
                         ("Ctrl+C", f"bold {TEXT}"), (" cancel", MUTED))
    console.print(Panel(Group(t, Text(""), keys), title=Text("commands", style=f"bold {VIOLET}"),
                        title_align="left", box=box.ROUNDED, border_style=VIOLET_DEEP, padding=(1, 2)))

def info_panel(cfg, conv):
    t = Table.grid(padding=(0, 3)); t.add_column(style=f"bold {VIOLET}", no_wrap=True); t.add_column(style=TEXT)
    t.add_row("provider", PROVIDER_LABEL)
    t.add_row("endpoint", os.environ.get("DEEPSEEK_BASE_URL", "?"))
    t.add_row("model", cfg.model)
    t.add_row("mode", "agent" if cfg.agent_mode else "chat")
    t.add_row("system prompt", "set" if cfg.system_prompt else "none")
    t.add_row("messages", str(len(conv.messages)))
    t.add_row("config", str(CONFIG_PATH)); t.add_row("providers", str(PROVIDERS_FILE)); t.add_row("chats", str(CHATS_DIR))
    if DESIGN_FILE.exists(): t.add_row("design", str(DESIGN_FILE))
    console.print(Panel(t, title=Text("info", style=f"bold {VIOLET}"), title_align="left",
                        box=box.ROUNDED, border_style=VIOLET_DEEP, padding=(1, 2)))

def chats_table():
    chats = sorted(CHATS_DIR.glob("*.json"))
    if not chats: notice("no saved chats", MUTED); return
    t = Table(box=box.SIMPLE_HEAD, header_style=f"bold {VIOLET}", border_style=MUTED, expand=False)
    t.add_column("name", style=f"bold {CYAN}"); t.add_column("msgs", justify="right"); t.add_column("updated", style=SOFT)
    for p in chats:
        try: n = str(len(json.loads(p.read_text())))
        except Exception: n = "?"
        t.add_row(p.stem, n, datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M"))
    console.print(t)

def print_history(conv):
    if not conv.messages: notice("nothing yet", MUTED); return
    for m in conv.messages:
        if m["role"] == "user": console.print(Text.assemble(("❯ ", f"bold {CYAN}"), (m["content"], TEXT)))
        elif m["role"] == "assistant": console.print(Markdown(m["content"]))
        console.print()

KB = KeyBindings()
@KB.add("enter")
def _(e): e.current_buffer.validate_and_handle()
@KB.add("escape", "enter")
def _(e): e.current_buffer.insert_text("\n")
@KB.add("c-j")
def _(e): e.current_buffer.insert_text("\n")

PROMPT_STYLE = Style.from_dict({"arrow": f"{VIOLET} bold", "bottom-toolbar": "bg:#0b0a14 #94a3b8",
                                 "completion-menu": "bg:#14122a #e2e8f0",
                                 "completion-menu.completion.current": f"bg:{VIOLET_DEEP} #ffffff"})

def toolbar(cfg, conv):
    mode = '<style fg="#fbbf24"><b>AGENT</b></style>' if cfg.agent_mode else '<style fg="#34d399"><b>CHAT</b></style>'
    pf = "#fbbf24" if IS_LOCAL else "#5eead4"
    return HTML(f' <style fg="{pf}"><b>{html.escape(PROVIDER_LABEL)}</b></style>'
                f'  ·  <style fg="#a78bfa"><b>{html.escape(cfg.model)}</b></style>'
                f'  ·  {mode}  ·  {len(conv.messages)} msgs'
                f'    <style fg="#64748b">/help · /provider · Ctrl+D exit</style>')

AGENT_SYSTEM = (
    "You are AyhanX-Agent, a capable coding assistant with FULL access "
    "to the user's filesystem via tools.\n\n"
    "RULES:\n"
    "1. When the user asks you to create/edit/run code or files, USE the "
    "tools (write_file, edit_file, run_shell, run_python). Do NOT just "
    "show code — actually write and run it.\n"
    "2. When the user asks something that needs real data (time, files, "
    "calculations), call the appropriate tool.\n"
    "3. After creating a file, verify it works (run it if applicable).\n"
    "4. Be concise in your final answer — show what you did.\n"
    "5. Paths are relative to $HOME. Use relative paths.\n"
    "6. NEVER use destructive commands (rm -rf /, mkfs, dd, etc.)\n\n"
    "DESIGN PRINCIPLES (when writing UI code):\n"
    "- Use springs, not CSS transitions, for gesture-driven animation\n"
    "- Animations must be interruptible: start from current on-screen value\n"
    "- Hand off finger velocity to springs on drag release\n"
    "- Animate only transform/opacity, never width/height\n"
    "- Use backdrop-filter for translucent materials\n"
    "- Always include @media (prefers-reduced-motion: reduce) fallbacks\n"
    "- Feedback on pointer-down, not release\n"
    "- Rubber-band at edges, never hard-stop\n"
)

def build_msgs(conv, cfg, agent=False):
    m = conv.to_api()
    if agent:
        prefix = cfg.system_prompt or AGENT_SYSTEM
        m = [{"role": "system", "content": prefix}] + m
    elif cfg.system_prompt:
        m = [{"role": "system", "content": cfg.system_prompt}] + m
    return m

def stream_response(client, conv, cfg):
    buf = []
    live = Live(Spinner("dots", text=Text(" thinking", style=MUTED), style=VIOLET),
                console=console, refresh_per_second=12, transient=False)
    live.start()
    try:
        for c in client.chat(build_msgs(conv, cfg, agent=False), stream=True):
            if "error" in c: live.update(error_panel(c["error"])); live.stop(); return ""
            if "text" in c:
                buf.append(c["text"]); live.update(assistant_panel("".join(buf), thinking=True))
    except httpx.RequestError as e: live.update(error_panel(f"network error: {e}")); live.stop(); return ""
    except KeyboardInterrupt:
        live.update(assistant_panel("".join(buf) + "\n\n*cancelled*")); live.stop(); return "".join(buf)
    full = "".join(buf)
    if not full: live.update(Text("  (empty response)", style=MUTED)); live.stop(); return ""
    live.update(assistant_panel(full)); live.stop(); return full

def run_agent(client, conv, cfg):
    msgs = build_msgs(conv, cfg, agent=True)
    for iteration in range(12):
        with console.status(Text(f" thinking (step {iteration+1})", style=MUTED), spinner="dots", spinner_style=VIOLET):
            try: resp = client.chat(msgs, tools=TOOL_SPECS, stream=False)
            except httpx.RequestError as e: resp = {"error": f"network error: {e}"}
        if isinstance(resp, dict) and "error" in resp:
            console.print(error_panel(resp["error"])); return ""
        msg = resp.get("choices", [{}])[0].get("message", {})
        tcalls = msg.get("tool_calls") or []
        if not tcalls:
            content = msg.get("content") or ""
            console.print(assistant_panel(content)); return content
        if msg.get("content"): console.print(Text(msg["content"], style=TEXT))
        msgs.append(msg)
        for tc in tcalls:
            fn = tc.get("function", {}); name = fn.get("name", "?")
            try: a = json.loads(fn.get("arguments") or "{}")
            except json.JSONDecodeError: a = {}
            impl = TOOL_IMPLS.get(name)
            if impl:
                try: r = impl(a)
                except Exception as e: r = f"Error: {type(e).__name__}: {e}"
            else: r = f"Error: unknown tool '{name}'"
            tool_card(name, a, r)
            msgs.append({"role": "tool", "tool_call_id": tc.get("id", ""), "content": r})
    console.print(error_panel("stopped after 12 steps")); return ""

COMMANDS = ["/help","/new","/clear","/model","/provider","/system","/agent","/save","/load","/chats","/history","/info","/exit"]

def main():
    global IS_LOCAL, MODELS, PROVIDER_LABEL
    key = os.environ.get("DEEPSEEK_API_KEY", "local" if IS_LOCAL else "")
    if not key and not IS_LOCAL: console.print(error_panel("DEEPSEEK_API_KEY is not set")); return 1
    base = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
    cfg = Config.load()
    if os.environ.get("DEEPSEEK_MODEL"): cfg.model = os.environ["DEEPSEEK_MODEL"]
    elif cfg.model not in MODELS and cfg.model not in cfg.custom_models:
        cfg.model = MODELS[0] if MODELS else "local-model"
    providers = load_providers()
    if IS_LOCAL:
        with console.status(Text(f" querying {PROVIDER_LABEL}…", style=MUTED), spinner="dots", spinner_style=VIOLET):
            ids = refresh_local_models(cfg)
        if not ids:
            notice(f"could not reach {PROVIDER_LABEL} at {base}", RED)
            notice("is it running? use /model refresh or /provider to switch", MUTED)
        elif cfg.model not in ids: cfg.model = ids[0]; cfg.save()
    conv = Conversation(); show_header(cfg)
    if START == "resume" and (CHATS_DIR / "last.json").exists():
        conv = Conversation.load("last"); notice(f"resumed · {len(conv.messages)} messages"); console.print()
    session = PromptSession(key_bindings=KB, style=PROMPT_STYLE, history=FileHistory(str(HISTORY_PATH)),
                            completer=WordCompleter(COMMANDS, ignore_case=True), complete_while_typing=True,
                            bottom_toolbar=lambda: toolbar(cfg, conv))
    while True:
        try: raw = session.prompt(HTML("<arrow>❯ </arrow>"))
        except KeyboardInterrupt: console.print(Text("  ^C", style=MUTED)); continue
        except EOFError: save_last(conv); console.print(); notice("bye", MUTED); return 0
        text = raw.strip()
        if not text: continue
        if text.startswith("/"):
            parts = text.split(maxsplit=1); cmd = parts[0].lower()
            args = parts[1].split() if len(parts) > 1 else []
            if cmd in ("/exit", "/quit"): save_last(conv); notice("bye", MUTED); return 0
            elif cmd == "/help": help_panel()
            elif cmd == "/clear": console.clear(); show_header(cfg)
            elif cmd == "/provider":
                if not args:
                    chips = Text.assemble(*[(" " + n + " " + ("◆" if n == PROVIDER else " ") + "  ",
                        f"bold #0f0a1f on {VIOLET}" if n == PROVIDER else f"{SOFT}") for n in providers])
                    console.print(Text("  providers  ", style=MUTED), chips)
                elif args[0].lower() == "add":
                    if len(args) < 2: notice("usage: /provider add <name>", RED); continue
                    pname = args[1].lower(); defaults = PROVIDER_DEFAULTS.get(pname, {"url": "", "model": ""})
                    url_in = console.input(f"  url [{defaults['url']}]: ").strip() or defaults["url"]
                    key_in = "local" if pname in LOCAL_PROVIDERS else console.input("  key: ").strip()
                    model_in = console.input(f"  model [{defaults['model']}]: ").strip() or defaults["model"]
                    providers[pname] = {"key": key_in, "url": url_in, "model": model_in}
                    save_providers(providers); notice(f"✔ {pname} added")
                elif args[0].lower() == "remove":
                    if len(args) < 2: notice("usage: /provider remove <name>", RED); continue
                    if args[1] in providers: del providers[args[1]]; save_providers(providers); notice(f"✔ {args[1]} removed")
                    else: notice(f"unknown: {args[1]}", RED)
                elif args[0] in providers:
                    if switch_provider(args[0], providers, cfg):
                        notice(f"→ switched to {PROVIDER_LABEL}")
                        console.print(f"  [dim]model[/]    {cfg.model}")
                        console.print(f"  [dim]endpoint[/] {os.environ['DEEPSEEK_BASE_URL']}")
                        if IS_LOCAL:
                            with console.status(Text(f" querying {PROVIDER_LABEL}…", style=MUTED), spinner="dots", spinner_style=VIOLET):
                                ids = refresh_local_models(cfg)
                            if ids and cfg.model not in ids: cfg.model = ids[0]; cfg.save()
                        console.print(); show_header(cfg)
                    else: notice(f"switch failed: {args[0]}", RED)
                else:
                    notice(f"unknown provider: {args[0]}", RED)
                    console.print("  [dim]available: " + ", ".join(providers) + "[/]")
            elif cmd == "/model":
                if args and args[0].lower() == "refresh":
                    if not IS_LOCAL: notice("refresh only for local", RED); continue
                    with console.status(Text(f" querying {PROVIDER_LABEL}…", style=MUTED), spinner="dots", spinner_style=VIOLET):
                        ids = refresh_local_models(cfg)
                    notice(f"refreshed · {len(ids)} models" if ids else "no models", MINT if ids else RED); continue
                models = all_models(cfg)
                if not args:
                    if not models: notice("no models — try /model refresh", MUTED); continue
                    chips = Text.assemble(*[(" " + m + " " + ("◆" if m == cfg.model else " ") + "  ",
                        f"bold #0f0a1f on {VIOLET}" if m == cfg.model else f"{SOFT}") for m in models])
                    console.print(Text("  models  ", style=MUTED), chips)
                elif args[0].lower() == "add":
                    if len(args) < 2: notice("usage: /model add <name>", RED)
                    else:
                        n = args[1]
                        if n not in models: cfg.custom_models.append(n); cfg.save()
                        notice(f"model added: {n}")
                elif args[0] in models or IS_LOCAL:
                    cfg.model = args[0]; cfg.save(); os.environ["DEEPSEEK_MODEL"] = args[0]; notice(f"model → {args[0]}")
                else: notice(f"unknown model: {args[0]}", RED)
            elif cmd == "/new": conv = Conversation(); notice("new conversation")
            elif cmd == "/system":
                t = " ".join(args).strip()
                if not t:
                    if cfg.system_prompt: console.print(Panel(Text(cfg.system_prompt, style=TEXT),
                        title=Text("system prompt", style=f"bold {VIOLET}"), title_align="left",
                        box=box.ROUNDED, border_style=VIOLET_DEEP, padding=(0, 2)))
                    else: notice("no system prompt set", MUTED)
                else: cfg.system_prompt = t; cfg.save(); notice("system prompt updated")
            elif cmd == "/agent":
                cfg.agent_mode = not cfg.agent_mode; cfg.save()
                notice("agent mode " + ("on — full terminal access" if cfg.agent_mode else "off"),
                       GOLD if cfg.agent_mode else MUTED)
            elif cmd == "/save":
                n = args[0] if args else datetime.now().strftime("chat-%Y%m%d-%H%M%S")
                try: p = conv.save(n); notice(f"saved → {p}")
                except Exception as e: notice(f"save failed: {e}", RED)
            elif cmd == "/load":
                if not args: notice("usage: /load <name>", RED)
                else:
                    try: conv = Conversation.load(args[0]); notice(f"loaded {len(conv.messages)} messages")
                    except FileNotFoundError as e: notice(str(e), RED)
            elif cmd == "/chats": chats_table()
            elif cmd == "/history": print_history(conv)
            elif cmd == "/info": info_panel(cfg, conv)
            else: notice(f"unknown command: {cmd}", RED)
            continue
        print_user(text); conv.add_user(text); conv.trim(cfg.max_context_messages)
        api_key = os.environ.get("DEEPSEEK_API_KEY", "local" if IS_LOCAL else "")
        base_url = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
        client = DeepSeekClient(api_key, base_url, cfg.model, PROVIDER)
        try:
            if cfg.agent_mode: answer = run_agent(client, conv, cfg)
            else: answer = stream_response(client, conv, cfg)
        except KeyboardInterrupt: notice("cancelled", MUTED); conv.messages.pop(); continue
        if answer: conv.add_assistant(answer)
        else: conv.messages.pop()
        console.print()

if __name__ == "__main__":
    sys.exit(main())
'@
    [System.IO.File]::WriteAllText((Join-Path $RUNNER_DIR "tui.py"), $c,
        (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $RUNNER_DIR "__init__.py"), "",
        (New-Object System.Text.UTF8Encoding($false)))
}

# ============================================================================
#  WRITE: runner/server.py (Web UI with 24 providers + auto-port)
# ============================================================================
function Write-Server {
    $c = @'
"""AyhanX-Agent — web UI with 24 providers + auto-port."""
import json, os, socket
from datetime import datetime
from pathlib import Path
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, StreamingResponse
from pydantic import BaseModel

try:
    from .tools import TOOL_IMPLS, TOOL_SPECS
except ImportError:
    from tools import TOOL_IMPLS, TOOL_SPECS

VERSION = os.environ.get("AI_RUNNER_VERSION", "5.0.0")
APP_DIR = Path(os.environ.get("APP_DIR", Path.home() / ".ai_platform"))
CONFIG_PATH = APP_DIR / "config.json"
PROVIDERS_FILE = APP_DIR / "providers.json"
PROVIDER_FILE = APP_DIR / "provider"
CHATS_DIR = APP_DIR / "chats"
CHATS_DIR.mkdir(parents=True, exist_ok=True)

LOCAL_PROVIDERS = {"ollama", "lmstudio", "vllm", "llamacpp", "localai", "ollama-cloud"}
LABELS = {
    "deepseek": "DeepSeek", "openrouter": "OpenRouter", "groq": "Groq",
    "google": "Google AI Studio", "mistral": "Mistral", "together": "Together AI",
    "fireworks": "Fireworks AI", "deepinfra": "DeepInfra", "perplexity": "Perplexity",
    "xai": "xAI (Grok)", "cerebras": "Cerebras", "abacus": "Abacus AI",
    "novita": "Novita AI", "siliconcloud": "SiliconCloud", "bytedance": "ByteDance Ark",
    "aliyun": "Aliyun DashScope", "minimax": "MiniMax", "edenai": "EdenAI",
    "nvidia": "NVIDIA NIM",
    "ollama-cloud": "Ollama Cloud",
    "ollama": "Ollama", "lmstudio": "LM Studio", "vllm": "vLLM",
    "llamacpp": "llama.cpp", "localai": "LocalAI",
}
PROVIDER_MODELS = {
    "deepseek": ["deepseek-chat", "deepseek-reasoner"],
    "openrouter": ["deepseek/deepseek-chat", "deepseek/deepseek-chat-v3-0324:free",
                   "deepseek/deepseek-r1:free", "meta-llama/llama-3.3-70b-instruct:free",
                   "qwen/qwen-2.5-72b-instruct:free", "microsoft/phi-4:free"],
    "groq": ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768", "gemma2-9b-it"],
    "google": ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-flash-latest", "gemini-flash-lite-latest"],
    "mistral": ["mistral-large-latest", "mistral-small-latest", "codestral-latest", "open-mistral-nemo"],
    "together": ["meta-llama/Llama-3.3-70B-Instruct-Turbo", "meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo",
                 "Qwen/Qwen2.5-72B-Instruct-Turbo", "deepseek-ai/DeepSeek-R1"],
    "fireworks": ["accounts/fireworks/models/llama-v3p1-8b-instruct",
                  "accounts/fireworks/models/llama-v3p1-70b-instruct",
                  "accounts/fireworks/models/qwen2p5-72b-instruct"],
    "deepinfra": ["meta-llama/Meta-Llama-3.1-70B-Instruct", "meta-llama/Meta-Llama-3.1-8B-Instruct",
                  "Qwen/Qwen2.5-72B-Instruct", "deepseek-ai/DeepSeek-V3"],
    "perplexity": ["sonar-pro", "sonar", "sonar-reasoning", "sonar-reasoning-pro"],
    "xai": ["grok-2-latest", "grok-2-vision-latest", "grok-beta"],
    "cerebras": ["llama3.1-8b", "llama3.1-70b", "llama-3.3-70b"],
    "abacus": ["gpt-4o", "gpt-4o-mini", "claude-3-5-sonnet", "llama-3.1-405b"],
    "novita": ["meta-llama/llama-3.1-8b-instruct", "meta-llama/llama-3.1-70b-instruct",
               "qwen/qwen-2.5-72b-instruct"],
    "siliconcloud": ["Qwen/Qwen2.5-7B-Instruct", "Qwen/Qwen2.5-72B-Instruct",
                     "deepseek-ai/DeepSeek-V3", "meta-llama/Meta-Llama-3.1-8B-Instruct"],
    "bytedance": ["doubao-pro-4k", "doubao-pro-32k", "doubao-lite-4k"],
    "aliyun": ["qwen-plus", "qwen-turbo", "qwen-max", "qwen-long"],
    "minimax": ["abab6.5s-chat", "abab6.5-chat", "abab5.5-chat"],
    "edenai": ["openai/gpt-4o", "anthropic/claude-3-5-sonnet", "google/gemini-2.5-flash"],
    "nvidia": ["meta/llama-3.1-8b-instruct", "meta/llama-3.3-70b-instruct",
               "meta/llama-3.1-70b-instruct", "nvidia/llama-3.1-nemotron-70b-instruct",
               "qwen/qwen2.5-coder-32b-instruct", "deepseek-ai/deepseek-r1"],
    "ollama-cloud": ["llama3.2", "llama3.1", "qwen2.5", "deepseek-r1"],
    "ollama": [], "lmstudio": [], "vllm": [], "llamacpp": [], "localai": [],
}

AGENT_SYSTEM = (
    "You are AyhanX-Agent, a capable coding assistant with FULL access "
    "to the user's filesystem via tools.\n\n"
    "RULES:\n"
    "1. When the user asks you to create/edit/run code or files, USE the "
    "tools (write_file, edit_file, run_shell, run_python). Do NOT just "
    "show code — actually write and run it.\n"
    "2. When the user asks something that needs real data (time, files, "
    "calculations), call the appropriate tool.\n"
    "3. After creating a file, verify it works (run it if applicable).\n"
    "4. Be concise in your final answer — show what you did.\n"
    "5. Paths are relative to $HOME. Use relative paths.\n"
    "6. NEVER use destructive commands (rm -rf /, mkfs, dd, etc.)\n\n"
    "DESIGN PRINCIPLES (when writing UI code):\n"
    "- Use springs, not CSS transitions, for gesture-driven animation\n"
    "- Animations must be interruptible: start from current on-screen value\n"
    "- Hand off finger velocity to springs on drag release\n"
    "- Animate only transform/opacity, never width/height\n"
    "- Use backdrop-filter for translucent materials\n"
    "- Always include @media (prefers-reduced-motion: reduce) fallbacks\n"
    "- Feedback on pointer-down, not release\n"
    "- Rubber-band at edges, never hard-stop\n"
)

def _load_providers():
    if PROVIDERS_FILE.exists():
        try: return json.loads(PROVIDERS_FILE.read_text())
        except Exception: pass
    return {}

def _active():
    try: return PROVIDER_FILE.read_text().strip()
    except Exception: return "deepseek"

def _load_cfg():
    if CONFIG_PATH.exists():
        try: return json.loads(CONFIG_PATH.read_text())
        except Exception: pass
    return {"model": "deepseek-chat", "system_prompt": "", "agent_mode": False}

def _save_cfg(cfg):
    CONFIG_PATH.write_text(json.dumps(cfg, indent=2))
    try: os.chmod(CONFIG_PATH, 0o600)
    except Exception: pass

def _client_info():
    providers = _load_providers()
    name = _active()
    if name not in providers: name = next(iter(providers), "deepseek")
    p = providers.get(name, {"key": "local", "url": "https://api.deepseek.com", "model": "deepseek-chat"})
    return name, p

def _headers(name, key):
    h = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
    if name == "openrouter":
        h["HTTP-Referer"] = "https://github.com/AyhanMansur/AyhanX-Agent"
        h["X-Title"] = "AyhanX-Agent"
    return h

def _err_msg(status, body):
    msg = body
    try: msg = json.loads(body).get("error", {}).get("message", body)
    except Exception: pass
    return f"HTTP {status}: {msg}"

def find_free_port(start=8080, end=8200):
    for p in range(start, end):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            s.bind(('0.0.0.0', p)); return p
        except OSError:
            continue
        finally:
            s.close()
    return None

class ChatReq(BaseModel):
    conversation_id: str | None = None
    message: str
    agent: bool = False

class SwitchReq(BaseModel):
    provider: str

class ModelReq(BaseModel):
    model: str

class AgentReq(BaseModel):
    enabled: bool

app = FastAPI(title="AyhanX-Agent", version=VERSION)

@app.get("/api/config")
def get_config():
    name, p = _client_info()
    cfg = _load_cfg()
    return {"version": VERSION, "provider": name, "provider_label": LABELS.get(name, name),
            "is_local": name in LOCAL_PROVIDERS, "model": cfg.get("model", p["model"]),
            "agent_mode": cfg.get("agent_mode", False)}

@app.get("/api/providers")
def list_providers():
    providers = _load_providers()
    return [{"name": k, "label": LABELS.get(k, k), "url": v["url"], "model": v["model"],
             "active": k == _active(), "local": k in LOCAL_PROVIDERS} for k, v in providers.items()]

@app.post("/api/switch")
def switch(req: SwitchReq):
    providers = _load_providers()
    if req.provider not in providers: raise HTTPException(404, "provider not found")
    PROVIDER_FILE.write_text(req.provider)
    p = providers[req.provider]
    cfg = _load_cfg(); cfg["model"] = p["model"]; _save_cfg(cfg)
    return {"ok": True, "provider": req.provider, "model": p["model"]}

@app.get("/api/models")
def list_models():
    name, p = _client_info()
    cfg = _load_cfg()
    built_in = PROVIDER_MODELS.get(name, [])
    custom = cfg.get("custom_models", [])
    all_m = built_in + [m for m in custom if m not in built_in]
    if name in LOCAL_PROVIDERS:
        try:
            r = httpx.get(f"{p['url'].rstrip('/')}/models", headers=_headers(name, p["key"]), timeout=4)
            if r.status_code == 200:
                for m in [x["id"] for x in r.json().get("data", [])]:
                    if m not in all_m: all_m.append(m)
        except Exception: pass
    return {"models": all_m, "current": cfg.get("model", p["model"])}

@app.post("/api/model")
def set_model(req: ModelReq):
    cfg = _load_cfg(); cfg["model"] = req.model; _save_cfg(cfg)
    return {"ok": True, "model": req.model}

@app.post("/api/agent")
def set_agent(req: AgentReq):
    cfg = _load_cfg(); cfg["agent_mode"] = req.enabled; _save_cfg(cfg)
    return {"ok": True, "agent_mode": req.enabled}

@app.get("/api/conversations")
def list_convs():
    items = []
    for p in sorted(CHATS_DIR.glob("*.json"), key=lambda x: x.stat().st_mtime, reverse=True):
        if p.stem == "last": continue
        try: n = len(json.loads(p.read_text()))
        except Exception: n = 0
        items.append({"id": p.stem, "messages": n,
                       "updated": datetime.fromtimestamp(p.stat().st_mtime).isoformat()})
    return items

@app.delete("/api/conversations/{cid}")
def del_conv(cid: str):
    p = CHATS_DIR / f"{cid}.json"
    if p.exists(): p.unlink()
    return {"ok": True}

@app.get("/api/conversations/{cid}")
def get_conv(cid: str):
    p = CHATS_DIR / f"{cid}.json"
    if not p.exists(): raise HTTPException(404, "not found")
    return {"id": cid, "messages": json.loads(p.read_text())}

@app.post("/api/chat")
async def chat(req: ChatReq):
    text = req.message.strip()
    if not text: raise HTTPException(400, "empty message")
    name, p = _client_info()
    cfg = _load_cfg()
    key = p["key"]; base = p["url"].rstrip("/")
    model = cfg.get("model", p["model"])
    system_prompt = cfg.get("system_prompt", "")
    cid = req.conversation_id or datetime.now().strftime("chat-%Y%m%d-%H%M%S")
    conv_path = CHATS_DIR / f"{cid}.json"
    if conv_path.exists():
        try: messages = json.loads(conv_path.read_text())
        except Exception: messages = []
    else: messages = []
    messages.append({"role": "user", "content": text})
    conv_path.write_text(json.dumps(messages, indent=2))

    async def stream():
        try:
            yield f"data: {json.dumps({'type':'start','conversation_id':cid})}\n\n"
            if req.agent:
                async for chunk in _run_agent(messages, name, key, base, model, system_prompt, cid, conv_path):
                    yield chunk
            else:
                async for chunk in _run_chat(messages, name, key, base, model, system_prompt, cid, conv_path):
                    yield chunk
        except Exception as e:
            yield f"data: {json.dumps({'type':'error','message':str(e)})}\n\n"

    return StreamingResponse(stream(), media_type="text/event-stream")

async def _run_chat(messages, name, key, base, model, system_prompt, cid, conv_path):
    msgs = []
    if system_prompt: msgs.append({"role": "system", "content": system_prompt})
    msgs.extend(messages)
    full = []
    async with httpx.AsyncClient(timeout=180) as client:
        async with client.stream("POST", f"{base}/chat/completions",
                                  headers=_headers(name, key),
                                  json={"model": model, "messages": msgs, "stream": True}) as r:
            if r.status_code >= 400:
                body = (await r.aread()).decode(errors="replace")
                yield f"data: {json.dumps({'type':'error','message':_err_msg(r.status_code, body)})}\n\n"
                return
            async for line in r.aiter_lines():
                if not line.startswith("data:"): continue
                data = line[5:].strip()
                if data == "[DONE]": break
                try: obj = json.loads(data)
                except json.JSONDecodeError: continue
                delta = obj.get("choices", [{}])[0].get("delta", {})
                if chunk := delta.get("content"):
                    full.append(chunk)
                    yield f"data: {json.dumps({'type':'delta','text':chunk})}\n\n"
    answer = "".join(full)
    messages.append({"role": "assistant", "content": answer})
    conv_path.write_text(json.dumps(messages, indent=2))
    yield f"data: {json.dumps({'type':'done'})}\n\n"

async def _run_agent(messages, name, key, base, model, system_prompt, cid, conv_path):
    msgs = [{"role": "system", "content": system_prompt or AGENT_SYSTEM}] + messages
    for iteration in range(12):
        print(f"[agent] iter {iteration+1} · {model}", flush=True)
        try:
            async with httpx.AsyncClient(timeout=180) as client:
                r = await client.post(f"{base}/chat/completions", headers=_headers(name, key),
                                       json={"model": model, "messages": msgs,
                                             "tools": TOOL_SPECS, "tool_choice": "auto"})
        except Exception as e:
            yield f"data: {json.dumps({'type':'error','message':f'network: {e}'})}\n\n"
            return
        if r.status_code >= 400:
            yield f"data: {json.dumps({'type':'error','message':_err_msg(r.status_code, r.text)})}\n\n"
            return
        obj = r.json()
        msg = obj.get("choices", [{}])[0].get("message", {})
        tcalls = msg.get("tool_calls") or []
        if not tcalls:
            content = msg.get("content") or ""
            if content:
                yield f"data: {json.dumps({'type':'delta','text':content})}\n\n"
            messages.append({"role": "assistant", "content": content})
            conv_path.write_text(json.dumps(messages, indent=2))
            yield f"data: {json.dumps({'type':'done'})}\n\n"
            return
        if msg.get("content"):
            yield f"data: {json.dumps({'type':'delta','text':msg['content']})}\n\n"
        msgs.append(msg)
        for tc in tcalls:
            fn = tc.get("function", {}); tname = fn.get("name", "?")
            try: args = json.loads(fn.get("arguments") or "{}")
            except json.JSONDecodeError: args = {}
            yield f"data: {json.dumps({'type':'tool','name':tname,'args':args})}\n\n"
            impl = TOOL_IMPLS.get(tname)
            if impl:
                try: result = impl(args)
                except Exception as e: result = f"{type(e).__name__}: {e}"
            else: result = f"unknown tool: {tname}"
            yield f"data: {json.dumps({'type':'tool_result','text':result[:800]})}\n\n"
            msgs.append({"role": "tool", "tool_call_id": tc.get("id", ""), "content": result})
    yield f"data: {json.dumps({'type':'delta','text':'\n\n[agent stopped after 12 iterations]'})}\n\n"
    yield f"data: {json.dumps({'type':'done'})}\n\n"

HTML = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>AyhanX-Agent</title>
<style>
:root{
  --bg:#080b12;--bg-2:#0b0f17;--panel:#10141e;--panel-2:#161b27;--panel-3:#1e2534;
  --border:#232a3d;--border-2:#2f3849;
  --text:#e8eef7;--dim:#8b95a8;--mute:#5c6577;
  --accent:#5eead4;--accent-2:#2dd4bf;--glow:rgba(94,234,212,.15);
  --red:#f87171;--amber:#fbbf24;--green:#34d399;--violet:#a78bfa;--blue:#60a5fa;
}
*{box-sizing:border-box;margin:0;padding:0}
html,body{height:100%;background:var(--bg);color:var(--text);
font:15px/1.6 -apple-system,BlinkMacSystemFont,"Inter","Segoe UI",Roboto,sans-serif;
-webkit-font-smoothing:antialiased;font-optical-sizing:auto}
body::before{content:'';position:fixed;inset:-50%;z-index:0;pointer-events:none;
background:radial-gradient(circle at 20% 10%,rgba(94,234,212,.10),transparent 40%),
radial-gradient(circle at 80% 90%,rgba(167,139,250,.08),transparent 40%);
animation:drift 24s ease-in-out infinite alternate}
@keyframes drift{0%{transform:translate(0,0) scale(1)}100%{transform:translate(3%,-2%) scale(1.05)}}
#app{position:relative;z-index:1;display:flex;height:100vh;overflow:hidden}

.sidebar{width:270px;background:rgba(16,20,30,.55);backdrop-filter:blur(24px) saturate(180%);
-webkit-backdrop-filter:blur(24px) saturate(180%);
border-right:1px solid var(--border);display:flex;flex-direction:column;flex-shrink:0;
transition:width 320ms cubic-bezier(.34,1.56,.64,1),border-right 320ms;will-change:width}
.sidebar.collapsed{width:0;overflow:hidden;border-right:none}
.sidebar.collapsed .sidebar-head,
.sidebar.collapsed .convs,
.sidebar.collapsed .sidebar-foot{opacity:0;pointer-events:none}
.sidebar-head,.convs,.sidebar-foot{transition:opacity 180ms}

@media (prefers-reduced-transparency: reduce){
  .sidebar,.header,.composer-inner{background:var(--panel);backdrop-filter:none;-webkit-backdrop-filter:none}
}
@media (prefers-reduced-motion: reduce){
  *{animation-duration:0.01ms !important;transition-duration:200ms !important}
  .sidebar{transition:width 200ms ease}
  .sidebar.collapsed{width:0}
  body::before{animation:none}
}

.sidebar-head{padding:18px 18px 14px}
.brand{display:flex;align-items:center;gap:10px;margin-bottom:18px}
.brand-icon{width:28px;height:28px;border-radius:8px;
background:linear-gradient(135deg,var(--accent),var(--accent-2));
display:flex;align-items:center;justify-content:center;
color:#0a0e14;font-weight:700;font-size:16px;box-shadow:0 0 16px var(--glow)}
.brand-name{font-weight:600;font-size:14px;letter-spacing:-0.01em}
.brand-ver{font-size:11px;color:var(--mute)}
.new-btn{width:100%;padding:10px 14px;border-radius:10px;
background:linear-gradient(135deg,rgba(94,234,212,.15),rgba(45,212,191,.08));
border:1px solid rgba(94,234,212,.3);color:var(--accent);
font-weight:600;font-size:13px;cursor:pointer;
display:flex;align-items:center;justify-content:center;gap:8px;
transition:transform 100ms,background 200ms,box-shadow 200ms;font-family:inherit}
.new-btn:hover{background:linear-gradient(135deg,rgba(94,234,212,.25),rgba(45,212,191,.15));box-shadow:0 0 20px var(--glow)}
.new-btn:active{transform:scale(0.97)}

.convs{flex:1;overflow-y:auto;padding:8px 10px}
.conv-item{padding:10px 12px;border-radius:10px;cursor:pointer;
display:flex;align-items:center;gap:8px;font-size:13px;color:var(--dim);
transition:background 150ms,color 150ms;margin-bottom:2px}
.conv-item:hover{background:rgba(255,255,255,.04);color:var(--text)}
.conv-item.active{background:rgba(94,234,212,.1);color:var(--accent);border:1px solid rgba(94,234,212,.2)}
.conv-item .title{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.conv-item .del{opacity:0;color:var(--red);font-size:16px;padding:0 2px;background:none;border:none;cursor:pointer;transition:opacity 150ms}
.conv-item:hover .del{opacity:.7}
.empty-state{padding:40px 20px;text-align:center;color:var(--mute);font-size:12px}
.empty-state .icon{font-size:32px;margin-bottom:8px;opacity:.5}

.sidebar-foot{padding:12px 14px;border-top:1px solid var(--border)}
.provider-btn{width:100%;padding:10px 12px;border-radius:10px;
background:rgba(255,255,255,.03);border:1px solid var(--border);
color:var(--text);font-size:12.5px;cursor:pointer;
display:flex;align-items:center;gap:8px;transition:transform 100ms,background 150ms;font-family:inherit}
.provider-btn:hover{background:rgba(255,255,255,.06);border-color:var(--border-2)}
.provider-btn:active{transform:scale(0.98)}
.dot{width:8px;height:8px;border-radius:50%;flex-shrink:0;background:var(--green);box-shadow:0 0 8px currentColor}
.dot.deepseek{background:var(--blue);box-shadow:0 0 8px var(--blue)}
.dot.openrouter{background:var(--violet);box-shadow:0 0 8px var(--violet)}
.dot.groq{background:var(--amber);box-shadow:0 0 8px var(--amber)}
.dot.google{background:var(--red);box-shadow:0 0 8px var(--red)}
.dot.nvidia{background:#76b900;box-shadow:0 0 8px #76b900}
.dot.local{background:var(--green);box-shadow:0 0 8px var(--green)}
.provider-name{flex:1;text-align:left;font-weight:500}

.main{flex:1;display:flex;flex-direction:column;min-width:0}
.header{padding:14px 24px;border-bottom:1px solid var(--border);
display:flex;align-items:center;gap:12px;
background:rgba(11,15,23,.55);backdrop-filter:blur(24px) saturate(180%);-webkit-backdrop-filter:blur(24px) saturate(180%)}
.menu-btn{display:none;background:none;border:none;color:var(--text);font-size:20px;cursor:pointer;padding:6px}
.collapse-btn{background:none;border:1px solid var(--border);color:var(--dim);
width:34px;height:34px;border-radius:8px;cursor:pointer;font-size:12px;
display:flex;align-items:center;justify-content:center;
transition:transform 280ms cubic-bezier(.34,1.56,.64,1),background 150ms,color 150ms,border-color 150ms;
font-family:inherit;flex-shrink:0}
.collapse-btn:hover{background:var(--panel);color:var(--accent);border-color:var(--border-2)}
.collapse-btn:active{transform:scale(0.94) rotate(180deg)}
body.collapsed .collapse-btn{transform:rotate(180deg)}
body.collapsed .collapse-btn:active{transform:scale(0.94)}

.model-sel{padding:6px 12px;border-radius:8px;background:var(--panel);border:1px solid var(--border);
color:var(--text);font-size:13px;cursor:pointer;display:flex;align-items:center;gap:8px;
transition:transform 100ms,background 150ms,border-color 150ms;font-family:inherit}
.model-sel:hover{background:var(--panel-2);border-color:var(--border-2)}
.model-sel:active{transform:scale(0.97)}
.model-sel .chev{font-size:10px;color:var(--mute)}
.spacer{flex:1}

.mode-toggle{padding:6px 14px;border-radius:999px;font-size:12px;font-weight:600;
background:rgba(52,211,153,.15);border:1px solid rgba(52,211,153,.3);
color:var(--green);cursor:pointer;display:flex;align-items:center;gap:6px;
transition:transform 100ms,background 150ms,border-color 150ms;font-family:inherit}
.mode-toggle:hover{filter:brightness(1.15)}
.mode-toggle:active{transform:scale(0.96)}
.mode-toggle.agent{background:rgba(251,191,36,.15);border-color:rgba(251,191,36,.3);color:var(--amber)}
.mode-dot{width:6px;height:6px;border-radius:50%;background:currentColor;box-shadow:0 0 6px currentColor}

.icon-btn{background:none;border:1px solid var(--border);color:var(--dim);
width:34px;height:34px;border-radius:8px;cursor:pointer;font-size:16px;
display:flex;align-items:center;justify-content:center;
transition:transform 100ms,background 150ms,color 150ms,border-color 150ms}
.icon-btn:hover{background:var(--panel);color:var(--text);border-color:var(--border-2)}
.icon-btn:active{transform:scale(0.94)}

.chat{flex:1;overflow-y:auto;padding:8px 0 140px;scroll-behavior:smooth}
.chat::-webkit-scrollbar{width:8px}
.chat::-webkit-scrollbar-thumb{background:var(--border-2);border-radius:4px}

.welcome{max-width:820px;margin:100px auto 0;padding:0 32px;text-align:center;animation:fadeUp 480ms cubic-bezier(.34,1.56,.64,1)}
@keyframes fadeUp{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:translateY(0)}}
.welcome-icon{width:64px;height:64px;border-radius:18px;margin:0 auto 24px;
background:linear-gradient(135deg,var(--accent),var(--accent-2));
display:flex;align-items:center;justify-content:center;font-size:28px;
color:#0a0e14;font-weight:700;box-shadow:0 0 40px var(--glow),0 8px 32px rgba(0,0,0,.3)}
.welcome h1{font-size:36px;font-weight:700;margin-bottom:8px;letter-spacing:-0.02em;
background:linear-gradient(135deg,var(--text),var(--accent));
-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.welcome p{color:var(--dim);font-size:15px;margin-bottom:40px}
.suggestions{display:grid;grid-template-columns:repeat(2,1fr);gap:12px;margin-top:32px}
.sug{padding:14px 18px;background:rgba(255,255,255,.02);border:1px solid var(--border);
border-radius:12px;color:var(--dim);font-size:13.5px;text-align:left;cursor:pointer;
transition:transform 120ms,background 150ms,border-color 150ms;font-family:inherit}
.sug:hover{background:rgba(94,234,212,.06);border-color:rgba(94,234,212,.3);color:var(--text)}
.sug:active{transform:scale(0.98)}

.message{max-width:820px;margin:0 auto;padding:14px 32px;display:flex;gap:16px;animation:msgIn 320ms cubic-bezier(.34,1.56,.64,1)}
@keyframes msgIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
.message+.message{padding-top:4px}
.msg-body{flex:1;min-width:0;line-height:1.7;word-wrap:break-word}
.msg-role{font-size:11px;font-weight:600;color:var(--mute);margin-bottom:4px;letter-spacing:0.02em;text-transform:uppercase}
.msg-user{justify-content:flex-end}
.msg-user .msg-body{flex:0 1 auto;max-width:75%;
background:linear-gradient(135deg,rgba(94,234,212,.08),rgba(45,212,191,.04));
border:1px solid rgba(94,234,212,.2);border-radius:16px;padding:10px 16px;color:var(--text);white-space:pre-wrap}
.msg-user .msg-role{display:none}
.msg-ai .msg-role{color:var(--accent)}
.msg-ai .msg-body p{margin-bottom:12px}
.msg-ai .msg-body p:last-child{margin-bottom:0}
.msg-ai .msg-body code{background:var(--panel-3);padding:2px 6px;border-radius:5px;
font:13px/1.4 "SF Mono","JetBrains Mono",Menlo,monospace;color:var(--accent)}
.msg-ai .msg-body pre{background:var(--bg-2);border:1px solid var(--border);
padding:14px 16px;border-radius:10px;overflow-x:auto;margin:12px 0;
font:13px/1.5 "SF Mono","JetBrains Mono",Menlo,monospace}
.msg-ai .msg-body pre code{background:none;padding:0;color:var(--text)}
.msg-ai .msg-body ul,.msg-ai .msg-body ol{margin:8px 0 12px 24px}
.msg-ai .msg-body li{margin:4px 0}
.msg-ai .msg-body h1,.msg-ai .msg-body h2,.msg-ai .msg-body h3{margin:16px 0 8px;font-weight:600;color:var(--text)}
.msg-ai .msg-body h1{font-size:1.4em}
.msg-ai .msg-body h2{font-size:1.2em}
.msg-ai .msg-body h3{font-size:1.1em}
.msg-ai .msg-body a{color:var(--accent);text-decoration:none;border-bottom:1px solid transparent}
.msg-ai .msg-body a:hover{border-bottom-color:var(--accent)}
.msg-ai .msg-body strong{color:var(--text);font-weight:600}
.msg-ai .msg-body blockquote{border-left:3px solid var(--border-2);padding-left:14px;color:var(--dim);margin:12px 0}

.tool-cards{margin:8px 0 0 32px}
.tool-card{background:rgba(251,191,36,.06);border:1px solid rgba(251,191,36,.2);
border-radius:8px;padding:10px 14px;margin:6px 0;font-size:12px;
font-family:"SF Mono","JetBrains Mono",Menlo,monospace;animation:toolIn 280ms cubic-bezier(.34,1.56,.64,1)}
@keyframes toolIn{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:translateY(0)}}
.tool-card .tool-name{color:var(--amber);font-weight:600}
.tool-card .tool-args{color:var(--mute);margin-left:8px}
.tool-card .tool-result{color:var(--text);margin-top:6px;padding-top:6px;
border-top:1px solid rgba(251,191,36,.15);white-space:pre-wrap;
max-height:120px;overflow-y:auto;font-size:11.5px;line-height:1.5}

.msg-err{background:rgba(248,113,113,.08);border:1px solid rgba(248,113,113,.3);
border-radius:10px;padding:12px 16px;color:var(--red);font-size:13px}

.cursor{display:inline-block;width:7px;height:16px;background:var(--accent);
vertical-align:middle;margin-left:2px;animation:blink 1s steps(2) infinite;border-radius:2px}
@keyframes blink{0%,50%{opacity:1}51%,100%{opacity:0}}

.composer-wrap{position:fixed;bottom:0;left:270px;right:0;
padding:20px 24px 22px;background:linear-gradient(transparent,var(--bg) 30%);
z-index:10;transition:left 320ms cubic-bezier(.34,1.56,.64,1)}
body.collapsed .composer-wrap{left:0}
.composer{max-width:820px;margin:0 auto}
.composer-inner{background:rgba(16,20,30,.85);backdrop-filter:blur(24px) saturate(180%);
-webkit-backdrop-filter:blur(24px) saturate(180%);
border:1px solid var(--border);border-radius:18px;padding:8px 8px 8px 18px;
display:flex;align-items:flex-end;gap:8px;
transition:border-color 200ms,box-shadow 280ms;box-shadow:0 4px 24px rgba(0,0,0,.3)}
.composer-inner:focus-within{border-color:rgba(94,234,212,.4);box-shadow:0 0 0 3px var(--glow),0 4px 24px rgba(0,0,0,.4)}
#input{flex:1;background:none;border:none;outline:none;color:var(--text);
font:inherit;resize:none;max-height:200px;padding:8px 0;line-height:1.6}
#input::placeholder{color:var(--mute)}
.send-btn{width:38px;height:38px;border-radius:12px;border:none;cursor:pointer;
background:linear-gradient(135deg,var(--accent),var(--accent-2));
color:#0a0e14;font-size:18px;font-weight:700;
display:flex;align-items:center;justify-content:center;
transition:transform 120ms cubic-bezier(.34,1.56,.64,1),box-shadow 200ms;flex-shrink:0;font-family:inherit}
.send-btn:hover:not(:disabled){transform:scale(1.05);box-shadow:0 0 20px var(--glow)}
.send-btn:active:not(:disabled){transform:scale(0.95)}
.send-btn:disabled{background:var(--panel-3);color:var(--mute);cursor:not-allowed}
.composer-hint{max-width:820px;margin:8px auto 0;padding:0 4px;
display:flex;justify-content:space-between;font-size:11px;color:var(--mute)}
#status{color:var(--accent)}

.modal{position:fixed;inset:0;background:rgba(0,0,0,.6);backdrop-filter:blur(4px);
z-index:100;display:none;align-items:center;justify-content:center;padding:20px;
animation:fadeIn 180ms cubic-bezier(.34,1.56,.64,1)}
.modal.open{display:flex}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
.modal-content{background:var(--panel);border:1px solid var(--border-2);
border-radius:16px;max-width:480px;width:100%;max-height:80vh;
display:flex;flex-direction:column;box-shadow:0 24px 64px rgba(0,0,0,.5);
animation:modalIn 280ms cubic-bezier(.34,1.56,.64,1);transform-origin:center}
@keyframes modalIn{from{opacity:0;transform:scale(0.92) translateY(8px)}to{opacity:1;transform:scale(1) translateY(0)}}
.modal-head{padding:18px 22px;border-bottom:1px solid var(--border);
display:flex;justify-content:space-between;align-items:center}
.modal-title{font-size:15px;font-weight:600}
.modal-close{background:none;border:none;color:var(--mute);cursor:pointer;font-size:20px;padding:4px;transition:color 150ms}
.modal-close:hover{color:var(--text)}
.modal-body{padding:12px;overflow-y:auto}
.modal-opt{padding:12px 16px;border-radius:10px;cursor:pointer;
display:flex;align-items:center;gap:12px;font-size:13.5px;color:var(--text);
transition:background 150ms,border-color 150ms;border:1px solid transparent}
.modal-opt:hover{background:rgba(255,255,255,.05)}
.modal-opt:active{transform:scale(0.99)}
.modal-opt.active{background:rgba(94,234,212,.1);border-color:rgba(94,234,212,.25);color:var(--accent)}
.modal-opt .opt-main{flex:1;font-weight:500}
.modal-opt .opt-sub{font-size:11px;color:var(--mute);font-family:"SF Mono","JetBrains Mono",Menlo,monospace}
.modal-opt.active .opt-sub{color:var(--accent)}

.toast{position:fixed;bottom:100px;left:50%;transform:translateX(-50%) translateY(20px);
background:var(--panel-2);border:1px solid var(--border-2);
padding:10px 20px;border-radius:10px;font-size:13px;color:var(--text);
opacity:0;pointer-events:none;transition:opacity 280ms,transform 280ms cubic-bezier(.34,1.56,.64,1);
z-index:200;box-shadow:0 8px 24px rgba(0,0,0,.4)}
.toast.show{opacity:1;transform:translateX(-50%) translateY(0)}
.toast.err{border-color:rgba(248,113,113,.4);color:var(--red)}

@media(max-width:768px){
  .sidebar{position:fixed;inset:0 auto 0 0;z-index:50;transform:translateX(-100%);width:270px !important;transition:transform 320ms cubic-bezier(.34,1.56,.64,1)}
  .sidebar.open{transform:translateX(0)}
  .sidebar.collapsed{transform:translateX(-100%)}
  .menu-btn{display:block}
  .collapse-btn{display:none}
  .composer-wrap{left:0 !important;padding:16px 12px}
  .suggestions{grid-template-columns:1fr}
  .welcome h1{font-size:28px}
  .welcome{margin-top:60px}
  .msg-user .msg-body{max-width:90%}
}
</style></head><body>
<div id="app">
<aside class="sidebar" id="sidebar">
<div class="sidebar-head">
<div class="brand"><div class="brand-icon">◆</div>
<div><div class="brand-name">AyhanX-Agent</div>
<div class="brand-ver">v<span id="ver">5.0.0</span></div></div></div>
<button class="new-btn" onclick="newConversation()"><span>+</span><span>New chat</span></button>
</div>
<div class="convs" id="convs"></div>
<div class="sidebar-foot">
<button class="provider-btn" onclick="openProviderPicker()">
<span class="dot" id="provider-dot"></span>
<span class="provider-name" id="provider-name">DeepSeek</span>
<span style="color:var(--mute);font-size:12px">⇄</span>
</button>
</div>
</aside>
<main class="main">
<header class="header">
<button class="menu-btn" onclick="toggleSidebar()">☰</button>
<button class="collapse-btn" id="collapse-btn" onclick="toggleSidebarCollapse()" title="Hide sidebar">◀</button>
<button class="model-sel" onclick="openModelPicker()">
<span id="model-name">deepseek-chat</span><span class="chev">▾</span>
</button>
<div class="spacer"></div>
<button class="mode-toggle" id="mode-toggle" onclick="toggleAgent()">
<span class="mode-dot"></span><span id="mode-text">Chat</span>
</button>
<button class="icon-btn" onclick="newConversation()" title="New chat">⊕</button>
</header>
<div class="chat" id="chat">
<div class="welcome" id="welcome">
<div class="welcome-icon">◆</div>
<h1>AyhanX-Agent</h1>
<p>Premium AI chat · 24 providers · full terminal access</p>
<div class="suggestions">
<button class="sug" onclick="suggest('Write a Python script that finds duplicate files and run it')">📝 Write & run a duplicate finder</button>
<button class="sug" onclick="suggest('List my home directory and tell me what is here')">📁 Explore my home directory</button>
<button class="sug" onclick="suggest('Create a FastAPI server in a folder called api and run it')">🚀 Build a FastAPI server</button>
<button class="sug" onclick="suggest('Explain quantum computing in simple terms')">💡 Explain quantum computing</button>
</div></div></div>
<div class="composer-wrap"><div class="composer"><div class="composer-inner">
<textarea id="input" placeholder="Message AyhanX-Agent..." rows="1"
onkeydown="handleKey(event)" oninput="autoResize(this)"></textarea>
<button class="send-btn" id="send-btn" onclick="sendMessage()" disabled>↑</button>
</div></div>
<div class="composer-hint"><span>Enter to send · Shift+Enter for newline</span><span id="status">Ready</span></div>
</div></main></div>
<div class="modal" id="modal" onclick="closeModal(event)">
<div class="modal-content" onclick="event.stopPropagation()">
<div class="modal-head"><div class="modal-title" id="modal-title">Select</div>
<button class="modal-close" onclick="closeModal()">×</button></div>
<div class="modal-body" id="modal-body"></div></div></div>
<div class="toast" id="toast"></div>
<script>
const state = {provider:"deepseek", model:"deepseek-chat", agent:false, convId:null,
                messages:[], streaming:false, config:{}};
const SIDEBAR_KEY = 'ayhanx_sidebar_collapsed';
const $ = s => document.querySelector(s);
const input = $('#input'), sendBtn = $('#send-btn'), chat = $('#chat'),
      status = $('#status'), welcome = $('#welcome');

function toggleSidebarCollapse(){
  const sb = $('#sidebar');
  const isCollapsed = sb.classList.toggle('collapsed');
  document.body.classList.toggle('collapsed', isCollapsed);
  $('#collapse-btn').title = isCollapsed ? 'Show sidebar' : 'Hide sidebar';
  try { localStorage.setItem(SIDEBAR_KEY, isCollapsed ? '1' : '0'); } catch(_){}
}

function restoreSidebar(){
  try {
    if (localStorage.getItem(SIDEBAR_KEY) === '1'){
      $('#sidebar').classList.add('collapsed');
      document.body.classList.add('collapsed');
      $('#collapse-btn').title = 'Show sidebar';
    }
  } catch(_){}
}

function toggleSidebar(){ $('#sidebar').classList.toggle('open'); }

function escapeHtml(s){return s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function md(text){
  if(!text) return '';
  let s = escapeHtml(text);
  s = s.replace(/```(\w*)\n?([\s\S]*?)```/g,(m,lang,code)=>`<pre><code>${code}</code></pre>`);
  s = s.replace(/`([^`]+)`/g,'<code>$1</code>');
  s = s.replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>');
  s = s.replace(/\*([^*]+)\*/g,'<em>$1</em>');
  s = s.replace(/^### (.+)$/gm,'<h3>$1</h3>');
  s = s.replace(/^## (.+)$/gm,'<h2>$1</h2>');
  s = s.replace(/^# (.+)$/gm,'<h1>$1</h1>');
  s = s.replace(/^- (.+)$/gm,'<li>$1</li>');
  s = s.replace(/(<li>.*<\/li>\n?)+/g,m=>`<ul>${m}</ul>`);
  s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g,'<a href="$2" target="_blank">$1</a>');
  s = s.replace(/^&gt; (.+)$/gm,'<blockquote>$1</blockquote>');
  s = s.split('\n\n').map(p=>p.trim()).filter(Boolean).map(p=>{
    if(/^<(h[1-6]|ul|ol|pre|blockquote|li)/.test(p)) return p;
    return `<p>${p.replace(/\n/g,'<br>')}</p>`;
  }).join('');
  return s;
}

async function api(path, opts={}){
  const r = await fetch(path, {headers:{'Content-Type':'application/json'}, ...opts});
  if(!r.ok) throw new Error(await r.text());
  return r.json();
}

async function loadConfig(){
  const c = await api('/api/config');
  state.config = c; state.provider = c.provider; state.model = c.model; state.agent = c.agent_mode;
  $('#ver').textContent = c.version;
  $('#provider-name').textContent = c.provider_label;
  $('#provider-dot').className = 'dot ' + (c.is_local ? 'local' : c.provider);
  $('#model-name').textContent = c.model;
  updateModeBtn();
}

function updateModeBtn(){
  const b = $('#mode-toggle');
  b.classList.toggle('agent', state.agent);
  $('#mode-text').textContent = state.agent ? 'Agent' : 'Chat';
}

async function loadConversations(){
  const list = await api('/api/conversations');
  const el = $('#convs');
  if(!list.length){
    el.innerHTML = '<div class="empty-state"><div class="icon">💬</div>No conversations yet</div>';
    return;
  }
  el.innerHTML = list.map(c => `
    <div class="conv-item ${c.id===state.convId?'active':''}" data-id="${c.id}">
      <span class="title">${escapeHtml(c.id)}</span>
      <button class="del" onclick="event.stopPropagation();delConv('${c.id}')" title="Delete">×</button>
    </div>`).join('');
  el.querySelectorAll('.conv-item').forEach(item => {
    item.onclick = () => loadConversation(item.dataset.id);
  });
}

async function loadConversation(id){
  const data = await api(`/api/conversations/${id}`);
  state.convId = id; state.messages = data.messages;
  hideWelcome(); chat.innerHTML = '';
  for(const m of data.messages){
    if(m.role === 'user') addMessage('user', m.content);
    else if(m.role === 'assistant') addMessage('ai', m.content);
  }
  await loadConversations();
  scrollDown();
}

async function delConv(id){
  await api(`/api/conversations/${id}`, {method:'DELETE'});
  if(state.convId === id) newConversation();
  await loadConversations();
}

function hideWelcome(){ if(welcome) welcome.style.display = 'none'; }
function scrollDown(){ chat.scrollTop = chat.scrollHeight; }

function addMessage(role, content){
  hideWelcome();
  const el = document.createElement('div');
  el.className = `message msg-${role}`;
  if(role === 'user'){
    el.innerHTML = `<div class="msg-body">${escapeHtml(content)}</div>`;
  } else {
    el.innerHTML = `<div class="msg-body"><div class="msg-role">Assistant</div><div class="md"></div></div>`;
    el.querySelector('.md').innerHTML = md(content);
  }
  chat.appendChild(el);
  scrollDown();
  return el;
}

function showToast(msg, isErr){
  const t = $('#toast');
  t.textContent = msg;
  t.className = 'toast show' + (isErr ? ' err' : '');
  clearTimeout(t._timer);
  t._timer = setTimeout(() => t.className = 'toast', 2500);
}

function setStatus(s){ status.textContent = s; }
function suggest(text){ input.value = text; autoResize(input); sendMessage(); }

function autoResize(el){
  el.style.height = 'auto';
  el.style.height = Math.min(el.scrollHeight, 200) + 'px';
  sendBtn.disabled = !el.value.trim() || state.streaming;
}

function handleKey(e){
  if(e.key === 'Enter' && !e.shiftKey){ e.preventDefault(); sendMessage(); }
}

async function sendMessage(){
  const text = input.value.trim();
  if(!text || state.streaming) return;
  input.value = ''; autoResize(input);
  addMessage('user', text);
  state.messages.push({role:'user', content:text});
  state.streaming = true; sendBtn.disabled = true; setStatus('Thinking…');

  const aiEl = addMessage('ai', '');
  const mdEl = aiEl.querySelector('.md');
  let answer = '';
  let toolCards = [];

  try {
    const r = await fetch('/api/chat', {
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({conversation_id: state.convId, message: text, agent: state.agent})
    });
    if(!r.ok) throw new Error('HTTP ' + r.status);
    const reader = r.body.getReader();
    const decoder = new TextDecoder();
    let buf = '';
    setStatus('Streaming…');

    while(true){
      const {done, value} = await reader.read();
      if(done) break;
      buf += decoder.decode(value, {stream:true});
      let idx;
      while((idx = buf.indexOf('\n\n')) >= 0){
        const chunk = buf.slice(0, idx); buf = buf.slice(idx + 2);
        for(const line of chunk.split('\n')){
          if(!line.startsWith('data: ')) continue;
          try {
            const obj = JSON.parse(line.slice(6));
            if(obj.type === 'start'){ state.convId = obj.conversation_id; }
            else if(obj.type === 'delta'){
              answer += obj.text;
              mdEl.innerHTML = md(answer) + '<span class="cursor"></span>';
              scrollDown();
            }
            else if(obj.type === 'tool'){
              const container = document.createElement('div');
              container.className = 'tool-cards';
              const card = document.createElement('div');
              card.className = 'tool-card';
              card.innerHTML = `<div><span class="tool-name">⚙ ${obj.name}</span><span class="tool-args">${escapeHtml(JSON.stringify(obj.args).slice(0,100))}</span></div><div class="tool-result">running...</div>`;
              container.appendChild(card);
              aiEl.querySelector('.msg-body').appendChild(container);
              toolCards.push({card});
              scrollDown();
            }
            else if(obj.type === 'tool_result'){
              if(toolCards.length){
                const resultDiv = toolCards[toolCards.length-1].card.querySelector('.tool-result');
                if(resultDiv) resultDiv.textContent = String(obj.text).slice(0, 500);
              }
            }
            else if(obj.type === 'error'){
              mdEl.innerHTML = `<div class="msg-err">${escapeHtml(obj.message)}</div>`;
              setStatus('Error');
            }
            else if(obj.type === 'done'){
              mdEl.innerHTML = md(answer);
              setStatus('Ready');
            }
          } catch(_){}
        }
      }
    }

    if(answer) state.messages.push({role:'assistant', content:answer});
    await loadConversations();
  } catch(e){
    mdEl.innerHTML = `<div class="msg-err">⚠ ${escapeHtml(e.message)}</div>`;
    setStatus('Error');
  } finally {
    state.streaming = false;
    sendBtn.disabled = !input.value.trim();
    setStatus('Ready');
    input.focus();
  }
}

function openModal(title, bodyHtml, onSelect){
  $('#modal-title').textContent = title;
  const body = $('#modal-body');
  body.innerHTML = bodyHtml;
  body.querySelectorAll('[data-value]').forEach(el => {
    el.onclick = () => { onSelect(el.dataset.value); closeModal(); };
  });
  $('#modal').classList.add('open');
}

function closeModal(e){
  if(e && e.target !== $('#modal') && !e.target.classList.contains('modal-close')) return;
  $('#modal').classList.remove('open');
}

async function openProviderPicker(){
  const list = await api('/api/providers');
  const html = list.map(p => `
    <div class="modal-opt ${p.active ? 'active' : ''}" data-value="${p.name}">
      <span class="dot ${p.local ? 'local' : p.name}"></span>
      <div style="flex:1"><div class="opt-main">${p.label}</div><div class="opt-sub">${p.model}</div></div>
      ${p.active ? '<span style="color:var(--accent);font-size:16px">✓</span>' : ''}
    </div>`).join('');
  openModal('Switch provider', html, async (name) => {
    try {
      await api('/api/switch', {method:'POST', body: JSON.stringify({provider:name})});
      await loadConfig();
      showToast('Switched to ' + name);
    } catch(e){ showToast('Failed: ' + e.message, true); }
  });
}

async function openModelPicker(){
  const data = await api('/api/models');
  if(!data.models.length){ showToast('No models available', true); return; }
  const html = data.models.map(m => `
    <div class="modal-opt ${m === data.current ? 'active' : ''}" data-value="${m}">
      <div style="flex:1"><div class="opt-main">${escapeHtml(m)}</div></div>
      ${m === data.current ? '<span style="color:var(--accent);font-size:16px">✓</span>' : ''}
    </div>`).join('');
  openModal('Select model', html, async (model) => {
    try {
      await api('/api/model', {method:'POST', body: JSON.stringify({model})});
      state.model = model;
      $('#model-name').textContent = model;
      showToast('Model → ' + model);
    } catch(e){ showToast('Failed: ' + e.message, true); }
  });
}

async function toggleAgent(){
  state.agent = !state.agent;
  try {
    await api('/api/agent', {method:'POST', body: JSON.stringify({enabled: state.agent})});
    updateModeBtn();
    showToast(state.agent ? 'Agent mode ON — full terminal access' : 'Agent mode OFF');
  } catch(e){ showToast('Failed: ' + e.message, true); }
}

function newConversation(){
  state.convId = null; state.messages = []; chat.innerHTML = '';
  if(welcome){ chat.appendChild(welcome); welcome.style.display = ''; }
  loadConversations(); input.focus();
}

(async function init(){
  await loadConfig();
  await loadConversations();
  restoreSidebar();
  input.focus();
  setStatus('Ready');
})();
</script></body></html>"""

@app.get("/", response_class=HTMLResponse)
def index(): return HTML

@app.get("/health")
def health(): return {"ok": True, "version": VERSION}

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", "8080"))
    host = os.environ.get("HOST", "0.0.0.0")

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.bind((host, port)); s.close()
    except OSError:
        s.close()
        new_port = find_free_port(port, port + 120)
        if new_port:
            print(f"  ! port {port} busy — using {new_port} instead")
            port = new_port
        else:
            print(f"  ✘ no free port found in {port}-{port+120}")
            import sys; sys.exit(1)

    print(f"\n  ◆ AyhanX-Agent web UI")
    print(f"  → http://localhost:{port}\n")
    uvicorn.run(app, host=host, port=port, log_level="warning")
'@
    [System.IO.File]::WriteAllText((Join-Path $RUNNER_DIR "server.py"), $c,
        (New-Object System.Text.UTF8Encoding($false)))
}

# ============================================================================
#  COMMANDS
# ============================================================================
function Start-Tui {
    Push-Location $APP_DIR
    try { $env:PYTHONPATH = $APP_DIR; & $VENV_PY -m runner.tui }
    finally { Pop-Location }
}

function Start-Web {
    param([int]$Port = 8080)
    Write-Section "Starting web UI on :$Port"
    Write-Host "  → http://localhost:$Port" -ForegroundColor Cyan
    Write-Host "  Ctrl+C to stop" -ForegroundColor DarkGray
    Write-Host ""
    Push-Location $APP_DIR
    try {
        $env:PORT = "$Port"
        $env:PYTHONPATH = $APP_DIR
        & $VENV_PY -m runner.server
    } finally { Pop-Location }
}

function Invoke-ChatLoop {
    $next = "new"
    while ($true) {
        Clear-Host
        Write-Logo
        Write-Tagline
        $env:AYHANX_START = $next
        Start-Tui
        Write-Host ""
        Write-Rule
        Write-Host "  ◆ " -ForegroundColor Cyan -NoNewline
        Write-Host "What next?" -ForegroundColor White -NoNewline
        Write-Host "   " -NoNewline
        Write-Host "[r]" -ForegroundColor Cyan -NoNewline
        Write-Host " resume   " -NoNewline
        Write-Host "[n]" -ForegroundColor Cyan -NoNewline
        Write-Host " new   " -NoNewline
        Write-Host "[w]" -ForegroundColor Cyan -NoNewline
        Write-Host " web UI   " -NoNewline
        Write-Host "[q]" -ForegroundColor Cyan -NoNewline
        Write-Host " quit" -NoNewline
        Write-Host ""
        $key = [Console]::ReadKey($true).KeyChar
        if ($key -in @("q","Q")) { return }
        elseif ($key -in @("r","R")) { $next = "resume" }
        elseif ($key -in @("w","W")) { Start-Web 8080 }
        else { $next = "new" }
    }
}

function Invoke-Ask {
    param([string]$Prompt)
    if (-not $Prompt) { Write-Err "empty prompt"; exit 1 }
    $s = @'
import os, sys
import httpx
p = sys.argv[1]
provider = os.environ.get("AYHANX_PROVIDER", "deepseek")
base = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com").rstrip("/")
h = {"Authorization": f"Bearer {os.environ.get('DEEPSEEK_API_KEY', 'local')}", "Content-Type": "application/json"}
if provider == "openrouter":
    h["HTTP-Referer"] = "https://github.com/AyhanMansur/AyhanX-Agent"
    h["X-Title"] = "AyhanX-Agent"
r = httpx.post(f"{base}/chat/completions", headers=h,
               json={"model": os.environ.get("DEEPSEEK_MODEL", "deepseek-chat"),
                     "messages": [{"role": "user", "content": p}]}, timeout=120)
if r.status_code >= 400:
    try: msg = r.json().get("error", {}).get("message", r.text)
    except Exception: msg = r.text
    print(f"HTTP {r.status_code}: {msg}", file=sys.stderr); sys.exit(1)
print(r.json()["choices"][0]["message"]["content"])
'@
    $s | & $VENV_PY - $Prompt
}

function Invoke-Health {
    Write-Section "Connection check"
    $s = @'
import os
import httpx
provider = os.environ.get("AYHANX_PROVIDER", "deepseek")
base = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com").rstrip("/")
model = os.environ.get("DEEPSEEK_MODEL", "deepseek-chat")
h = {"Authorization": f"Bearer {os.environ.get('DEEPSEEK_API_KEY', 'local')}", "Content-Type": "application/json"}
if provider == "openrouter":
    h["HTTP-Referer"] = "https://github.com/AyhanMansur/AyhanX-Agent"
    h["X-Title"] = "AyhanX-Agent"
G, R, M, N = "\033[38;5;84m", "\033[38;5;203m", "\033[38;5;245m", "\033[0m"
print(f"  {M}provider{N}  {provider}")
print(f"  {M}endpoint{N}  {base}")
print(f"  {M}model{N}     {model}")
try:
    r = httpx.post(f"{base}/chat/completions", headers=h, timeout=30,
                   json={"model": model, "max_tokens": 5, "messages": [{"role": "user", "content": "say OK"}]})
    print(f"  {M}status{N}    {r.status_code}")
    j = r.json()
    if "choices" in j:
        print(f"  {M}reply{N}     {j['choices'][0]['message']['content']!r}")
        print(f"  {G}✔ connected{N}")
    else:
        print(f"  {M}body{N}      {r.text[:300]}")
        print(f"  {R}✘ failed{N}")
except Exception as e:
    print(f"  {R}✘ {type(e).__name__}: {e}{N}")
'@
    $s | & $VENV_PY -
}

function Invoke-Config {
    Write-Section "Files"
    Write-Info "provider $($env:AYHANX_PROVIDER)"
    Write-Info "config   $CONFIG_FILE"
    Write-Info "env      $ENV_FILE"
    Write-Info "providers $PROVIDERS_FILE"
    Write-Info "chats    $CHATS_DIR"
    Write-Info "design   $DESIGN_FILE"
    Write-Host ""
    if (Test-Path $PROVIDERS_FILE) {
        Write-Section "Providers"
        Get-Content $PROVIDERS_FILE
        Write-Host ""
    }
    if (Test-Path $CONFIG_FILE) {
        Write-Section "Config"
        Get-Content $CONFIG_FILE
        Write-Host ""
    }
}

function Invoke-Version {
    Write-Section "Version"
    Write-Info "AyhanX-Agent  $VERSION"
    Write-Info "repo       $REPO_URL"
    Write-Info "provider   $($env:AYHANX_PROVIDER)"
    Write-Info "app dir    $APP_DIR"
    if (Test-Path $VENV_PY) {
        $v = & $VENV_PY --version 2>&1
        Write-Info "python     $v"
    }
}

function Invoke-Switch {
    param([string]$Name)
    if (-not $Name) {
        Write-Err "usage: .\ai.ps1 switch <provider>"
        if (Test-Path $PROVIDERS_FILE) {
            (Get-Content $PROVIDERS_FILE | ConvertFrom-Json).PSObject.Properties.Name | ForEach-Object {
                Write-Info "  · $_"
            }
        }
        exit 1
    }
    if (Test-Path $PROVIDERS_FILE) {
        $data = Get-Content $PROVIDERS_FILE -Raw | ConvertFrom-Json
        if (-not $data.PSObject.Properties.Name.Contains($Name)) {
            Write-Err "unknown provider: $Name"
            Write-Info "available: $($data.PSObject.Properties.Name -join ', ')"
            exit 1
        }
        $Name | Out-File -FilePath $PROVIDER_FILE -Encoding UTF8 -NoNewline
        Write-Ok "→ switched to $Name"
        Write-Info "  model    $($data.$Name.model)"
        Write-Info "  endpoint $($data.$Name.url)"
    } else {
        $Name | Out-File -FilePath $PROVIDER_FILE -Encoding UTF8 -NoNewline
        Write-Ok "provider → $Name"
    }
}

# ============================================================================
#  MAIN
# ============================================================================
function Main {
    New-Item -ItemType Directory -Force -Path $APP_DIR | Out-Null

    switch ($Command.ToLower()) {
        "ask" {
            Initialize-Environment
            Initialize-Credentials
            Invoke-Ask ($Rest -join " ")
        }
        "health" {
            Initialize-Environment
            Initialize-Credentials
            Invoke-Health
        }
        "config"  { Invoke-Config }
        "version" { Invoke-Version }
        "switch" {
            Initialize-Environment
            Initialize-Credentials
            Invoke-Switch ($Rest | Select-Object -First 1)
        }
        "web" {
            $portArg = $Rest | Select-Object -First 1
            $port = if ($portArg) { [int]$portArg } else { 8080 }
            Initialize-Environment
            Initialize-Credentials
            Write-Section "Preparing web UI"
            Write-Tools
            Write-Tui
            Write-Server
            Write-Ok "runner ready"
            Start-Sleep -Milliseconds 200
            Start-Web $port
        }
        { $_ -in @("chat", "tui", "") } {
            Initialize-Environment
            Initialize-Credentials
            Write-Section "Starting"
            Write-Tools
            Write-Tui
            Write-Server
            Write-Ok "runner ready"
            Start-Sleep -Milliseconds 200
            Invoke-ChatLoop
            Write-Outro
        }
        default {
            Write-Err "unknown mode: $Command"
            Write-Info "usage: .\ai.ps1 [chat|web|ask|health|config|version|switch] [-Provider NAME]"
            exit 1
        }
    }
}

Main
