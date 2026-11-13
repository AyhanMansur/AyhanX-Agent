#!/usr/bin/env bash
# ============================================================================
#   AyhanX-Agent · premium terminal client for DeepSeek, OpenRouter, Groq & local
#   Repository:  https://github.com/AyhanMansur/AyhanX-Agent
#   Version:     3.4.0
#
#   Usage:
#     ./ai.sh                              chat (auto-detect provider)
#     ./ai.sh --provider ollama            force Ollama
#     ./ai.sh --provider lmstudio          force LM Studio
#     ./ai.sh --provider vllm              force vLLM
#     ./ai.sh --provider llamacpp          force llama.cpp
#     ./ai.sh --provider localai           force LocalAI
#     ./ai.sh --provider openrouter        force OpenRouter
#     ./ai.sh --provider groq              force Groq
#     ./ai.sh --provider auto              auto-detect local server
#     ./ai.sh ask "prompt"                 one-shot answer
#     ./ai.sh health                       check the API connection
#     ./ai.sh config                       show file locations
#     ./ai.sh version                      print version
# ============================================================================
set -euo pipefail

VERSION="3.4.0"
REPO_URL="https://github.com/AyhanMansur/AyhanX-Agent"
APP_DIR="${HOME}/.ai_platform"
VENV="${APP_DIR}/.venv"
RUNNER_DIR="${APP_DIR}/runner"
CONFIG_FILE="${APP_DIR}/config.json"
ENV_FILE="${APP_DIR}/.env"
HISTORY_FILE="${APP_DIR}/history.txt"
CHATS_DIR="${APP_DIR}/chats"
LOG_FILE="${APP_DIR}/install.log"
PROVIDER_FILE="${APP_DIR}/provider"
export AI_RUNNER_VERSION="$VERSION"

# ---------- palette ----------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  E=$'\e'
  V1="${E}[38;5;44m"; V2="${E}[38;5;30m"; C1="${E}[38;5;51m"
  PK="${E}[38;5;213m"; GD="${E}[38;5;221m"; MT="${E}[38;5;245m"
  OK="${E}[38;5;84m"; ER="${E}[38;5;203m"
  BD="${E}[1m"; DM="${E}[2m"; RS="${E}[0m"
else
  E= V1= V2= C1= PK= GD= MT= OK= ER= BD= DM= RS=
fi

cleanup() {
  local code=$?
  printf '%s' "$RS" 2>/dev/null || true
  stty sane 2>/dev/null || true
  exit "$code"
}
trap cleanup EXIT INT TERM

# ============================================================================
#  PROVIDER HELPERS
# ============================================================================
is_local_provider() {
  case "$1" in
    ollama|lmstudio|vllm|llamacpp|localai) return 0 ;;
    *) return 1 ;;
  esac
}

provider_of_key() {
  case "${1:-}" in
    sk-or-*)  echo "openrouter" ;;
    gsk_*)    echo "groq" ;;
    sk-*)     echo "deepseek" ;;
    *)        echo "" ;;
  esac
}

provider_url() {
  case "$1" in
    openrouter) echo "https://openrouter.ai/api/v1" ;;
    groq)       echo "https://api.groq.com/openai/v1" ;;
    ollama)     echo "${OLLAMA_URL:-http://localhost:11434/v1}" ;;
    lmstudio)   echo "${LMSTUDIO_URL:-http://localhost:1234/v1}" ;;
    vllm)       echo "${VLLM_URL:-http://localhost:8000/v1}" ;;
    llamacpp)   echo "${LLAMACPP_URL:-http://localhost:8080/v1}" ;;
    localai)    echo "${LOCALAI_URL:-http://localhost:8080/v1}" ;;
    *)          echo "https://api.deepseek.com" ;;
  esac
}

provider_default_model() {
  case "$1" in
    openrouter) echo "deepseek/deepseek-chat" ;;
    groq)       echo "llama-3.3-70b-versatile" ;;
    ollama)     echo "qwen2.5:3b" ;;
    lmstudio)   echo "local-model" ;;
    vllm)       echo "local-model" ;;
    llamacpp)   echo "local-model" ;;
    localai)    echo "local-model" ;;
    *)          echo "deepseek-chat" ;;
  esac
}

provider_label() {
  case "$1" in
    openrouter) echo "OpenRouter" ;;
    groq)       echo "Groq" ;;
    ollama)     echo "Ollama" ;;
    lmstudio)   echo "LM Studio" ;;
    vllm)       echo "vLLM" ;;
    llamacpp)   echo "llama.cpp" ;;
    localai)    echo "LocalAI" ;;
    *)          echo "DeepSeek" ;;
  esac
}

# Probe a URL for an OpenAI-compatible /models endpoint
probe_local() {
  local url="$1"
  timeout 2 curl -sSf -H "Authorization: Bearer local" \
    "${url%/}/models" 2>/dev/null | grep -q '"id"'
}

# Try common local server ports; return first that responds
detect_local() {
  local pair name url
  for pair in \
    "ollama:${OLLAMA_URL:-http://localhost:11434/v1}" \
    "lmstudio:${LMSTUDIO_URL:-http://localhost:1234/v1}" \
    "vllm:${VLLM_URL:-http://localhost:8000/v1}" \
    "llamacpp:${LLAMACPP_URL:-http://localhost:8080/v1}" \
    "localai:${LOCALAI_URL:-http://localhost:8080/v1}"
  do
    name="${pair%%:*}"
    url="${pair#*:}"
    if probe_local "$url"; then
      echo "$name"
      return 0
    fi
  done
  return 1
}

# ============================================================================
#  UI PRIMITIVES
# ============================================================================
term_width() {
  local w="${COLUMNS:-}"
  [[ -z "$w" ]] && w="$(tput cols 2>/dev/null || echo 80)"
  (( w > 96 )) && w=96
  (( w < 50 )) && w=50
  echo "$w"
}

rule() {
  local w; w="$(term_width)"
  local line="" i
  for (( i = 0; i < w - 4; i++ )); do line+="─"; done
  printf '  %s%s%s%s\n' "$DM" "$V2" "$line" "$RS"
}

section() { printf '\n  %s%s▍%s %s%s%s\n' "$BD" "$V1" "$RS" "$BD" "$*" "$RS"; }
ok()      { printf '  %s✔%s %s\n' "$OK" "$RS" "$*"; }
warn()    { printf '  %s!%s %s\n' "$GD" "$RS" "$*"; }
err()     { printf '  %s✘%s %s\n' "$ER" "$RS" "$*" >&2; }
info()    { printf '  %s·%s %s%s%s\n' "$MT" "$RS" "$MT" "$*" "$RS"; }

