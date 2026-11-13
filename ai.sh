#!/usr/bin/env bash
# ============================================================
#   AI RUNNER  ·  DeepSeek Terminal Chat
#   Repo:  https://github.com/AyhanMansur/AyhanX-Agent
#
#   Usage:
#     ./ai.sh                → interactive menu
#     ./ai.sh tui            → terminal chat
#     ./ai.sh ask "prompt"   → one-shot answer
#     ./ai.sh health         → test API connection
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${HOME}/.ai_platform"
VENV="${APP_DIR}/.venv"

# ---------- Cleanup on exit ----------
cleanup() {
  local code=$?
  printf '%s' "$RS" 2>/dev/null || true
  stty sane 2>/dev/null || true
  exit "$code"
}
trap cleanup EXIT INT TERM

# ---------- Palette ----------
if [[ -t 1 ]]; then
  B1=$'\e[38;5;33m'; B2=$'\e[38;5;39m'; B3=$'\e[38;5;45m'; B4=$'\e[38;5;51m'
  BD=$'\e[1m'; DM=$'\e[2m'; RS=$'\e[0m'
else
  B1= B2= B3= B4= BD= DM= RS=
fi

# ---------- Banner ----------
print_banner() {
  local lines=(
'▄▄▄     ▓██   ██▓ ██░ ██  ▄▄▄       ███▄    █ ▒██   ██▒ ▄▄▄        ▄████ ▓█████  ███▄    █ ▄▄▄█████▓'
'▒████▄    ▒██  ██▒▓██░ ██▒▒████▄     ██ ▀█   █ ▒▒ █ █ ▒░▒████▄     ██▒ ▀█▒▓█   ▀  ██ ▀█   █ ▓  ██▒ ▓▒'
'▒██  ▀█▄   ▒██ ██░▒██▀▀██░▒██  ▀█▄  ▓██  ▀█ ██▒░░  █   ░▒██  ▀█▄  ▒██░▄▄▄░▒███   ▓██  ▀█ ██▒▒ ▓██░ ▒░'
'░██▄▄▄▄██  ░ ▐██▓░░▓█ ░██ ░██▄▄▄▄██ ▓██▒  ▐▌██▒ ░ █ █ ▒ ░██▄▄▄▄██ ░▓█  ██▓▒██████▓██▒  ▐▌██▒░ ▓██▓ ░'
' ▓█   ▓██▒ ░ ██▒▓░░▒▓██▒  ▓█   ▓██▒▒██░   ▓██░ ▒░ ░ ░▒   ▓█   ▓██▒░▒▓███▀▒░▒░ ░ ▒▓ ░▒▓░░ ▒▒   ▓▒█░'
' ▒▒   ▓▒█░  ██▒▒▒ ▒▒ ▓▒█░ ▒▒   ▓▒█░░ ▒░   ▒ ▒   ░░   ░░   ▒▒   ▓▒█░ ░▒   ▒  ░▒ ░ ▒▒  ░▒░  ▒▒   ▓▒█░'
'  ▒   ▒▒ ░▓██ ░▒░  ▒ ▒▒ ░  ▒   ▒▒ ░░ ░░   ░ ▒░   ░    ░   ▒   ▒▒ ░  ░   ░  ░░   ░░  ░ ░   ▒   ▒▒ ░'
'  ░   ▒   ▒ ▒ ░░   ░ ░     ░   ▒      ░   ░ ░    ░        ░   ▒   ░ ░   ░   ░   ░  ░   ░  ░   ▒   '
'      ░   ░ ░      ░           ░          ░                ░   ░        ░   ░   ░           ░  ░'
  )
  local colors=("$B1" "$B1" "$B2" "$B2" "$B3" "$B3" "$B4" "$B4" "$B4")
  echo
  for i in "${!lines[@]}"; do
    printf '%s%s%s\n' "${BD}${colors[$i]}" "${lines[$i]}" "$RS"
  done
  printf '%-100s\n' | sed 's/ /─/g' | sed "s/^/${DM}${B2}/; s/$/${RS}/"
  printf '  %s%sAI Runner%s   %s·%s   %sDeepSeek Terminal%s   %s·%s   %sv1.0%s\n\n' \
    "$BD" "$B4" "$RS" "$DM" "$RS" "$BD" "$RS" "$DM" "$RS" "$DM" "$RS"
}

# ---------- Helpers ----------
section() { printf '%s%s▸ %s%s\n' "$BD" "$B3" "$*" "$RS"; }
ok()      { printf '%s  ✓%s %s\n' "$B4" "$RS" "$*"; }
warn()    { printf '%s  !%s %s\n' "$B3" "$RS" "$*"; }
err()     { printf '%s  ✗%s %s\n' "$B1" "$RS" "$*" >&2; }

