# ============================================================================
#   AyhanX-Agent · Windows PowerShell client for DeepSeek, OpenRouter & local
#   Repository:  https://github.com/AyhanMansur/AyhanX-Agent
#   Version:     3.4.2-windows
# ============================================================================
$ErrorActionPreference = "Stop"

# ---- argument parsing (no param() — works with `| iex`) ----
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
    elseif ($a -in @("ask","health","config","version","chat","tui")) {
        $Command = $a
    }
    else {
        $Rest += $a
    }
    $i++
}

$VERSION      = "3.4.2-windows"
$REPO_URL     = "https://github.com/AyhanMansur/AyhanX-Agent"
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

$env:AI_RUNNER_VERSION = $VERSION
if ($Provider) { $env:AYHANX_PROVIDER = $Provider }

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }
$E = [char]27

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
'            ░███████                                                                  ░███████                                  '
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
#  PROVIDER HELPERS
# ============================================================================
function Get-ProviderLabel {
    param([string]$p)
    switch ($p) {
        "openrouter" { return "OpenRouter" }
        "groq"       { return "Groq" }
        "ollama"     { return "Ollama" }
        "lmstudio"   { return "LM Studio" }
        "vllm"       { return "vLLM" }
        "llamacpp"   { return "llama.cpp" }
        "localai"    { return "LocalAI" }
        default      { return "DeepSeek" }
    }
}

function Test-LocalProvider {
    param([string]$p)
    return $p -in @("ollama", "lmstudio", "vllm", "llamacpp", "localai")
}

function Get-ProviderUrl {
    param([string]$p)
    switch ($p) {
        "openrouter" { return "https://openrouter.ai/api/v1" }
        "groq"       { return "https://api.groq.com/openai/v1" }
        "ollama"     { if ($env:OLLAMA_URL)   { return $env:OLLAMA_URL   } else { return "http://localhost:11434/v1" } }
        "lmstudio"   { if ($env:LMSTUDIO_URL) { return $env:LMSTUDIO_URL } else { return "http://localhost:1234/v1" } }
        "vllm"       { if ($env:VLLM_URL)     { return $env:VLLM_URL     } else { return "http://localhost:8000/v1" } }
        "llamacpp"   { if ($env:LLAMACPP_URL) { return $env:LLAMACPP_URL } else { return "http://localhost:8080/v1" } }
        "localai"    { if ($env:LOCALAI_URL)  { return $env:LOCALAI_URL  } else { return "http://localhost:8080/v1" } }
        default      { return "https://api.deepseek.com" }
    }
}

function Get-DefaultModel {
    param([string]$p)
    switch ($p) {
        "openrouter" { return "deepseek/deepseek-chat" }
        "groq"       { return "llama-3.3-70b-versatile" }
        "ollama"     { return "qwen2.5:3b" }
        "lmstudio"   { return "local-model" }
        "vllm"       { return "local-model" }
        "llamacpp"   { return "local-model" }
        "localai"    { return "local-model" }
        default      { return "deepseek-chat" }
    }
}

function Get-ProviderFromKey {
    param([string]$key)
    if (-not $key) { return "" }
    if ($key -like "sk-or-*") { return "openrouter" }
    if ($key -like "gsk_*")   { return "groq" }
    if ($key -like "sk-*")    { return "deepseek" }
    return ""
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
            & $VENV_PY -c "import httpx,rich,prompt_toolkit" 2>&1 | Out-Null
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
                --timeout 20 --retries 3 httpx rich prompt_toolkit pyreadline3
        }
        if (-not $installed) { Write-Err "package install failed — see $LOG_FILE"; exit 1 }
    } else {
        Write-Ok "runtime ready"
    }
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
        if     ($u -match "openrouter") { $prov = "openrouter" }
        elseif ($u -match "groq")       { $prov = "groq" }
        elseif ($u -match ":11434")     { $prov = "ollama" }
        elseif ($u -match ":1234")      { $prov = "lmstudio" }
        elseif ($u -match ":8000")      { $prov = "vllm" }
        elseif ($u -match ":8080")      { $prov = "llamacpp" }
        elseif ($u -match "deepseek")   { $prov = "deepseek" }
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
    if (-not $env:DEEPSEEK_MODEL)    { $env:DEEPSEEK_MODEL    = Get-DefaultModel $prov }

    Write-Ok "provider → $(Get-ProviderLabel $prov)"
    Write-Info "endpoint → $env:DEEPSEEK_BASE_URL"
    Write-Info "model    → $env:DEEPSEEK_MODEL"
}