spin() {
  local msg="$1"; shift
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) i=0 rc=0 pid
  mkdir -p "$APP_DIR"
  if [[ ! -t 1 ]]; then
    if "$@" >>"$LOG_FILE" 2>&1; then ok "$msg"; return 0; fi
    err "$msg failed (log: $LOG_FILE)"; return 1
  fi
  "$@" >>"$LOG_FILE" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r  %s%s%s %s%s\033[K' "$PK" "${frames[i % 10]}" "$RS" "$msg" ""
    i=$(( i + 1 ))
    sleep 0.08
  done
  wait "$pid" || rc=$?
  if (( rc == 0 )); then
    printf '\r  %s✔%s %s\033[K\n' "$OK" "$RS" "$msg"
  else
    printf '\r  %s✘%s %s\033[K\n' "$ER" "$RS" "$msg"
    info "log: $LOG_FILE"
  fi
  return "$rc"
}

print_logo() {
  local lines=(
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
  local ramp=(30 36 37 43 44 80 87)
  local max=0 l
  for l in "${lines[@]}"; do
    if (( ${#l} > max )); then max=${#l}; fi
  done
  echo
  for l in "${lines[@]}"; do
    local out="" j c n=${#l}
    if [[ -z "$E" ]]; then
      printf '%s\n' "$l"; continue
    fi
    for (( j = 0; j < n; j++ )); do
      c=${ramp[$(( j * ${#ramp[@]} / max ))]}
      out+="${E}[1;38;5;${c}m${l:j:1}"
    done
    printf '%s%s\n' "$out" "$RS"
  done
  echo
}

print_tagline() {
  local provider="${AYHANX_PROVIDER:-deepseek}"
  printf '  %s◆%s %s%sAyhanX-Agent%s  %s· %s · v%s%s\n' \
    "$V1" "$RS" "$BD" "$V1" "$RS" "$MT" "$(provider_label "$provider")" "$VERSION" "$RS"
  rule
}

print_outro() {
  echo
  rule
  printf '  %s◆%s %sthanks for using AyhanX-Agent%s\n' "$V1" "$RS" "$BD" "$RS"
  printf '  %s%s%s\n\n' "$MT" "$REPO_URL" "$RS"
}

# ============================================================================
#  ENVIRONMENT
# ============================================================================
find_python() {
  for c in python3.12 python3.11 python3.10 python3.13; do
    if command -v "$c" >/dev/null 2>&1 \
       && "$c" -c 'import sys; sys.exit(0 if (3,10)<=sys.version_info[:2]<=(3,13) else 1)' 2>/dev/null; then
      echo "$c"; return 0
    fi
  done
  if command -v uv >/dev/null 2>&1; then
    local p
    p="$(uv python find 3.12 2>/dev/null || true)"
    if [[ -n "$p" && -x "$p" ]]; then echo "$p"; return 0; fi
  fi
  return 1
}

pick_pypi_mirror() {
  local mirrors=(
    "https://pypi.org/simple"
    "https://mirror-pypi.runflare.com/simple"
    "https://mirrors.aliyun.com/pypi/simple"
    "https://pypi.tuna.tsinghua.edu.cn/simple"
  )
  for m in "${mirrors[@]}"; do
    if timeout 6 curl -sSI -o /dev/null "$m/" 2>/dev/null; then
      echo "$m"; return 0
    fi
  done
  return 1
}

ensure_env() {
  section "Environment"
  mkdir -p "$APP_DIR"

  local PY
  if ! PY="$(find_python)"; then
    warn "no Python 3.10–3.13 found — installing uv"
    spin "installing uv" bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh' || true
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    if command -v uv >/dev/null 2>&1; then
      spin "fetching Python 3.12" uv python install 3.12 || true
      PY="$(uv python find 3.12 2>/dev/null || true)"
    fi
    if [[ -z "${PY:-}" ]]; then err "cannot obtain Python 3.10–3.13"; exit 1; fi
  fi
  ok "python → $PY"

  local rebuild=0
  [[ -d "$VENV" ]] || rebuild=1
  [[ -x "$VENV/bin/python" ]] || rebuild=1
  if (( !rebuild )); then
    "$VENV/bin/python" -c 'import httpx,rich,prompt_toolkit' 2>/dev/null || rebuild=1
  fi

  if (( rebuild )); then
    local mirror host
    if ! mirror="$(pick_pypi_mirror)"; then
      err "no PyPI mirror reachable — check DNS or internet"
      info "try: echo 'nameserver 1.1.1.1' > /etc/resolv.conf"
      exit 1
    fi
    host="$(echo "$mirror" | awk -F/ '{print $3}')"
    ok "package index → $host"

    rm -rf "$VENV"
    mkdir -p "$RUNNER_DIR" "$CHATS_DIR"
    spin "creating virtual environment" "$PY" -m venv "$VENV" || { err "venv failed"; exit 1; }
    spin "upgrading pip" "$VENV/bin/pip" install -q --upgrade pip --timeout 10 --retries 1 || true
    spin "installing httpx · rich · prompt_toolkit" \
      "$VENV/bin/pip" install --index-url "$mirror" --trusted-host "$host" \
      --timeout 20 --retries 3 httpx rich prompt_toolkit || { err "package install failed"; exit 1; }
  else
    ok "runtime ready"
  fi
}

ensure_key() {
  section "Credentials"
  if [[ -f "$ENV_FILE" ]]; then
    set -o allexport; . "$ENV_FILE"; set +o allexport
  fi

  # ---- resolve provider first (before asking for any key) ----
  local provider=""
  if [[ -n "${AYHANX_PROVIDER:-}" && "${AYHANX_PROVIDER}" != "auto" ]]; then
    provider="$AYHANX_PROVIDER"
  elif [[ -n "${DEEPSEEK_BASE_URL:-}" ]]; then
    case "$DEEPSEEK_BASE_URL" in
      *openrouter*)          provider="openrouter" ;;
      *groq*)                provider="groq" ;;
      *:11434*)              provider="ollama" ;;
      *:1234*)               provider="lmstudio" ;;
      *:8000*)               provider="vllm" ;;
      *:8080*)               provider="llamacpp" ;;
      *deepseek*)            provider="deepseek" ;;
    esac
  fi

  # ---- auto-detect a running local server ----
  if [[ -z "$provider" || "${AYHANX_PROVIDER:-}" == "auto" ]]; then
    local detected=""
    if detected="$(detect_local)"; then
      provider="$detected"
      ok "detected local server → $(provider_label "$provider")"
    fi
  fi

  # ---- infer from key, provider file, or default ----
  if [[ -z "$provider" ]]; then
    provider="$(provider_of_key "${DEEPSEEK_API_KEY:-}")"
  fi
  if [[ -z "$provider" && -f "$PROVIDER_FILE" ]]; then
    provider="$(cat "$PROVIDER_FILE" 2>/dev/null || echo "")"
  fi
  if [[ -z "$provider" ]]; then
    provider="deepseek"
  fi

  # ---- obtain key only when needed ----
  if is_local_provider "$provider"; then
    DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-local}"
    ok "local provider — no API key required"
  else
    if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
      warn "no API key found for $(provider_label "$provider")"
      printf '  %s›%s paste your key %s: ' "$PK" "$RS" "$MT"
      read -r -s DEEPSEEK_API_KEY || true
      echo
      if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then err "a key is required"; exit 1; fi
      printf 'DEEPSEEK_API_KEY=%s\n' "$DEEPSEEK_API_KEY" > "$ENV_FILE"
      chmod 600 "$ENV_FILE"
      ok "key saved"
    else
      ok "key loaded"
    fi
  fi

  printf '%s\n' "$provider" > "$PROVIDER_FILE"
  export AYHANX_PROVIDER="$provider"
  export DEEPSEEK_API_KEY
  export DEEPSEEK_BASE_URL="${DEEPSEEK_BASE_URL:-$(provider_url "$provider")}"
  export DEEPSEEK_MODEL="${DEEPSEEK_MODEL:-$(provider_default_model "$provider")}"

  ok "provider → $(provider_label "$provider")"
  info "endpoint → $DEEPSEEK_BASE_URL"
  info "model    → $DEEPSEEK_MODEL"
}

# ============================================================================
#  GENERATE: runner/tools.py (unchanged)
# ============================================================================
write_tools() {
  mkdir -p "$RUNNER_DIR"
  cat > "$RUNNER_DIR/tools.py" <<'PYEOF'
"""Tool definitions and implementations for AyhanX-Agent agent mode."""
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

TOOL_SPECS = [
    {"type": "function", "function": {
        "name": "get_current_time",
        "description": "Get the current UTC date and time in ISO 8601 format.",
        "parameters": {"type": "object", "properties": {}},
    }},
    {"type": "function", "function": {
        "name": "calculate",
        "description": "Evaluate a simple arithmetic expression.",
        "parameters": {
            "type": "object",
            "properties": {
                "expression": {"type": "string",
                               "description": "Math expression, e.g. '2 + 3 * 4'"}
            },
            "required": ["expression"],
        },
    }},
    {"type": "function", "function": {
        "name": "list_directory",
        "description": "List files in a directory under the user's home.",
        "parameters": {
            "type": "object",
            "properties": {"path": {"type": "string"}},
        },
    }},
    {"type": "function", "function": {
        "name": "read_file",
        "description": "Read a text file under the user's home (10 KB limit).",
        "parameters": {
            "type": "object",
            "properties": {"path": {"type": "string"}},
            "required": ["path"],
        },
    }},
    {"type": "function", "function": {
        "name": "run_shell",
        "description": "Run a safe shell command and return its output.",
        "parameters": {
            "type": "object",
            "properties": {"command": {"type": "string"}},
            "required": ["command"],
        },
    }},
]


def _safe_resolve(path_str: str) -> Path:
    base = Path.home()
    target = (base / path_str).expanduser().resolve()
    if target != base and base not in target.parents:
        raise ValueError(f"path escapes home directory: {path_str}")
    return target


def _err(msg: str) -> str:
    return json.dumps({"error": msg})


def tool_get_current_time(_a: dict) -> str:
    return datetime.now(timezone.utc).isoformat()


def tool_calculate(a: dict) -> str:
    expr = a.get("expression", "").strip()
    if not expr:
        return _err("empty expression")
    allowed = set("0123456789+-*/(). ")
    if any(ch not in allowed for ch in expr):
        return _err(f"disallowed character in expression: {expr!r}")
    try:
        return str(eval(expr, {"__builtins__": {}}, {}))
    except Exception as e:
        return _err(f"evaluation failed: {e}")


def tool_list_directory(a: dict) -> str:
    rel = a.get("path", "").strip()
    try:
        target = _safe_resolve(rel) if rel else Path.home()
    except ValueError as e:
        return _err(str(e))
    if not target.exists():
        return _err(f"path not found: {target}")
    if not target.is_dir():
        return _err(f"not a directory: {target}")
    try:
        items = sorted(target.iterdir())
    except PermissionError:
        return _err("permission denied")
    names = [(p.name + ("/" if p.is_dir() else "")) for p in items[:200]]
    return json.dumps(names)


def tool_read_file(a: dict) -> str:
    rel = a.get("path", "").strip()
    if not rel:
        return _err("path required")
    try:
        target = _safe_resolve(rel)
    except ValueError as e:
        return _err(str(e))
    if not target.exists():
        return _err(f"file not found: {target}")
    if not target.is_file():
        return _err(f"not a file: {target}")
    try:
        data = target.read_text(encoding="utf-8", errors="replace")
    except PermissionError:
        return _err("permission denied")
    if len(data) > 10 * 1024:
        data = data[:10 * 1024] + "\n... [truncated at 10 KB]"
    return data


def tool_run_shell(a: dict) -> str:
    cmd = a.get("command", "").strip()
    if not cmd:
        return _err("command required")
    blocked = ("rm -rf /", "mkfs", ":(){", "dd if=/dev/zero")
    if any(b in cmd for b in blocked):
        return _err("refused: destructive command detected")
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True,
            timeout=15, cwd=str(Path.home()),
        )
        output = result.stdout
        if result.returncode != 0:
            output += f"\n[exit code: {result.returncode}]"
        if result.stderr:
            output += f"\n[stderr]: {result.stderr[:500]}"
        return output[:5000] or "(no output)"
    except subprocess.TimeoutExpired:
        return _err("command timed out (15s)")
    except Exception as e:
        return _err(f"{type(e).__name__}: {e}")


TOOL_IMPLS = {
    "get_current_time": tool_get_current_time,
    "calculate": tool_calculate,
    "list_directory": tool_list_directory,
    "read_file": tool_read_file,
    "run_shell": tool_run_shell,
}
PYEOF
}

# ============================================================================
#  GENERATE: runner/tui.py (now local-aware)
# ============================================================================
write_tui() {
  cat > "$RUNNER_DIR/tui.py" <<'PYEOF'
"""AyhanX-Agent — premium terminal chat for cloud & local providers."""
import html
import json
import os
import sys
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

VERSION = os.environ.get("AI_RUNNER_VERSION", "3.4.0")
APP_DIR = Path(os.environ.get("APP_DIR", Path.home() / ".ai_platform"))
CONFIG_PATH = APP_DIR / "config.json"
HISTORY_PATH = APP_DIR / "history.txt"
CHATS_DIR = APP_DIR / "chats"
CHATS_DIR.mkdir(parents=True, exist_ok=True)

PROVIDER = os.environ.get("AYHANX_PROVIDER", "deepseek")
PROVIDER_LABEL = {
    "deepseek": "DeepSeek",
    "openrouter": "OpenRouter",
    "groq": "Groq",
    "ollama": "Ollama",
    "lmstudio": "LM Studio",
    "vllm": "vLLM",
    "llamacpp": "llama.cpp",
    "localai": "LocalAI",
}.get(PROVIDER, PROVIDER)

LOCAL_PROVIDERS = {"ollama", "lmstudio", "vllm", "llamacpp", "localai"}
IS_LOCAL = PROVIDER in LOCAL_PROVIDERS

PROVIDER_MODELS = {
    "deepseek": ["deepseek-chat", "deepseek-reasoner"],
    "openrouter": [
        "deepseek/deepseek-chat",
        "deepseek/deepseek-chat-v3-0324:free",
        "deepseek/deepseek-r1:free",
        "meta-llama/llama-3.3-70b-instruct:free",
        "google/gemini-2.0-flash-exp:free",
        "qwen/qwen-2.5-72b-instruct:free",
        "mistralai/mistral-small-24b-instruct-2501:free",
        "microsoft/phi-4:free",
        "anthropic/claude-3.5-sonnet",
    ],
    "groq": [
        "llama-3.3-70b-versatile",
        "llama-3.1-8b-instant",
        "mixtral-8x7b-32768",
        "gemma2-9b-it",
        "qwen-2.5-32b",
    ],
    # local providers are populated dynamically via /models
    "ollama": [],
    "lmstudio": [],
    "vllm": [],
    "llamacpp": [],
    "localai": [],
}
MODELS = PROVIDER_MODELS.get(PROVIDER, PROVIDER_MODELS["deepseek"])
START = os.environ.get("AYHANX_START", "new")


def fetch_server_models(base_url: str, api_key: str) -> list:
    """GET {base}/models — returns list of model ids."""
    headers = {"Authorization": f"Bearer {api_key}"}
    if PROVIDER == "openrouter":
        headers["HTTP-Referer"] = "https://github.com/AyhanMansur/AyhanX-Agent"
        headers["X-Title"] = "AyhanX-Agent"
    try:
        r = httpx.get(f"{base_url.rstrip('/')}/models", headers=headers, timeout=6)
        if r.status_code == 200:
            return [m["id"] for m in r.json().get("data", [])]
    except Exception:
        pass
    return []


def refresh_local_models(cfg) -> list:
    """For local providers, fetch models from the server and remember them."""
    if not IS_LOCAL:
        return []
    base = os.environ.get("DEEPSEEK_BASE_URL", "")
    key = os.environ.get("DEEPSEEK_API_KEY", "local")
    ids = fetch_server_models(base, key)
    if ids:
        # persist so /model list survives a restart
        for m in ids:
            if m not in cfg.custom_models and m not in MODELS:
                cfg.custom_models.append(m)
        cfg.save()
        # if current model isn't in the server, switch to the first one
        if cfg.model not in ids:
            cfg.model = ids[0]
            cfg.save()
    return ids


def all_models(cfg) -> list:
    return MODELS + [m for m in cfg.custom_models if m not in MODELS]


def save_last(conv) -> None:
    if conv.messages:
        (CHATS_DIR / "last.json").write_text(json.dumps(conv.messages, indent=2))


VIOLET = "#40e0d0"
VIOLET_DEEP = "#0f9d9a"
CYAN = "#5eead4"
GOLD = "#fbbf24"
MINT = "#34d399"
RED = "#f87171"
MUTED = "#64748b"
SOFT = "#94a3b8"
TEXT = "#e2e8f0"

console = Console(highlight=False)


@dataclass
class Config:
    model: str = "deepseek-chat"
    system_prompt: str = ""
    agent_mode: bool = False
    max_context_messages: int = 40
    custom_models: list = field(default_factory=list)

    @classmethod
    def load(cls) -> "Config":
        if CONFIG_PATH.exists():
            try:
                data = json.loads(CONFIG_PATH.read_text())
                return cls(**{k: v for k, v in data.items()
                              if k in cls.__annotations__})
            except Exception:
                pass
        return cls()

    def save(self) -> None:
        CONFIG_PATH.write_text(json.dumps(self.__dict__, indent=2))
        os.chmod(CONFIG_PATH, 0o600)


@dataclass
class Conversation:
    messages: list = field(default_factory=list)
    created: str = field(default_factory=lambda: datetime.now().isoformat())

    def add_user(self, text: str) -> None:
        self.messages.append({"role": "user", "content": text})

    def add_assistant(self, text: str) -> None:
        self.messages.append({"role": "assistant", "content": text})

    def trim(self, max_messages: int) -> None:
        system = [m for m in self.messages if m["role"] == "system"]
        dialog = [m for m in self.messages if m["role"] != "system"]
        if len(dialog) > max_messages:
            dialog = dialog[-max_messages:]
        self.messages = system + dialog

    def save(self, name: str) -> Path:
        path = CHATS_DIR / f"{name}.json"
        path.write_text(json.dumps(self.messages, indent=2))
        return path

    @classmethod
    def load(cls, name: str) -> "Conversation":
        path = CHATS_DIR / f"{name}.json"
        if not path.exists():
            raise FileNotFoundError(f"no saved chat named '{name}'")
        conv = cls()
        conv.messages = json.loads(path.read_text())
        return conv

    def to_api(self) -> list:
        return [m for m in self.messages if m.get("content", "").strip()]


class DeepSeekClient:
    def __init__(self, api_key: str, base_url: str, model: str,
                 provider: str = "deepseek"):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.model = model
        self.provider = provider

    def _headers(self) -> dict:
        h = {"Authorization": f"Bearer {self.api_key}",
             "Content-Type": "application/json"}
        if self.provider == "openrouter":
            h["HTTP-Referer"] = "https://github.com/AyhanMansur/AyhanX-Agent"
            h["X-Title"] = "AyhanX-Agent"
        return h

    def _hint(self, status: int) -> str:
        base = {
            401: "invalid API key",
            402: "insufficient balance",
            429: "rate limited — wait a few seconds",
        }.get(status, "")
        if not base:
            return ""
        if self.provider == "openrouter":
            return base + " — openrouter.ai/keys"
        if self.provider in LOCAL_PROVIDERS:
            return base + " — is the local server running?"
        return base + " — platform.deepseek.com/api_keys"

    def _error(self, status: int, body: str) -> str:
        msg = body
        try:
            msg = json.loads(body).get("error", {}).get("message", body)
        except Exception:
            pass
        hint = self._hint(status)
        return f"HTTP {status}: {msg}" + (f"\n→ {hint}" if hint else "")

    def chat(self, messages, tools=None, stream=True):
        payload = {"model": self.model, "messages": messages, "stream": stream}
        if tools:
            payload["tools"] = tools
            payload["tool_choice"] = "auto"
        client = httpx.Client(timeout=180)
        if stream:
            return self._stream(client, payload)
        return self._nonstream(client, payload)

    def _stream(self, client, payload):
        def gen():
            try:
                with client.stream("POST", f"{self.base_url}/chat/completions",
                                   headers=self._headers(), json=payload) as r:
                    if r.status_code >= 400:
                        body = r.read().decode(errors="replace")
                        yield {"error": self._error(r.status_code, body)}
                        return
                    for line in r.iter_lines():
                        if not line.startswith("data:"):
                            continue
                        data = line[5:].strip()
                        if data == "[DONE]":
                            break
                        try:
                            obj = json.loads(data)
                        except json.JSONDecodeError:
                            continue
                        delta = obj.get("choices", [{}])[0].get("delta", {})
                        if chunk := delta.get("content"):
                            yield {"text": chunk}
            finally:
                client.close()
        return gen()

    def _nonstream(self, client, payload):
        try:
            r = client.post(f"{self.base_url}/chat/completions",
                            headers=self._headers(), json=payload)
            if r.status_code >= 400:
                return {"error": self._error(r.status_code, r.text)}
            return r.json()
        finally:
            client.close()


# ============================================================================
#  VISUAL COMPONENTS
# ============================================================================
def _rgb(h: str):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def gradient(text: str, start: str = VIOLET_DEEP, end: str = CYAN) -> Text:
    a, b = _rgb(start), _rgb(end)
    out = Text()
    n = max(len(text) - 1, 1)
    for i, ch in enumerate(text):
        k = i / n
        c = "#" + "".join(f"{round(a[j] + (b[j] - a[j]) * k):02x}" for j in range(3))
        out.append(ch, style=f"bold {c}")
    return out


def model_chip(name: str) -> Text:
    return Text(f" {name} ", style=f"bold #0f0a1f on {VIOLET}")


def mode_chip(agent: bool) -> Text:
    if agent:
        return Text(" AGENT ", style=f"bold #1c1600 on {GOLD}")
    return Text(" CHAT ", style=f"bold #04221a on {MINT}")


def provider_chip() -> Text:
    label = f" {PROVIDER_LABEL} "
    if IS_LOCAL:
        # warm amber for local, cyan for cloud
        return Text(label, style="bold #1c1600 on #fbbf24")
    return Text(label, style=f"bold #0a0f1c on {CYAN}")


def show_header(cfg: Config) -> None:
    left = Text.assemble(("◆ ", VIOLET), gradient("AyhanX-Agent"),
                         ("   ", ""), (f"v{VERSION}", MUTED))
    right = Text.assemble(provider_chip(), ("  ", ""),
                          model_chip(cfg.model), ("  ", ""),
                          mode_chip(cfg.agent_mode))
    grid = Table.grid(expand=True)
    grid.add_column(ratio=1)
    grid.add_column(justify="right")
    grid.add_row(left, right)
    console.print(Panel(grid, box=box.ROUNDED, border_style=VIOLET_DEEP,
                        padding=(0, 2)))
    console.print(Text("  type a message · /help for commands · Ctrl+D to exit",
                       style=MUTED))
    console.print()


def notice(msg: str, color: str = MINT) -> None:
    console.print(Text(f"  {msg}", style=color))


def error_panel(msg: str) -> Panel:
    return Panel(Text(msg, style=RED),
                 title=Text("error", style=f"bold {RED}"), title_align="left",
                 box=box.ROUNDED, border_style=RED, padding=(0, 2))


def assistant_panel(text: str, thinking: bool = False) -> Panel:
    title = Text.assemble(("◆ ", VIOLET),
                          (PROVIDER_LABEL, f"bold {VIOLET}"),
                          ("  thinking…" if thinking else "", MUTED))
    return Panel(Markdown(text or ""), title=title, title_align="left",
                 box=box.ROUNDED, border_style=VIOLET_DEEP, padding=(0, 2))


def print_user(text: str) -> None:
    console.print()
    console.print(Text.assemble((" you ", f"bold #0f0a1f on {CYAN}"),
                                ("  ", ""), (text, TEXT)))
    console.print()


def tool_card(name: str, args: dict, result: str) -> None:
    arg_s = json.dumps(args, ensure_ascii=False)[:90]
    preview = result[:140].replace("\n", " ")
    if len(result) > 140:
        preview += "…"
    console.print(Text.assemble(("  ⚙ ", GOLD), (name, f"bold {GOLD}"),
                                ("  ", ""), (arg_s, MUTED)))
    console.print(Text.assemble(("    └ ", "#334155"), (preview, SOFT)))


def help_panel() -> None:
    rows = [
        ("/new", "start a new conversation"),
        ("/clear", "clear the screen"),
        ("/model [name]", "show or switch the model"),
        ("/model refresh", "re-fetch models from server (local only)"),
        ("/model add <name>", "add a model to the list"),
        ("/system [text]", "show or set the system prompt"),
        ("/agent", "toggle agent mode (tools)"),
        ("/save [name]", "save this conversation"),
        ("/load <name>", "load a saved conversation"),
        ("/chats", "list saved conversations"),
        ("/history", "print this conversation"),
        ("/info", "show configuration"),
        ("/exit", "quit"),
    ]
    t = Table.grid(padding=(0, 3))
    t.add_column(style=f"bold {CYAN}", no_wrap=True)
    t.add_column(style=SOFT)
    for cmd, desc in rows:
        t.add_row(cmd, desc)
    keys = Text.assemble(
        ("Enter", f"bold {TEXT}"), (" send    ", MUTED),
        ("Esc+Enter", f"bold {TEXT}"), (" newline    ", MUTED),
        ("↑ ↓", f"bold {TEXT}"), (" history    ", MUTED),
        ("Ctrl+C", f"bold {TEXT}"), (" cancel", MUTED),
    )
    console.print(Panel(Group(t, Text(""), keys),
                        title=Text("commands", style=f"bold {VIOLET}"),
                        title_align="left", box=box.ROUNDED,
                        border_style=VIOLET_DEEP, padding=(1, 2)))


def info_panel(cfg: Config, conv: Conversation) -> None:
    t = Table.grid(padding=(0, 3))
    t.add_column(style=f"bold {VIOLET}", no_wrap=True)
    t.add_column(style=TEXT)
    t.add_row("provider", PROVIDER_LABEL)
    t.add_row("endpoint", os.environ.get("DEEPSEEK_BASE_URL", "?"))
    t.add_row("model", cfg.model)
    t.add_row("mode", "agent" if cfg.agent_mode else "chat")
    t.add_row("system prompt", "set" if cfg.system_prompt else "none")
    t.add_row("messages", str(len(conv.messages)))
    t.add_row("config", str(CONFIG_PATH))
    t.add_row("chats", str(CHATS_DIR))
    console.print(Panel(t, title=Text("info", style=f"bold {VIOLET}"),
                        title_align="left", box=box.ROUNDED,
                        border_style=VIOLET_DEEP, padding=(1, 2)))


def chats_table() -> None:
    chats = sorted(CHATS_DIR.glob("*.json"))
    if not chats:
        notice("no saved chats yet", MUTED)
        return
    t = Table(box=box.SIMPLE_HEAD, header_style=f"bold {VIOLET}",
              border_style=MUTED, expand=False)
    t.add_column("name", style=f"bold {CYAN}")
    t.add_column("messages", justify="right")
    t.add_column("updated", style=SOFT)
    for p in chats:
        try:
            n = str(len(json.loads(p.read_text())))
        except Exception:
            n = "?"
        t.add_row(p.stem, n, datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M"))
    console.print(t)


def print_history(conv: Conversation) -> None:
    if not conv.messages:
        notice("nothing here yet", MUTED)
        return
    for m in conv.messages:
        if m["role"] == "user":
            console.print(Text.assemble(("❯ ", f"bold {CYAN}"), (m["content"], TEXT)))
        elif m["role"] == "assistant":
            console.print(Markdown(m["content"]))
        console.print()


# ============================================================================
#  PROMPT
# ============================================================================
KB = KeyBindings()


@KB.add("enter")
def _(event):
    event.current_buffer.validate_and_handle()


@KB.add("escape", "enter")
def _(event):
    event.current_buffer.insert_text("\n")


@KB.add("c-j")
def _(event):
    event.current_buffer.insert_text("\n")


PROMPT_STYLE = Style.from_dict({
    "arrow": f"{VIOLET} bold",
    "bottom-toolbar": "bg:#0b0a14 #94a3b8",
    "completion-menu": "bg:#14122a #e2e8f0",
    "completion-menu.completion.current": f"bg:{VIOLET_DEEP} #ffffff",
})


def toolbar(cfg: Config, conv: Conversation) -> HTML:
    mode = ('<style fg="#fbbf24"><b>AGENT</b></style>' if cfg.agent_mode
            else '<style fg="#34d399"><b>CHAT</b></style>')
    prov_fg = "#fbbf24" if IS_LOCAL else "#5eead4"
    return HTML(
        f' <style fg="{prov_fg}"><b>{html.escape(PROVIDER_LABEL)}</b></style>'
        f'  ·  <style fg="#a78bfa"><b>{html.escape(cfg.model)}</b></style>'
        f'  ·  {mode}  ·  {len(conv.messages)} msgs'
        f'    <style fg="#64748b">/help · Enter send · Esc+Enter newline · Ctrl+D exit</style>'
    )


# ============================================================================
#  CHAT ENGINE
# ============================================================================
def build_msgs(conv: Conversation, cfg: Config) -> list:
    msgs = conv.to_api()
    if cfg.system_prompt:
        msgs = [{"role": "system", "content": cfg.system_prompt}] + msgs
    return msgs


def stream_response(client, conv, cfg) -> str:
    buf: list = []
    live = Live(Spinner("dots", text=Text(" thinking", style=MUTED), style=VIOLET),
                console=console, refresh_per_second=12, transient=False)
    live.start()
    try:
        for chunk in client.chat(build_msgs(conv, cfg), stream=True):
            if "error" in chunk:
                live.update(error_panel(chunk["error"]))
                live.stop()
                return ""
            if "text" in chunk:
                buf.append(chunk["text"])
                live.update(assistant_panel("".join(buf), thinking=True))
    except httpx.RequestError as e:
        live.update(error_panel(f"network error: {e}"))
        live.stop()
        return ""
    except KeyboardInterrupt:
        live.update(assistant_panel("".join(buf) + "\n\n*cancelled*"))
        live.stop()
        return "".join(buf)

    full = "".join(buf)
    if not full:
        live.update(Text("  (empty response)", style=MUTED))
        live.stop()
        return ""
    live.update(assistant_panel(full))
    live.stop()
    return full


def run_agent(client, conv, cfg) -> str:
    msgs = build_msgs(conv, cfg)
    for _ in range(8):
        with console.status(Text(" thinking", style=MUTED), spinner="dots",
                            spinner_style=VIOLET):
            try:
                resp = client.chat(msgs, tools=TOOL_SPECS, stream=False)
            except httpx.RequestError as e:
                resp = {"error": f"network error: {e}"}

        if isinstance(resp, dict) and "error" in resp:
            console.print(error_panel(resp["error"]))
            return ""

        msg = resp.get("choices", [{}])[0].get("message", {})
        tool_calls = msg.get("tool_calls") or []

        if not tool_calls:
            content = msg.get("content") or ""
            console.print(assistant_panel(content))
            return content

        if msg.get("content"):
            console.print(Text(msg["content"], style=TEXT))
        msgs.append(msg)

        for tc in tool_calls:
            fn = tc.get("function", {})
            name = fn.get("name", "?")
            try:
                args = json.loads(fn.get("arguments") or "{}")
            except json.JSONDecodeError:
                args = {}
            impl = TOOL_IMPLS.get(name)
            if impl:
                try:
                    result = impl(args)
                except Exception as e:
                    result = f"Error: {type(e).__name__}: {e}"
            else:
                result = f"Error: unknown tool '{name}'"
            tool_card(name, args, result)
            msgs.append({"role": "tool", "tool_call_id": tc.get("id", ""),
                         "content": result})

    console.print(error_panel("stopped after 8 tool steps"))
    return ""


# ============================================================================
#  MAIN LOOP
# ============================================================================
COMMANDS = ["/help", "/new", "/clear", "/model", "/system", "/agent",
            "/save", "/load", "/chats", "/history", "/info", "/exit"]


def main() -> int:
    api_key = os.environ.get("DEEPSEEK_API_KEY", "local" if IS_LOCAL else "")
    if not api_key and not IS_LOCAL:
        console.print(error_panel("DEEPSEEK_API_KEY is not set"))
        return 1

    base_url = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
    cfg = Config.load()

    # seed a sensible default model per provider
    if os.environ.get("DEEPSEEK_MODEL"):
        cfg.model = os.environ["DEEPSEEK_MODEL"]
    elif cfg.model not in MODELS and cfg.model not in cfg.custom_models:
        cfg.model = MODELS[0] if MODELS else "local-model"

    # for local providers, try to fetch the live model list once at start
    if IS_LOCAL:
        with console.status(Text(f" querying {PROVIDER_LABEL}…", style=MUTED),
                            spinner="dots", spinner_style=VIOLET):
            ids = refresh_local_models(cfg)
        if not ids:
            notice(f"could not reach {PROVIDER_LABEL} at {base_url}", RED)
            notice(f"is it running? start it and retry, or use /model refresh", MUTED)
        elif cfg.model not in ids:
            # keep provider default if the server exposes it, else pick first
            cfg.model = ids[0]
            cfg.save()

    conv = Conversation()
    show_header(cfg)
    if START == "resume" and (CHATS_DIR / "last.json").exists():
        conv = Conversation.load("last")
        notice(f"resumed last chat · {len(conv.messages)} messages")
        console.print()

    session = PromptSession(
        key_bindings=KB,
        style=PROMPT_STYLE,
        history=FileHistory(str(HISTORY_PATH)),
        completer=WordCompleter(COMMANDS, ignore_case=True),
        complete_while_typing=True,
        bottom_toolbar=lambda: toolbar(cfg, conv),
    )

    while True:
        try:
            raw = session.prompt(HTML("<arrow>❯ </arrow>"))
        except KeyboardInterrupt:
            console.print(Text("  ^C", style=MUTED))
            continue
        except EOFError:
            save_last(conv)
            console.print()
            notice("bye", MUTED)
            return 0

        text = raw.strip()
        if not text:
            continue

        if text.startswith("/"):
            parts = text.split(maxsplit=1)
            cmd = parts[0].lower()
            args = parts[1].split() if len(parts) > 1 else []

            if cmd in ("/exit", "/quit"):
                save_last(conv)
                notice("bye", MUTED)
                return 0
            elif cmd == "/help":
                help_panel()
            elif cmd == "/clear":
                console.clear()
                show_header(cfg)
            elif cmd == "/new":
                conv = Conversation()
                notice("new conversation started")
            elif cmd == "/model":
                if args and args[0].lower() == "refresh":
                    if not IS_LOCAL:
                        notice("refresh is only available for local providers", RED)
                        continue
                    with console.status(Text(f" querying {PROVIDER_LABEL}…", style=MUTED),
                                        spinner="dots", spinner_style=VIOLET):
                        ids = refresh_local_models(cfg)
                    if ids:
                        notice(f"refreshed · {len(ids)} models from {PROVIDER_LABEL}")
                    else:
                        notice("no models returned by server", RED)
                    continue
                models = all_models(cfg)
                if not args:
                    if not models:
                        notice("no models available — try /model refresh", MUTED)
                        continue
                    chips = Text.assemble(*[
                        (" " + m + " " + ("◆" if m == cfg.model else " ") + "  ",
                         f"bold #0f0a1f on {VIOLET}" if m == cfg.model else f"{SOFT}")
                        for m in models
                    ])
                    console.print(Text("  models  ", style=MUTED), chips)
                elif args[0].lower() == "add":
                    if len(args) < 2:
                        notice("usage: /model add <name>", RED)
                    else:
                        name = args[1]
                        if name not in models:
                            cfg.custom_models.append(name)
                            cfg.save()
                        notice(f"model added: {name}  ·  switch with /model {name}")
                elif args[0] in models or IS_LOCAL:
                    cfg.model = args[0]
                    cfg.save()
                    notice(f"model → {args[0]}")
                else:
                    notice(f"unknown model: {args[0]}  ·  add it with /model add {args[0]}", RED)
            elif cmd == "/system":
                txt = " ".join(args).strip()
                if not txt:
                    if cfg.system_prompt:
                        console.print(Panel(Text(cfg.system_prompt, style=TEXT),
                                            title=Text("system prompt", style=f"bold {VIOLET}"),
                                            title_align="left", box=box.ROUNDED,
                                            border_style=VIOLET_DEEP, padding=(0, 2)))
                    else:
                        notice("no system prompt set", MUTED)
                else:
                    cfg.system_prompt = txt
                    cfg.save()
                    notice("system prompt updated")
            elif cmd == "/agent":
                cfg.agent_mode = not cfg.agent_mode
                cfg.save()
                notice("agent mode " + ("on — tools enabled" if cfg.agent_mode else "off"),
                       GOLD if cfg.agent_mode else MUTED)
            elif cmd == "/save":
                name = args[0] if args else datetime.now().strftime("chat-%Y%m%d-%H%M%S")
                try:
                    p = conv.save(name)
                    notice(f"saved → {p}")
                except Exception as e:
                    notice(f"save failed: {e}", RED)
            elif cmd == "/load":
                if not args:
                    notice("usage: /load <name>", RED)
                else:
                    try:
                        conv = Conversation.load(args[0])
                        notice(f"loaded {len(conv.messages)} messages from {args[0]}")
                    except FileNotFoundError as e:
                        notice(str(e), RED)
            elif cmd == "/chats":
                chats_table()
            elif cmd == "/history":
                print_history(conv)
            elif cmd == "/info":
                info_panel(cfg, conv)
            else:
                notice(f"unknown command: {cmd}  (try /help)", RED)
            continue

        print_user(text)
        conv.add_user(text)
        conv.trim(cfg.max_context_messages)
        client = DeepSeekClient(api_key, base_url, cfg.model, PROVIDER)

        try:
            if cfg.agent_mode:
                answer = run_agent(client, conv, cfg)
            else:
                answer = stream_response(client, conv, cfg)
        except KeyboardInterrupt:
            notice("cancelled", MUTED)
            conv.messages.pop()
            continue

        if answer:
            conv.add_assistant(answer)
        else:
            conv.messages.pop()
        console.print()


if __name__ == "__main__":
    sys.exit(main())
PYEOF
  touch "$RUNNER_DIR/__init__.py"
}

# ============================================================================
#  COMMANDS
# ============================================================================
cmd_tui() {
  cd "$APP_DIR"
  PYTHONPATH="$APP_DIR" "$VENV/bin/python" -m runner.tui || true
}

add_model() {
  printf '  %s›%s new model id: ' "$PK" "$RS"
  local name=""
  read -r name || true
  name="${name// /}"
  if [[ -z "$name" ]]; then warn "no model name given"; return 0; fi
  if "$VENV/bin/python" - "$name" "$CONFIG_FILE" <<'MODELPY'
import json, os, sys
name, path = sys.argv[1], sys.argv[2]
data = json.load(open(path)) if os.path.exists(path) else {}
models = data.get("custom_models", [])
if name not in models:
    models.append(name)
data["custom_models"] = models
json.dump(data, open(path, "w"), indent=2)
os.chmod(path, 0o600)
MODELPY
  then
    ok "model added: $name"
  else
    err "could not save model"
  fi
}

post_menu() {
  echo
  rule
  printf '  %s◆%s %sWhat next?%s   %s[r]%s resume last chat   %s[n]%s new chat   %s[a]%s add model   %s[q]%s quit\n' \
    "$V1" "$RS" "$BD" "$RS" "$C1" "$RS" "$C1" "$RS" "$C1" "$RS" "$C1" "$RS"
  local key=""
  read -r -s -n 1 key || key="q"
  echo
  printf '%s' "$key"
}

chat_loop() {
  local next="new" choice
  while true; do
    clear
    print_logo
    print_tagline
    export AYHANX_START="$next"
    cmd_tui
    choice="$(post_menu)"
    case "$choice" in
      r|R) next="resume" ;;
      a|A) add_model; sleep 1; next="new" ;;
      q|Q) break ;;
      *)   next="new" ;;
    esac
  done
}