# ============================================================
#  ENVIRONMENT
# ============================================================
find_python() {
  for c in python3.12 python3.11 python3.10 python3.13 python3; do
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

ensure_env() {
  section "Environment"
  local PY
  if ! PY="$(find_python)"; then
    warn "no Python 3.10–3.13 → installing uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 || true
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    if command -v uv >/dev/null 2>&1; then
      uv python install 3.12 >/dev/null 2>&1 || true
      PY="$(uv python find 3.12 2>/dev/null || true)"
    fi
    [[ -z "$PY" ]] && { err "cannot get Python 3.10–3.13"; exit 1; }
  fi
  ok "python → $PY"

  local rebuild=0
  [[ -d "$VENV" ]] || rebuild=1
  [[ -x "$VENV/bin/python" ]] || rebuild=1
  if (( !rebuild )); then
    "$VENV/bin/python" -c 'import httpx,rich' 2>/dev/null || rebuild=1
  fi
  if (( rebuild )); then
    section "Installing packages"
    rm -rf "$VENV"; mkdir -p "$APP_DIR"
    "$PY" -m venv "$VENV"
    "$VENV/bin/pip" install -q --upgrade pip --timeout 10 --retries 1 2>/dev/null || true

    local mirrors=(
      "https://pypi.org/simple"
      "https://mirror-pypi.runflare.com/simple"
      "https://mirrors.aliyun.com/pypi/simple"
      "https://pypi.tuna.tsinghua.edu.cn/simple"
    )
    local chosen=""
    for m in "${mirrors[@]}"; do
      if timeout 6 curl -sSI -o /dev/null "$m/" 2>/dev/null; then chosen="$m"; break; fi
    done
    [[ -z "$chosen" ]] && { err "no PyPI mirror reachable — fix DNS/internet"; exit 1; }
    ok "using index: $chosen"

    local host
    host="$(echo "$chosen" | awk -F/ '{print $3}')"
    "$VENV/bin/pip" install \
      --index-url "$chosen" --trusted-host "$host" \
      --timeout 20 --retries 3 \
      httpx rich
    ok "packages installed"
  else
    ok "venv ready"
  fi
}

ensure_key() {
  section "API key"
  [[ -f "$APP_DIR/.env" ]] && { set -o allexport; . "$APP_DIR/.env"; set +o allexport; }
  if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
    warn "DEEPSEEK_API_KEY not set"
    read -r -p "  paste your DeepSeek key (sk-...): " DEEPSEEK_API_KEY
    [[ -z "$DEEPSEEK_API_KEY" ]] && { err "required"; exit 1; }
    printf 'DEEPSEEK_API_KEY=%s\n' "$DEEPSEEK_API_KEY" > "$APP_DIR/.env"
    chmod 600 "$APP_DIR/.env"
    ok "saved to $APP_DIR/.env"
  else
    ok "key loaded"
  fi
  export DEEPSEEK_API_KEY
  export DEEPSEEK_BASE_URL="${DEEPSEEK_BASE_URL:-https://api.deepseek.com}"
  export DEEPSEEK_MODEL="${DEEPSEEK_MODEL:-deepseek-chat}"
}

# ============================================================
#  WRITE: TUI
# ============================================================
write_tui() {
  cat > "$APP_DIR/tui.py" <<'PYEOF'
"""AI Runner — terminal chat for DeepSeek with Rich."""
import json
import os
import sys

import httpx
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt
from rich.rule import Rule

API_KEY = os.environ["DEEPSEEK_API_KEY"]
BASE_URL = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
MODEL = os.environ.get("DEEPSEEK_MODEL", "deepseek-chat")

console = Console()

# ---------- Error hints ----------
HINTS = {
    401: "invalid API key — create one at platform.deepseek.com/api_keys",
    402: "insufficient balance — top up at platform.deepseek.com/top_up",
    429: "rate limited — wait a few seconds",
    500: "server error — try again",
    503: "service unavailable — try again later",
}


def parse_error(status: int, body: str) -> str:
    msg = body
    try:
        j = json.loads(body)
        msg = j.get("error", {}).get("message", body)
    except Exception:
        pass
    hint = HINTS.get(status, "")
    return f"HTTP {status}: {msg}" + (f"\n→ {hint}" if hint else "")


def stream_reply(messages):
    headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
    payload = {"model": MODEL, "messages": messages, "stream": True}
    full = []
    console.print("[bold cyan]AI ▸[/] ", end="")
    try:
        with httpx.Client(timeout=120) as client:
            with client.stream("POST", f"{BASE_URL}/chat/completions",
                               headers=headers, json=payload) as r:
                if r.status_code >= 400:
                    body = r.read().decode(errors="replace")
                    console.print(f"[red]\n[!] {parse_error(r.status_code, body)}[/]")
                    return ""
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
                    chunk = delta.get("content") or ""
                    if chunk:
                        full.append(chunk)
                        console.print(chunk, end="", style="green")
        console.print()
        return "".join(full)
    except httpx.RequestError as e:
        console.print(f"[red]\n[!] network error: {e}[/]")
        return ""


def banner():
    console.print(Panel.fit(
        "[bold bright_blue]AI Runner · Terminal[/]\n"
        f"[dim]{MODEL} · /help for commands[/]",
        border_style="blue",
    ))


def help_text():
    console.print(Panel(
        "[cyan]/new[/]     start a new conversation\n"
        "[cyan]/help[/]    this message\n"
        "[cyan]/model[/]   show model\n"
        "[cyan]/clear[/]   clear screen\n"
        "[cyan]/exit[/]    quit",
        title="commands", border_style="blue",
    ))


def main():
    banner()
    history = []
    while True:
        try:
            text = Prompt.ask("[bold blue]you ▸[/]").strip()
        except (EOFError, KeyboardInterrupt):
            console.print("\n[dim]bye[/]")
            return
        if not text:
            continue
        if text.startswith("/"):
            cmd = text.lower()
            if cmd in ("/exit", "/quit"):
                return
            if cmd == "/help":
                help_text(); continue
            if cmd == "/clear":
                console.clear(); banner(); continue
            if cmd == "/model":
                console.print(f"[cyan]model:[/] {MODEL}"); continue
            if cmd == "/new":
                history.clear(); console.print("[dim]new conversation[/]"); continue
            console.print("[red]unknown command[/]"); continue

        history.append({"role": "user", "content": text})
        answer = stream_reply(history)
        if answer:
            history.append({"role": "assistant", "content": answer})
        else:
            history.pop()
            console.print("[dim]reply failed — try again[/]")
        console.print(Rule(style="bright_black"))


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n[dim]bye[/]")
PYEOF
}

# ============================================================
#  COMMANDS
# ============================================================
show_menu() {
  echo
  section "Choose mode"
  cat <<EOF

   ${B4}1${RS})  ${BD}tui${RS}     → terminal chat (Rich)
   ${B4}2${RS})  ${BD}ask${RS}     → one-shot: ask a prompt
   ${B4}3${RS})  ${BD}health${RS}  → test DeepSeek API
   ${B4}q${RS})  quit