# ============================================================================
#  WRITE RUNNER FILES
# ============================================================================
function Write-Tools {
    $c = @'
"""Tool definitions and implementations for AyhanX-Agent agent mode."""
import json, subprocess
from datetime import datetime, timezone
from pathlib import Path

TOOL_SPECS = [
    {"type":"function","function":{"name":"get_current_time","description":"Get the current UTC date and time in ISO 8601 format.","parameters":{"type":"object","properties":{}}}},
    {"type":"function","function":{"name":"calculate","description":"Evaluate a simple arithmetic expression.","parameters":{"type":"object","properties":{"expression":{"type":"string","description":"Math expression"}},"required":["expression"]}}},
    {"type":"function","function":{"name":"list_directory","description":"List files in a directory under the user's home.","parameters":{"type":"object","properties":{"path":{"type":"string"}}}}},
    {"type":"function","function":{"name":"read_file","description":"Read a text file under the user's home (10 KB limit).","parameters":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}}},
    {"type":"function","function":{"name":"run_shell","description":"Run a safe shell command and return its output.","parameters":{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}}},
]

def _safe_resolve(p):
    base = Path.home()
    t = (base / p).expanduser().resolve()
    if t != base and base not in t.parents: raise ValueError(f"path escapes home: {p}")
    return t

def _err(m): return json.dumps({"error": m})

def tool_get_current_time(_a): return datetime.now(timezone.utc).isoformat()

def tool_calculate(a):
    e = a.get("expression","").strip()
    if not e: return _err("empty expression")
    if any(ch not in "0123456789+-*/(). " for ch in e): return _err(f"disallowed char in {e!r}")
    try: return str(eval(e, {"__builtins__":{}}, {}))
    except Exception as ex: return _err(f"failed: {ex}")

def tool_list_directory(a):
    rel = a.get("path","").strip()
    try: t = _safe_resolve(rel) if rel else Path.home()
    except ValueError as e: return _err(str(e))
    if not t.exists(): return _err(f"path not found: {t}")
    if not t.is_dir(): return _err(f"not a directory: {t}")
    try: items = sorted(t.iterdir())
    except PermissionError: return _err("permission denied")
    return json.dumps([(p.name + ("/" if p.is_dir() else "")) for p in items[:200]])

def tool_read_file(a):
    rel = a.get("path","").strip()
    if not rel: return _err("path required")
    try: t = _safe_resolve(rel)
    except ValueError as e: return _err(str(e))
    if not t.exists(): return _err(f"file not found: {t}")
    if not t.is_file(): return _err(f"not a file: {t}")
    try: data = t.read_text(encoding="utf-8", errors="replace")
    except PermissionError: return _err("permission denied")
    if len(data) > 10*1024: data = data[:10*1024] + "\n... [truncated]"
    return data

def tool_run_shell(a):
    cmd = a.get("command","").strip()
    if not cmd: return _err("command required")
    for b in ("rm -rf /","mkfs",":(){","dd if=/dev/zero","del /f /s /q c:\\"):
        if b in cmd: return _err("refused: destructive command")
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=15, cwd=str(Path.home()))
        out = r.stdout
        if r.returncode != 0: out += f"\n[exit code: {r.returncode}]"
        if r.stderr: out += f"\n[stderr]: {r.stderr[:500]}"
        return out[:5000] or "(no output)"
    except subprocess.TimeoutExpired: return _err("timed out (15s)")
    except Exception as e: return _err(f"{type(e).__name__}: {e}")

TOOL_IMPLS = {
    "get_current_time": tool_get_current_time, "calculate": tool_calculate,
    "list_directory": tool_list_directory, "read_file": tool_read_file,
    "run_shell": tool_run_shell,
}
'@
    [System.IO.File]::WriteAllText((Join-Path $RUNNER_DIR "tools.py"), $c,
        (New-Object System.Text.UTF8Encoding($false)))
}