cmd_ask() {
  local prompt="$*"
  if [[ -z "$prompt" ]]; then err "empty prompt"; exit 1; fi
  "$VENV/bin/python" - "$prompt" <<'PY'
import os, sys
import httpx
p = sys.argv[1]
provider = os.environ.get("AYHANX_PROVIDER", "deepseek")
base = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com").rstrip("/")
headers = {"Authorization": f"Bearer {os.environ.get('DEEPSEEK_API_KEY', 'local')}",
           "Content-Type": "application/json"}
if provider == "openrouter":
    headers["HTTP-Referer"] = "https://github.com/AyhanMansur/AyhanX-Agent"
    headers["X-Title"] = "AyhanX-Agent"
r = httpx.post(f"{base}/chat/completions", headers=headers,
               json={"model": os.environ.get("DEEPSEEK_MODEL", "deepseek-chat"),
                     "messages": [{"role": "user", "content": p}]},
               timeout=120)
if r.status_code >= 400:
    try:
        msg = r.json().get("error", {}).get("message", r.text)
    except Exception:
        msg = r.text
    hints = {401: "invalid key", 402: "no balance", 429: "rate limited"}
    hint = hints.get(r.status_code, "")
    if provider in ("ollama", "lmstudio", "vllm", "llamacpp", "localai"):
        hint = "is the local server running?"
    print(f"HTTP {r.status_code}: {msg}" + (f" ({hint})" if hint else ""),
          file=sys.stderr)
    sys.exit(1)
print(r.json()["choices"][0]["message"]["content"])
PY
}