EOF
}

cmd_tui() {
  "$VENV/bin/python" "$APP_DIR/tui.py" || true
  echo
  section "Terminal chat closed"
  printf '%s  press Enter to return to menu…%s\n' "$DM" "$RS"
  read -r _ || true
}

cmd_ask() {
  local prompt="$*"
  [[ -z "$prompt" ]] && { err "empty prompt"; exit 1; }
  "$VENV/bin/python" - "$prompt" <<'PY'
import json, os, sys
import httpx
p = sys.argv[1]
base = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
h = {"Authorization": f"Bearer {os.environ['DEEPSEEK_API_KEY']}",
     "Content-Type": "application/json"}
r = httpx.post(
    f"{base}/chat/completions", headers=h,
    json={"model": os.environ.get("DEEPSEEK_MODEL", "deepseek-chat"),
          "messages": [{"role": "user", "content": p}]},
    timeout=60,
)
if r.status_code >= 400:
    try:
        msg = r.json().get("error", {}).get("message", r.text)
    except Exception:
        msg = r.text
    print(f"HTTP {r.status_code}: {msg}", file=sys.stderr); sys.exit(1)
print(r.json()["choices"][0]["message"]["content"])
PY
}

cmd_health() {
  "$VENV/bin/python" - <<'PY'
import os
import httpx
base = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
h = {"Authorization": f"Bearer {os.environ['DEEPSEEK_API_KEY']}",
     "Content-Type": "application/json"}
try:
    r = httpx.post(
        f"{base}/chat/completions", headers=h,
        json={"model": os.environ.get("DEEPSEEK_MODEL", "deepseek-chat"),
              "messages": [{"role": "user", "content": "say OK"}],
              "max_tokens": 5},
        timeout=30,
    )
    print(f"status: {r.status_code}")
    print(f"body:   {r.text[:300]}")
except Exception as e:
    print(f"error:  {e}")
PY
}

# ============================================================
#  MAIN
# ============================================================
print_banner
ensure_env
ensure_key
write_tui

case "${1:-menu}" in
  tui)   cmd_tui ;;
  ask)   shift; cmd_ask "$@" ;;
  health) cmd_health ;;
  menu|"")
    while true; do
      show_menu
      read -r -p "  > " choice
      case "$choice" in
        1) cmd_tui ;;
        2) read -r -p "  prompt: " p; cmd_ask "$p" ;;
        3) cmd_health ;;
        q|Q) exit 0 ;;
        *) warn "unknown choice" ;;
      esac
    done
    ;;
  *)  err "unknown mode: $1"; echo "usage: $0 [tui|ask|health|menu]"; exit 1 ;;
esac