function Write-Tui {
    $c = @'
"""AyhanX-Agent — premium terminal chat for Windows."""
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

VERSION = os.environ.get("AI_RUNNER_VERSION", "3.4.2-windows")
APP_DIR = Path(os.environ.get("APP_DIR", Path.home() / ".ai_platform"))
CONFIG_PATH = APP_DIR / "config.json"
HISTORY_PATH = APP_DIR / "history.txt"
CHATS_DIR = APP_DIR / "chats"
CHATS_DIR.mkdir(parents=True, exist_ok=True)

PROVIDER = os.environ.get("AYHANX_PROVIDER", "deepseek")
PROVIDER_LABEL = {"deepseek":"DeepSeek","openrouter":"OpenRouter","groq":"Groq","ollama":"Ollama","lmstudio":"LM Studio","vllm":"vLLM","llamacpp":"llama.cpp","localai":"LocalAI"}.get(PROVIDER, PROVIDER)
LOCAL_PROVIDERS = {"ollama","lmstudio","vllm","llamacpp","localai"}
IS_LOCAL = PROVIDER in LOCAL_PROVIDERS

PROVIDER_MODELS = {
    "deepseek": ["deepseek-chat","deepseek-reasoner"],
    "openrouter": ["deepseek/deepseek-chat","deepseek/deepseek-chat-v3-0324:free","deepseek/deepseek-r1:free","meta-llama/llama-3.3-70b-instruct:free","google/gemini-2.0-flash-exp:free","qwen/qwen-2.5-72b-instruct:free"],
    "groq": ["llama-3.3-70b-versatile","llama-3.1-8b-instant","mixtral-8x7b-32768","gemma2-9b-it"],
    "ollama": [], "lmstudio": [], "vllm": [], "llamacpp": [], "localai": [],
}
MODELS = PROVIDER_MODELS.get(PROVIDER, PROVIDER_MODELS["deepseek"])
START = os.environ.get("AYHANX_START", "new")

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
    ids = fetch_server_models(os.environ.get("DEEPSEEK_BASE_URL",""), os.environ.get("DEEPSEEK_API_KEY","local"))
    if ids:
        for m in ids:
            if m not in cfg.custom_models and m not in MODELS: cfg.custom_models.append(m)
        cfg.save()
        if cfg.model not in ids: cfg.model = ids[0]; cfg.save()
    return ids

def all_models(cfg): return MODELS + [m for m in cfg.custom_models if m not in MODELS]

def save_last(conv):
    if conv.messages: (CHATS_DIR / "last.json").write_text(json.dumps(conv.messages, indent=2))

VIOLET="#40e0d0"; VIOLET_DEEP="#0f9d9a"; CYAN="#5eead4"; GOLD="#fbbf24"
MINT="#34d399"; RED="#f87171"; MUTED="#64748b"; SOFT="#94a3b8"; TEXT="#e2e8f0"
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
                return cls(**{k:v for k,v in d.items() if k in cls.__annotations__})
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
    def add_user(self, t): self.messages.append({"role":"user","content":t})
    def add_assistant(self, t): self.messages.append({"role":"assistant","content":t})
    def trim(self, n):
        s = [m for m in self.messages if m["role"]=="system"]
        d = [m for m in self.messages if m["role"]!="system"]
        if len(d) > n: d = d[-n:]
        self.messages = s + d
    def save(self, name):
        p = CHATS_DIR / f"{name}.json"
        p.write_text(json.dumps(self.messages, indent=2)); return p
    @classmethod
    def load(cls, name):
        p = CHATS_DIR / f"{name}.json"
        if not p.exists(): raise FileNotFoundError(f"no saved chat named '{name}'")
        c = cls(); c.messages = json.loads(p.read_text()); return c
    def to_api(self): return [m for m in self.messages if m.get("content","").strip()]

class DeepSeekClient:
    def __init__(self, key, base, model, provider="deepseek"):
        self.api_key = key; self.base_url = base.rstrip("/"); self.model = model; self.provider = provider
    def _headers(self):
        h = {"Authorization": f"Bearer {self.api_key}", "Content-Type": "application/json"}
        if self.provider == "openrouter":
            h["HTTP-Referer"] = "https://github.com/AyhanMansur/AyhanX-Agent"
            h["X-Title"] = "AyhanX-Agent"
        return h
    def _hint(self, s):
        b = {401:"invalid API key",402:"insufficient balance",429:"rate limited"}.get(s,"")
        if not b: return ""
        if self.provider == "openrouter": return b + " — openrouter.ai/keys"
        if self.provider in LOCAL_PROVIDERS: return b + " — is the local server running?"
        return b + " — platform.deepseek.com/api_keys"
    def _error(self, s, body):
        msg = body
        try: msg = json.loads(body).get("error",{}).get("message",body)
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
                with client.stream("POST", f"{self.base_url}/chat/completions", headers=self._headers(), json=payload) as r:
                    if r.status_code >= 400:
                        yield {"error": self._error(r.status_code, r.read().decode(errors="replace"))}; return
                    for line in r.iter_lines():
                        if not line.startswith("data:"): continue
                        d = line[5:].strip()
                        if d == "[DONE]": break
                        try: o = json.loads(d)
                        except json.JSONDecodeError: continue
                        delta = o.get("choices",[{}])[0].get("delta",{})
                        if c := delta.get("content"): yield {"text": c}
            finally: client.close()
        return gen()
    def _nonstream(self, client, payload):
        try:
            r = client.post(f"{self.base_url}/chat/completions", headers=self._headers(), json=payload)
            if r.status_code >= 400: return {"error": self._error(r.status_code, r.text)}
            return r.json()
        finally: client.close()

def _rgb(h): return tuple(int(h[i:i+2],16) for i in (1,3,5))

def gradient(text, s=VIOLET_DEEP, e=CYAN):
    a, b = _rgb(s), _rgb(e); out = Text(); n = max(len(text)-1,1)
    for i, ch in enumerate(text):
        k = i/n
        c = "#" + "".join(f"{round(a[j]+(b[j]-a[j])*k):02x}" for j in range(3))
        out.append(ch, style=f"bold {c}")
    return out

def model_chip(n): return Text(f" {n} ", style=f"bold #0f0a1f on {VIOLET}")
def mode_chip(a): return Text(" AGENT ", style=f"bold #1c1600 on {GOLD}") if a else Text(" CHAT ", style=f"bold #04221a on {MINT}")
def provider_chip():
    l = f" {PROVIDER_LABEL} "
    return Text(l, style="bold #1c1600 on #fbbf24") if IS_LOCAL else Text(l, style=f"bold #0a0f1c on {CYAN}")

def show_header(cfg):
    left = Text.assemble(("◆ ", VIOLET), gradient("AyhanX-Agent"), ("   ", ""), (f"v{VERSION}", MUTED))
    right = Text.assemble(provider_chip(), ("  ",""), model_chip(cfg.model), ("  ",""), mode_chip(cfg.agent_mode))
    g = Table.grid(expand=True); g.add_column(ratio=1); g.add_column(justify="right"); g.add_row(left, right)
    console.print(Panel(g, box=box.ROUNDED, border_style=VIOLET_DEEP, padding=(0,2)))
    console.print(Text("  type a message · /help for commands · Ctrl+D to exit", style=MUTED))
    console.print()

def notice(m, c=MINT): console.print(Text(f"  {m}", style=c))
def error_panel(m): return Panel(Text(m, style=RED), title=Text("error", style=f"bold {RED}"), title_align="left", box=box.ROUNDED, border_style=RED, padding=(0,2))

def assistant_panel(t, thinking=False):
    title = Text.assemble(("◆ ", VIOLET), (PROVIDER_LABEL, f"bold {VIOLET}"), ("  thinking…" if thinking else "", MUTED))
    return Panel(Markdown(t or ""), title=title, title_align="left", box=box.ROUNDED, border_style=VIOLET_DEEP, padding=(0,2))

def print_user(t):
    console.print()
    console.print(Text.assemble((" you ", f"bold #0f0a1f on {CYAN}"), ("  ",""), (t, TEXT)))
    console.print()

def tool_card(n, a, r):
    ag = json.dumps(a, ensure_ascii=False)[:90]
    pv = r[:140].replace("\n"," ")
    if len(r) > 140: pv += "…"
    console.print(Text.assemble(("  ⚙ ", GOLD), (n, f"bold {GOLD}"), ("  ",""), (ag, MUTED)))
    console.print(Text.assemble(("    └ ", "#334155"), (pv, SOFT)))

def help_panel():
    rows = [("/new","new conversation"),("/clear","clear screen"),("/model [name]","show/switch model"),("/model refresh","re-fetch (local only)"),("/model add <name>","add model"),("/system [text]","set/show system prompt"),("/agent","toggle agent mode"),("/save [name]","save conversation"),("/load <name>","load conversation"),("/chats","list saved chats"),("/history","print conversation"),("/info","show config"),("/exit","quit")]
    t = Table.grid(padding=(0,3)); t.add_column(style=f"bold {CYAN}", no_wrap=True); t.add_column(style=SOFT)
    for cmd, desc in rows: t.add_row(cmd, desc)
    keys = Text.assemble(("Enter", f"bold {TEXT}"),(" send    ", MUTED),("Esc+Enter", f"bold {TEXT}"),(" newline    ", MUTED),("↑ ↓", f"bold {TEXT}"),(" history    ", MUTED),("Ctrl+C", f"bold {TEXT}"),(" cancel", MUTED))
    console.print(Panel(Group(t, Text(""), keys), title=Text("commands", style=f"bold {VIOLET}"), title_align="left", box=box.ROUNDED, border_style=VIOLET_DEEP, padding=(1,2)))

def info_panel(cfg, conv):
    t = Table.grid(padding=(0,3)); t.add_column(style=f"bold {VIOLET}", no_wrap=True); t.add_column(style=TEXT)
    t.add_row("provider", PROVIDER_LABEL)
    t.add_row("endpoint", os.environ.get("DEEPSEEK_BASE_URL","?"))
    t.add_row("model", cfg.model); t.add_row("mode", "agent" if cfg.agent_mode else "chat")
    t.add_row("system prompt", "set" if cfg.system_prompt else "none")
    t.add_row("messages", str(len(conv.messages)))
    t.add_row("config", str(CONFIG_PATH)); t.add_row("chats", str(CHATS_DIR))
    console.print(Panel(t, title=Text("info", style=f"bold {VIOLET}"), title_align="left", box=box.ROUNDED, border_style=VIOLET_DEEP, padding=(1,2)))

def chats_table():
    chats = sorted(CHATS_DIR.glob("*.json"))
    if not chats: notice("no saved chats yet", MUTED); return
    t = Table(box=box.SIMPLE_HEAD, header_style=f"bold {VIOLET}", border_style=MUTED, expand=False)
    t.add_column("name", style=f"bold {CYAN}"); t.add_column("messages", justify="right"); t.add_column("updated", style=SOFT)
    for p in chats:
        try: n = str(len(json.loads(p.read_text())))
        except Exception: n = "?"
        t.add_row(p.stem, n, datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M"))
    console.print(t)

def print_history(conv):
    if not conv.messages: notice("nothing here yet", MUTED); return
    for m in conv.messages:
        if m["role"] == "user": console.print(Text.assemble(("❯ ", f"bold {CYAN}"), (m["content"], TEXT)))
        elif m["role"] == "assistant": console.print(Markdown(m["content"]))
        console.print()

KB = KeyBindings()
@KB.add("enter")
def _(e): e.current_buffer.validate_and_handle()
@KB.add("escape","enter")
def _(e): e.current_buffer.insert_text("\n")
@KB.add("c-j")
def _(e): e.current_buffer.insert_text("\n")

PROMPT_STYLE = Style.from_dict({"arrow": f"{VIOLET} bold","bottom-toolbar":"bg:#0b0a14 #94a3b8","completion-menu":"bg:#14122a #e2e8f0","completion-menu.completion.current":f"bg:{VIOLET_DEEP} #ffffff"})

def toolbar(cfg, conv):
    mode = '<style fg="#fbbf24"><b>AGENT</b></style>' if cfg.agent_mode else '<style fg="#34d399"><b>CHAT</b></style>'
    pf = "#fbbf24" if IS_LOCAL else "#5eead4"
    return HTML(f' <style fg="{pf}"><b>{html.escape(PROVIDER_LABEL)}</b></style>  ·  <style fg="#a78bfa"><b>{html.escape(cfg.model)}</b></style>  ·  {mode}  ·  {len(conv.messages)} msgs    <style fg="#64748b">/help · Enter send · Esc+Enter newline · Ctrl+D exit</style>')

def build_msgs(conv, cfg):
    m = conv.to_api()
    if cfg.system_prompt: m = [{"role":"system","content":cfg.system_prompt}] + m
    return m

def stream_response(client, conv, cfg):
    buf = []
    live = Live(Spinner("dots", text=Text(" thinking", style=MUTED), style=VIOLET), console=console, refresh_per_second=12, transient=False)
    live.start()
    try:
        for c in client.chat(build_msgs(conv, cfg), stream=True):
            if "error" in c: live.update(error_panel(c["error"])); live.stop(); return ""
            if "text" in c:
                buf.append(c["text"]); live.update(assistant_panel("".join(buf), thinking=True))
    except httpx.RequestError as e: live.update(error_panel(f"network error: {e}")); live.stop(); return ""
    except KeyboardInterrupt: live.update(assistant_panel("".join(buf) + "\n\n*cancelled*")); live.stop(); return "".join(buf)
    full = "".join(buf)
    if not full: live.update(Text("  (empty response)", style=MUTED)); live.stop(); return ""
    live.update(assistant_panel(full)); live.stop(); return full

def run_agent(client, conv, cfg):
    msgs = build_msgs(conv, cfg)
    for _ in range(8):
        with console.status(Text(" thinking", style=MUTED), spinner="dots", spinner_style=VIOLET):
            try: resp = client.chat(msgs, tools=TOOL_SPECS, stream=False)
            except httpx.RequestError as e: resp = {"error": f"network error: {e}"}
        if isinstance(resp, dict) and "error" in resp: console.print(error_panel(resp["error"])); return ""
        msg = resp.get("choices",[{}])[0].get("message",{})
        tcalls = msg.get("tool_calls") or []
        if not tcalls: content = msg.get("content") or ""; console.print(assistant_panel(content)); return content
        if msg.get("content"): console.print(Text(msg["content"], style=TEXT))
        msgs.append(msg)
        for tc in tcalls:
            fn = tc.get("function",{}); name = fn.get("name","?")
            try: a = json.loads(fn.get("arguments") or "{}")
            except json.JSONDecodeError: a = {}
            impl = TOOL_IMPLS.get(name)
            if impl:
                try: r = impl(a)
                except Exception as e: r = f"Error: {type(e).__name__}: {e}"
            else: r = f"Error: unknown tool '{name}'"
            tool_card(name, a, r)
            msgs.append({"role":"tool","tool_call_id":tc.get("id",""),"content":r})
    console.print(error_panel("stopped after 8 tool steps")); return ""

COMMANDS = ["/help","/new","/clear","/model","/system","/agent","/save","/load","/chats","/history","/info","/exit"]

def main():
    key = os.environ.get("DEEPSEEK_API_KEY", "local" if IS_LOCAL else "")
    if not key and not IS_LOCAL: console.print(error_panel("DEEPSEEK_API_KEY is not set")); return 1
    base = os.environ.get("DEEPSEEK_BASE_URL","https://api.deepseek.com")
    cfg = Config.load()
    if os.environ.get("DEEPSEEK_MODEL"): cfg.model = os.environ["DEEPSEEK_MODEL"]
    elif cfg.model not in MODELS and cfg.model not in cfg.custom_models:
        cfg.model = MODELS[0] if MODELS else "local-model"
    if IS_LOCAL:
        with console.status(Text(f" querying {PROVIDER_LABEL}…", style=MUTED), spinner="dots", spinner_style=VIOLET):
            ids = refresh_local_models(cfg)
        if not ids:
            notice(f"could not reach {PROVIDER_LABEL} at {base}", RED)
            notice("is it running? use /model refresh", MUTED)
        elif cfg.model not in ids: cfg.model = ids[0]; cfg.save()
    conv = Conversation(); show_header(cfg)
    if START == "resume" and (CHATS_DIR / "last.json").exists():
        conv = Conversation.load("last"); notice(f"resumed last chat · {len(conv.messages)} messages"); console.print()
    session = PromptSession(key_bindings=KB, style=PROMPT_STYLE, history=FileHistory(str(HISTORY_PATH)), completer=WordCompleter(COMMANDS, ignore_case=True), complete_while_typing=True, bottom_toolbar=lambda: toolbar(cfg, conv))
    while True:
        try: raw = session.prompt(HTML("<arrow>❯ </arrow>"))
        except KeyboardInterrupt: console.print(Text("  ^C", style=MUTED)); continue
        except EOFError: save_last(conv); console.print(); notice("bye", MUTED); return 0
        text = raw.strip()
        if not text: continue
        if text.startswith("/"):
            parts = text.split(maxsplit=1); cmd = parts[0].lower()
            args = parts[1].split() if len(parts) > 1 else []
            if cmd in ("/exit","/quit"): save_last(conv); notice("bye", MUTED); return 0
            elif cmd == "/help": help_panel()
            elif cmd == "/clear": console.clear(); show_header(cfg)
            elif cmd == "/new": conv = Conversation(); notice("new conversation started")
            elif cmd == "/model":
                if args and args[0].lower() == "refresh":
                    if not IS_LOCAL: notice("refresh is only for local providers", RED); continue
                    with console.status(Text(f" querying {PROVIDER_LABEL}…", style=MUTED), spinner="dots", spinner_style=VIOLET):
                        ids = refresh_local_models(cfg)
                    notice(f"refreshed · {len(ids)} models" if ids else "no models returned", MINT if ids else RED); continue
                models = all_models(cfg)
                if not args:
                    if not models: notice("no models — try /model refresh", MUTED); continue
                    chips = Text.assemble(*[(" " + m + " " + ("◆" if m == cfg.model else " ") + "  ", f"bold #0f0a1f on {VIOLET}" if m == cfg.model else f"{SOFT}") for m in models])
                    console.print(Text("  models  ", style=MUTED), chips)
                elif args[0].lower() == "add":
                    if len(args) < 2: notice("usage: /model add <name>", RED)
                    else:
                        n = args[1]
                        if n not in models: cfg.custom_models.append(n); cfg.save()
                        notice(f"model added: {n}")
                elif args[0] in models or IS_LOCAL: cfg.model = args[0]; cfg.save(); notice(f"model → {args[0]}")
                else: notice(f"unknown model: {args[0]}", RED)
            elif cmd == "/system":
                t = " ".join(args).strip()
                if not t:
                    if cfg.system_prompt: console.print(Panel(Text(cfg.system_prompt, style=TEXT), title=Text("system prompt", style=f"bold {VIOLET}"), title_align="left", box=box.ROUNDED, border_style=VIOLET_DEEP, padding=(0,2)))
                    else: notice("no system prompt set", MUTED)
                else: cfg.system_prompt = t; cfg.save(); notice("system prompt updated")
            elif cmd == "/agent":
                cfg.agent_mode = not cfg.agent_mode; cfg.save()
                notice("agent mode " + ("on" if cfg.agent_mode else "off"), GOLD if cfg.agent_mode else MUTED)
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
        client = DeepSeekClient(key, base, cfg.model, PROVIDER)
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
    [System.IO.File]::WriteAllText((Join-Path $RUNNER_DIR "tui.py"), $c, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::WriteAllText((Join-Path $RUNNER_DIR "__init__.py"), "", (New-Object System.Text.UTF8Encoding($false)))
}

# ============================================================================
#  COMMANDS
# ============================================================================
function Start-Tui {
    Push-Location $APP_DIR
    try { $env:PYTHONPATH = $APP_DIR; & $VENV_PY -m runner.tui }
    finally { Pop-Location }
}

function Invoke-ChatLoop {
    $next = "new"
    while ($true) {
        Clear-Host; Write-Logo; Write-Tagline
        $env:AYHANX_START = $next
        Start-Tui
        Write-Host ""
        Write-Rule
        Write-Host "  ◆ " -ForegroundColor Cyan -NoNewline
        Write-Host "What next?   " -ForegroundColor White -NoNewline
        Write-Host "[r]" -ForegroundColor Cyan -NoNewline; Write-Host " resume   " -NoNewline
        Write-Host "[n]" -ForegroundColor Cyan -NoNewline; Write-Host " new   " -NoNewline
        Write-Host "[q]" -ForegroundColor Cyan -NoNewline; Write-Host " quit" -NoNewline
        Write-Host ""
        $k = [Console]::ReadKey($true).KeyChar
        if ($k -in @("q","Q")) { return }
        elseif ($k -in @("r","R")) { $next = "resume" }
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
provider = os.environ.get("AYHANX_PROVIDER","deepseek")
base = os.environ.get("DEEPSEEK_BASE_URL","https://api.deepseek.com").rstrip("/")
h = {"Authorization": f"Bearer {os.environ.get('DEEPSEEK_API_KEY','local')}", "Content-Type": "application/json"}
if provider == "openrouter":
    h["HTTP-Referer"] = "https://github.com/AyhanMansur/AyhanX-Agent"
    h["X-Title"] = "AyhanX-Agent"
r = httpx.post(f"{base}/chat/completions", headers=h, json={"model": os.environ.get("DEEPSEEK_MODEL","deepseek-chat"), "messages": [{"role":"user","content":p}]}, timeout=120)
if r.status_code >= 400:
    try: msg = r.json().get("error",{}).get("message",r.text)
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
provider = os.environ.get("AYHANX_PROVIDER","deepseek")
base = os.environ.get("DEEPSEEK_BASE_URL","https://api.deepseek.com").rstrip("/")
model = os.environ.get("DEEPSEEK_MODEL","deepseek-chat")
h = {"Authorization": f"Bearer {os.environ.get('DEEPSEEK_API_KEY','local')}", "Content-Type": "application/json"}
if provider == "openrouter":
    h["HTTP-Referer"] = "https://github.com/AyhanMansur/AyhanX-Agent"
    h["X-Title"] = "AyhanX-Agent"
G,R,M,N = "\033[38;5;84m","\033[38;5;203m","\033[38;5;245m","\033[0m"
print(f"  {M}provider{N}  {provider}")
print(f"  {M}endpoint{N}  {base}")
print(f"  {M}model{N}     {model}")
try:
    r = httpx.post(f"{base}/chat/completions", headers=h, timeout=30, json={"model": model, "max_tokens": 5, "messages": [{"role":"user","content":"say OK"}]})
    print(f"  {M}status{N}    {r.status_code}")
    j = r.json()
    if "choices" in j:
        print(f"  {M}reply{N}     {j['choices'][0]['message']['content']!r}")
        print(f"  {G}✔ connected{N}")
    else:
        print(f"  {M}body{N}      {r.text[:300]}")
        print(f"  {R}✘ failed{N}")
except Exception as e:
    hint = "  → is the server running?" if provider in ("ollama","lmstudio","vllm","llamacpp","localai") else ""
    print(f"  {R}✘ {type(e).__name__}: {e}{N}{hint}")
'@
    $s | & $VENV_PY -
}

function Invoke-Config {
    Write-Section "Files"
    Write-Info "provider $($env:AYHANX_PROVIDER)"
    Write-Info "config   $CONFIG_FILE"
    Write-Info "env      $ENV_FILE"
    Write-Info "provider $PROVIDER_FILE"
    Write-Info "history  $HISTORY_FILE"
    Write-Info "chats    $CHATS_DIR"
    Write-Info "log      $LOG_FILE"
    Write-Host ""
    if (Test-Path $CONFIG_FILE) { Get-Content $CONFIG_FILE }
    else { Write-Info "no config yet" }
}

function Invoke-Version {
    Write-Section "Version"
    Write-Info "AyhanX-Agent  $VERSION"
    Write-Info "repo       $REPO_URL"
    Write-Info "provider   $($env:AYHANX_PROVIDER)"
    Write-Info "app dir    $APP_DIR"
    if (Test-Path $VENV_PY) { $v = & $VENV_PY --version 2>&1; Write-Info "python     $v" }
}

# ============================================================================
#  MAIN
# ============================================================================
function Main {
    New-Item -ItemType Directory -Force -Path $APP_DIR | Out-Null
    switch ($Command.ToLower()) {
        "ask" { Initialize-Environment; Initialize-Credentials; Invoke-Ask ($Rest -join " ") }
        "health" { Initialize-Environment; Initialize-Credentials; Invoke-Health }
        "config" { Invoke-Config }
        "version" { Invoke-Version }
        { $_ -in @("chat","tui","") } {
            Initialize-Environment
            Initialize-Credentials
            Write-Section "Starting"
            Write-Tools; Write-Tui
            Write-Ok "runner ready"
            Start-Sleep -Milliseconds 200
            Invoke-ChatLoop
            Write-Outro
        }
        default {
            Write-Err "unknown mode: $Command"
            Write-Info "usage: .\ai.ps1 [chat|ask|health|config|version] [-Provider NAME]"
            exit 1
        }
    }
}

Main