cmd_health() {
  section "Connection check"
  "$VENV/bin/python" - <<'PY'
import os
import httpx
provider = os.environ.get("AYHANX_PROVIDER", "deepseek")
base = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com").rstrip("/")
model = os.environ.get("DEEPSEEK_MODEL", "deepseek-chat")
headers = {"Authorization": f"Bearer {os.environ.get('DEEPSEEK_API_KEY', 'local')}",
           "Content-Type": "application/json"}
if provider == "openrouter":
    headers["HTTP-Referer"] = "https://github.com/AyhanMansur/AyhanX-Agent"
    headers["X-Title"] = "AyhanX-Agent"
G, R, M, N = "\033[38;5;84m", "\033[38;5;203m", "\033[38;5;245m", "\033[0m"
print(f"  {M}provider{N}  {provider}")
print(f"  {M}endpoint{N}  {base}")
print(f"  {M}model{N}     {model}")
try:
    # for local providers, list available models
    if provider in ("ollama", "lmstudio", "vllm", "llamacpp", "localai"):
        try:
            mr = httpx.get(f"{base}/models", headers=headers, timeout=10)
            if mr.status_code == 200:
                ids = [m["id"] for m in mr.json().get("data", [])]
                if ids:
                    preview = ", ".join(ids[:4])
                    more = f" … (+{len(ids) - 4})" if len(ids) > 4 else ""
                    print(f"  {M}models{N}    {preview}{more}")
        except Exception:
            pass
    r = httpx.post(f"{base}/chat/completions", headers=headers, timeout=30,
                   json={"model": model, "max_tokens": 5,
                         "messages": [{"role": "user", "content": "say OK"}]})
    print(f"  {M}status{N}    {r.status_code}")
    j = r.json()
    if "choices" in j:
        print(f"  {M}reply{N}     {j['choices'][0]['message']['content']!r}")
        print(f"  {G}✔ connected{N}")
    else:
        print(f"  {M}body{N}      {r.text[:300]}")
        print(f"  {R}✘ failed{N}")
except Exception as e:
    hint = ""
    if provider in ("ollama", "lmstudio", "vllm", "llamacpp", "localai"):
        hint = "  → is the server running?"
    print(f"  {R}✘ {type(e).__name__}: {e}{N}{hint}")
PY
}

cmd_config() {
  section "Files"
  info "provider ${AYHANX_PROVIDER:-deepseek}  (override: --provider NAME)"
  info "config   $CONFIG_FILE"
  info "env      $ENV_FILE"
  info "provider $PROVIDER_FILE"
  info "history  $HISTORY_FILE"
  info "chats    $CHATS_DIR"
  info "log      $LOG_FILE"
  echo
  if [[ -f "$CONFIG_FILE" ]]; then
    cat "$CONFIG_FILE"; echo
  else
    info "no config yet — created on first /model, /system or /agent"
  fi
}

cmd_version() {
  section "Version"
  info "AyhanX-Agent  $VERSION"
  info "repo       $REPO_URL"
  info "provider   ${AYHANX_PROVIDER:-deepseek}"
  info "app dir    $APP_DIR"
  if [[ -x "$VENV/bin/python" ]]; then
    info "python     $("$VENV/bin/python" --version 2>&1)"
  fi
}

# ============================================================================
#  MAIN
# ============================================================================
main() {
  mkdir -p "$APP_DIR"

  # ---- parse --provider flag ----
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --provider)   shift; export AYHANX_PROVIDER="${1:-}"; shift || break ;;
      --provider=*) export AYHANX_PROVIDER="${1#*=}"; shift ;;
      --)           shift; break ;;
      ask|health|config|version|chat|tui) break ;;
      *)            break ;;
    esac
  done

  case "${1:-chat}" in
    ask)
      shift
      ensure_env; ensure_key
      cmd_ask "$@"
      ;;
    health)
      ensure_env; ensure_key
      cmd_health
      ;;
    config)
      cmd_config
      ;;
    version)
      cmd_version
      ;;
    chat|tui|"")
      ensure_env
      ensure_key
      section "Starting"
      write_tools
      write_tui
      ok "runner ready"

      sleep 0.2
      chat_loop

      print_outro
      ;;
    *)
      err "unknown mode: $1"
      info "usage: $0 [--provider deepseek|openrouter|groq|ollama|lmstudio|vllm|llamacpp|localai|auto] [chat|ask|health|config|version]"
      exit 1
      ;;
  esac
}

main "$@"
