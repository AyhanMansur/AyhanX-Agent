#!/usr/bin/env bash
# ============================================================================
#   AI RUNNER  ·  DeepSeek Terminal Chat  ·  Claude Code Style
#   Repository:  https://github.com/AyhanMansur/AyhanX-Agent
#   Version:     3.1.0
#
#   Straight-to-chat terminal AI client. Clears the screen after setup
#   and shows only the banner + chat prompt.
#
#   Usage:
#     ./ai.sh                → banner + straight to chat
#     ./ai.sh ask "prompt"   → one-shot answer
#     ./ai.sh health         → test API connection
#     ./ai.sh config         → show config
#     ./ai.sh version        → print version
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${HOME}/.ai_platform"
VENV="${APP_DIR}/.venv"
RUNNER_DIR="${APP_DIR}/runner"
CONFIG_FILE="${APP_DIR}/config.json"
ENV_FILE="${APP_DIR}/.env"
HISTORY_FILE="${APP_DIR}/history.txt"
CHATS_DIR="${APP_DIR}/chats"
REPO_URL="https://github.com/AyhanMansur/AyhanX-Agent"
VERSION="3.1.0"

# ---------- Cleanup trap ----------
cleanup() {
  local code=$?
  printf '%s' "$RS" 2>/dev/null || true
  stty sane 2>/dev/null || true
  exit "$code"
}
trap cleanup EXIT INT TERM

# ---------- ANSI palette (blue gradient) ----------
if [[ -t 1 ]]; then
  B1=$'\e[38;5;33m'; B2=$'\e[38;5;39m'; B3=$'\e[38;5;45m'; B4=$'\e[38;5;51m'
  BD=$'\e[1m'; DM=$'\e[2m'; RS=$'\e[0m'
  RD=$'\e[91m'; YL=$'\e[93m'; GR=$'\e[92m'
else
  B1= B2= B3= B4= BD= DM= RS= RD= YL= GR=
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
  printf '  %s%sAI Runner%s  %s·%s  %sDeepSeek Terminal%s  %s·%s  %sv%s%s\n' \
    "$BD" "$B4" "$RS" "$DM" "$RS" "$BD" "$RS" "$DM" "$RS" "$DM" "$VERSION" "$RS"
  printf '  %s%s%s%s\n' "$DM" "$REPO_URL" "$RS" ""
  printf '%s\n' ""
  printf '%-100s\n' | sed 's/ /─/g' | sed "s/^/${DM}${B2}/; s/$/${RS}/"
  echo
}

# ---------- Logging helpers ----------
section() { printf '%s%s▸ %s%s\n' "$BD" "$B3" "$*" "$RS"; }
ok()      { printf '%s  ✓%s %s\n' "$B4" "$RS" "$*"; }
warn()    { printf '%s  !%s %s\n' "$B3" "$RS" "$*"; }
err()     { printf '%s  ✗%s %s\n' "$B1" "$RS" "$*" >&2; }
info()    { printf '%s  ·%s %s\n' "$DM" "$RS" "$*"; }

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

  local PY
  if ! PY="$(find_python)"; then
    warn "no Python 3.10–3.13 on system → installing uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 || true
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    if command -v uv >/dev/null 2>&1; then
      uv python install 3.12 >/dev/null 2>&1 || true
      PY="$(uv python find 3.12 2>/dev/null || true)"
    fi
    [[ -z "$PY" ]] && { err "cannot obtain Python 3.10–3.13"; exit 1; }
  fi
  ok "python → $PY"

  local rebuild=0
  [[ -d "$VENV" ]] || rebuild=1
  [[ -x "$VENV/bin/python" ]] || rebuild=1
  if (( !rebuild )); then
    "$VENV/bin/python" -c 'import httpx,rich,prompt_toolkit' 2>/dev/null || rebuild=1
  fi

  if (( rebuild )); then
    section "Installing packages"
    rm -rf "$VENV"
    mkdir -p "$APP_DIR" "$RUNNER_DIR" "$CHATS_DIR"
    "$PY" -m venv "$VENV"
    "$VENV/bin/pip" install -q --upgrade pip --timeout 10 --retries 1 2>/dev/null || true

    local mirror
    if ! mirror="$(pick_pypi_mirror)"; then
      err "no PyPI mirror reachable — fix DNS or internet"
      echo "    try: echo 'nameserver 1.1.1.1' > /etc/resolv.conf" >&2
      exit 1
    fi
    ok "using index: $mirror"

    local host
    host="$(echo "$mirror" | awk -F/ '{print $3}')"
    "$VENV/bin/pip" install \
      --index-url "$mirror" --trusted-host "$host" \
      --timeout 20 --retries 3 \
      httpx rich prompt_toolkit
    ok "packages installed"
  else
    ok "venv ready"
  fi
}

ensure_key() {
  section "API key"
  [[ -f "$ENV_FILE" ]] && { set -o allexport; . "$ENV_FILE"; set +o allexport; }
  if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
    warn "DEEPSEEK_API_KEY not set"
    read -r -p "  paste your DeepSeek key (sk-...): " DEEPSEEK_API_KEY
    [[ -z "$DEEPSEEK_API_KEY" ]] && { err "required"; exit 1; }
    printf 'DEEPSEEK_API_KEY=%s\n' "$DEEPSEEK_API_KEY" > "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    ok "saved to $ENV_FILE"
  else
    ok "key loaded"
  fi
  export DEEPSEEK_API_KEY
  export DEEPSEEK_BASE_URL="${DEEPSEEK_BASE_URL:-https://api.deepseek.com}"
  export DEEPSEEK_MODEL="${DEEPSEEK_MODEL:-deepseek-chat}"
}

# ============================================================================
#  GENERATE: runner/tools.py
# ============================================================================
write_tools() {
  mkdir -p "$RUNNER_DIR"
  cat > "$RUNNER_DIR/tools.py" <<'PYEOF'
"""Tool definitions and implementations for AI Runner agent mode."""
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
#  GENERATE: runner/tui.py
# ============================================================================
write_tui() {
  cat > "$RUNNER_DIR/tui.py" <<'PYEOF'
"""AI Runner TUI — Claude Code style terminal chat for DeepSeek."""
import json
import os
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

import httpx
from prompt_toolkit import PromptSession
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.formatted_text import HTML
from prompt_toolkit.history import FileHistory
from prompt_toolkit.key_binding import KeyBindings
from prompt_toolkit.styles import Style
from rich.console import Console
from rich.panel import Panel
from rich.text import Text

from .tools import TOOL_IMPLS, TOOL_SPECS

APP_DIR = Path(os.environ.get("APP_DIR", Path.home() / ".ai_platform"))
CONFIG_PATH = APP_DIR / "config.json"
HISTORY_PATH = APP_DIR / "history.txt"
CHATS_DIR = APP_DIR / "chats"
CHATS_DIR.mkdir(parents=True, exist_ok=True)

MODELS = ["deepseek-chat", "deepseek-reasoner"]
QUIET = os.environ.get("AI_RUNNER_QUIET") == "1"


@dataclass
class Config:
    model: str = "deepseek-chat"
    system_prompt: str = ""
    agent_mode: bool = False
    max_context_messages: int = 40

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
    messages: list[dict[str, str]] = field(default_factory=list)
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
            raise FileNotFoundError(f"chat not found: {name}")
        conv = cls()
        conv.messages = json.loads(path.read_text())
        return conv

    def to_api(self) -> list[dict[str, str]]:
        return [m for m in self.messages if m.get("content", "").strip()]


class DeepSeekClient:
    def __init__(self, api_key: str, base_url: str, model: str):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.model = model

    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"}

    def _hint(self, status: int) -> str:
        return {
            401: "invalid API key — platform.deepseek.com/api_keys",
            402: "insufficient balance — platform.deepseek.com/top_up",
            429: "rate limited — wait a few seconds",
        }.get(status, "")

    def _error(self, status: int, body: str) -> str:
        msg = body
        try:
            j = json.loads(body)
            msg = j.get("error", {}).get("message", body)
        except Exception:
            pass
        hint = self._hint(status)
        return f"HTTP {status}: {msg}" + (f"\n→ {hint}" if hint else "")

    def chat(self, messages, tools=None, stream=True):
        payload: dict[str, Any] = {
            "model": self.model, "messages": messages, "stream": stream,
        }
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
                with client.stream(
                    "POST", f"{self.base_url}/chat/completions",
                    headers=self._headers(), json=payload,
                ) as r:
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


console = Console()

PROMPT_STYLE = Style.from_dict({
    "arrow": "ansibrightcyan bold",
})

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


def chat_header(model: str, agent: bool) -> None:
    agent_badge = " [bold yellow]· AGENT[/]" if agent else ""
    console.print(
        f"[bold cyan]✻[/] [bold]DeepSeek[/]  [dim]·[/]  "
        f"[white]{model}[/]{agent_badge}  "
        f"[dim]·  /help for commands  ·  /exit to quit[/]"
    )
    console.print()


def help_panel() -> None:
    console.print(Panel(
        Text.from_markup(
            "[bold cyan]Commands[/]\n"
            "[cyan]/help[/]        this message\n"
            "[cyan]/new[/]         new conversation\n"
            "[cyan]/clear[/]       clear screen\n"
            "[cyan]/model[/]       list/switch models\n"
            "[cyan]/system[/]      set/show system prompt\n"
            "[cyan]/agent[/]       toggle agent mode\n"
            "[cyan]/save NAME[/]   save conversation\n"
            "[cyan]/load NAME[/]   load conversation\n"
            "[cyan]/chats[/]       list saved chats\n"
            "[cyan]/history[/]     show conversation\n"
            "[cyan]/info[/]        config summary\n"
            "[cyan]/exit[/]        quit\n\n"
            "[bold cyan]Keys[/]\n"
            "[dim]Enter send · Shift+Enter newline · ↑↓ history[/]\n"
            "[dim]Ctrl+C cancel response · Ctrl+D exit[/]"
        ),
        title="[bold cyan]commands[/]",
        border_style="dim cyan",
        padding=(1, 2),
    ))


def stream_response(client, conv, cfg) -> str:
    msgs = conv.to_api()
    if cfg.system_prompt:
        msgs = [{"role": "system", "content": cfg.system_prompt}] + msgs

    console.print("[cyan bold]⏺[/] ", end="", highlight=False)
    full: list[str] = []
    try:
        for chunk in client.chat(msgs, stream=True):
            if "error" in chunk:
                console.print(f"[red]{chunk['error']}[/]")
                return ""
            if "text" in chunk:
                full.append(chunk["text"])
                console.print(chunk["text"], end="",
                              highlight=False, markup=False, soft_wrap=True)
    except httpx.RequestError as e:
        console.print(f"[red]network error: {e}[/]")
        return ""
    except KeyboardInterrupt:
        console.print("\n[dim]^C cancelled[/]")
        return "".join(full)
    console.print()
    return "".join(full)


def run_agent(client, conv, cfg) -> str:
    msgs = conv.to_api()
    if cfg.system_prompt:
        msgs = [{"role": "system", "content": cfg.system_prompt}] + msgs

    console.print("[cyan bold]⏺[/] ", end="", highlight=False)

    for _ in range(8):
        try:
            resp = client.chat(msgs, tools=TOOL_SPECS, stream=False)
        except httpx.RequestError as e:
            console.print(f"[red]network error: {e}[/]")
            return ""

        if isinstance(resp, dict) and "error" in resp:
            console.print(f"[red]{resp['error']}[/]")
            return ""

        msg = resp.get("choices", [{}])[0].get("message", {})
        tool_calls = msg.get("tool_calls") or []

        if not tool_calls:
            content = msg.get("content") or ""
            console.print(content)
            return content

        if msg.get("content"):
            console.print(msg["content"])

        msgs.append(msg)

        for tc in tool_calls:
            fn = tc.get("function", {})
            name = fn.get("name", "?")
            try:
                args = json.loads(fn.get("arguments") or "{}")
            except json.JSONDecodeError:
                args = {}

            console.print(
                f"[yellow]  ⚙[/] [dim]{name}[/]"
                f"[dim]({json.dumps(args, ensure_ascii=False)[:80]})[/]"
            )

            impl = TOOL_IMPLS.get(name)
            if impl:
                try:
                    result = impl(args)
                except Exception as e:
                    result = f"Error: {type(e).__name__}: {e}"
            else:
                result = f"Error: unknown tool '{name}'"

            preview = result[:120].replace("\n", " ")
            if len(result) > 120:
                preview += "…"
            console.print(f"[dim]    → {preview}[/]")

            msgs.append({"role": "tool",
                         "tool_call_id": tc.get("id", ""),
                         "content": result})

    console.print("[yellow]  ⚠ max tool iterations reached[/]")
    return ""


def main() -> int:
    api_key = os.environ.get("DEEPSEEK_API_KEY")
    if not api_key:
        console.print("[red]DEEPSEEK_API_KEY not set[/]")
        return 1

    base_url = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
    cfg = Config.load()
    if os.environ.get("DEEPSEEK_MODEL"):
        cfg.model = os.environ["DEEPSEEK_MODEL"]

    conv = Conversation()
    if not QUIET:
        chat_header(cfg.model, cfg.agent_mode)

    completer = WordCompleter(
        ["/help", "/new", "/clear", "/model", "/system", "/agent",
         "/save", "/load", "/chats", "/history", "/info", "/exit"],
        ignore_case=True,
    )

    session = PromptSession(
        key_bindings=KB,
        style=PROMPT_STYLE,
        history=FileHistory(str(HISTORY_PATH)),
        completer=completer,
        complete_while_typing=True,
    )

    while True:
        try:
            raw = session.prompt(HTML("<arrow>❯ </arrow>"))
        except KeyboardInterrupt:
            console.print("[dim]^C[/]")
            continue
        except EOFError:
            console.print("[dim]bye[/]")
            return 0

        text = raw.strip()
        if not text:
            continue

        # ---- Slash commands ----
        if text.startswith("/"):
            parts = text.split(maxsplit=1)
            cmd = parts[0].lower()
            args = parts[1].split() if len(parts) > 1 else []

            if cmd in ("/exit", "/quit"):
                console.print("[dim]bye[/]")
                return 0
            elif cmd == "/help":
                help_panel()
            elif cmd == "/clear":
                console.clear()
                chat_header(cfg.model, cfg.agent_mode)
            elif cmd == "/new":
                conv = Conversation()
                console.print("[dim]· new conversation[/]")
            elif cmd == "/model":
                if not args:
                    console.print(f"[cyan]current:[/] {cfg.model}")
                    console.print(f"[dim]available: {', '.join(MODELS)}[/]")
                elif args[0] in MODELS:
                    cfg.model = args[0]; cfg.save()
                    console.print(f"[green]→ model set to[/] {args[0]}")
                else:
                    console.print(f"[red]unknown model: {args[0]}[/]")
            elif cmd == "/system":
                txt = " ".join(args).strip()
                if not txt:
                    if cfg.system_prompt:
                        console.print(Panel(cfg.system_prompt,
                                            title="system prompt",
                                            border_style="dim"))
                    else:
                        console.print("[dim]no system prompt set[/]")
                else:
                    cfg.system_prompt = txt; cfg.save()
                    console.print("[green]→ system prompt set[/]")
            elif cmd == "/agent":
                cfg.agent_mode = not cfg.agent_mode; cfg.save()
                state = "[green]ON[/]" if cfg.agent_mode else "[red]OFF[/]"
                console.print(f"→ agent mode: {state}")
            elif cmd == "/save":
                name = args[0] if args else f"chat-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
                try:
                    p = conv.save(name)
                    console.print(f"[green]→ saved to[/] {p}")
                except Exception as e:
                    console.print(f"[red]save failed: {e}[/]")
            elif cmd == "/load":
                if not args:
                    console.print("[red]usage: /load NAME[/]")
                else:
                    try:
                        conv = Conversation.load(args[0])
                        console.print(f"[green]→ loaded[/] {len(conv.messages)} messages")
                    except FileNotFoundError as e:
                        console.print(f"[red]{e}[/]")
            elif cmd == "/chats":
                chats = sorted(CHATS_DIR.glob("*.json"))
                if not chats:
                    console.print("[dim]no saved chats[/]")
                else:
                    for p in chats:
                        console.print(f"  [cyan]{p.stem}[/]  "
                                      f"[dim]({p.stat().st_size} bytes)[/]")
            elif cmd == "/history":
                for m in conv.messages:
                    if m["role"] == "user":
                        console.print(f"[bold cyan]❯[/] {m['content']}")
                    elif m["role"] == "assistant":
                        console.print(f"[cyan bold]⏺[/] {m['content']}")
            elif cmd == "/info":
                console.print(Panel(Text.from_markup(
                    f"[bold]model[/]         {cfg.model}\n"
                    f"[bold]agent mode[/]    {'ON' if cfg.agent_mode else 'OFF'}\n"
                    f"[bold]system prompt[/] {'set' if cfg.system_prompt else 'none'}\n"
                    f"[bold]messages[/]      {len(conv.messages)}\n"
                    f"[bold]config[/]        {CONFIG_PATH}\n"
                    f"[bold]chats[/]         {CHATS_DIR}"
                ), title="[bold cyan]info[/]", border_style="dim cyan",
                    padding=(1, 2)))
            else:
                console.print(f"[red]unknown command: {cmd}[/]")
            continue

        # ---- Normal message ----
        conv.add_user(text)
        conv.trim(cfg.max_context_messages)

        client = DeepSeekClient(api_key, base_url, cfg.model)

        try:
            if cfg.agent_mode:
                answer = run_agent(client, conv, cfg)
            else:
                answer = stream_response(client, conv, cfg)
        except KeyboardInterrupt:
            console.print("\n[dim]^C[/]")
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

cmd_ask() {
  local prompt="$*"
  [[ -z "$prompt" ]] && { err "empty prompt"; exit 1; }
  "$VENV/bin/python" - "$prompt" <<'PY'
import json, os, sys
import httpx
p = sys.argv[1]
base = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com").rstrip("/")
h = {"Authorization": f"Bearer {os.environ['DEEPSEEK_API_KEY']}",
     "Content-Type": "application/json"}
r = httpx.post(
    f"{base}/chat/completions", headers=h,
    json={"model": os.environ.get("DEEPSEEK_MODEL", "deepseek-chat"),
          "messages": [{"role": "user", "content": p}]},
    timeout=120,
)
if r.status_code >= 400:
    try:
        msg = r.json().get("error", {}).get("message", r.text)
    except Exception:
        msg = r.text
    hints = {401: "invalid key", 402: "no balance", 429: "rate limited"}
    hint = hints.get(r.status_code, "")
    print(f"HTTP {r.status_code}: {msg}" + (f" ({hint})" if hint else ""),
          file=sys.stderr)
    sys.exit(1)
print(r.json()["choices"][0]["message"]["content"])
PY
}

cmd_health() {
  "$VENV/bin/python" - <<'PY'
import json, os
import httpx
base = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com").rstrip("/")
model = os.environ.get("DEEPSEEK_MODEL", "deepseek-chat")
h = {"Authorization": f"Bearer {os.environ['DEEPSEEK_API_KEY']}",
     "Content-Type": "application/json"}
try:
    r = httpx.post(
        f"{base}/chat/completions", headers=h,
        json={"model": model,
              "messages": [{"role": "user", "content": "say OK"}],
              "max_tokens": 5},
        timeout=30,
    )
    print(f"endpoint: {base}")
    print(f"model:    {model}")
    print(f"status:   {r.status_code}")
    try:
        j = r.json()
        if "choices" in j:
            txt = j["choices"][0]["message"]["content"]
            print(f"reply:    {txt!r}")
            print("result:   [OK]")
        else:
            print(f"body:     {r.text[:300]}")
            print("result:   [FAIL]")
    except Exception:
        print(f"body:     {r.text[:300]}")
except Exception as e:
    print(f"error:    {type(e).__name__}: {e}")
    print("result:   [FAIL]")
PY
}

cmd_config() {
  section "Config"
  if [[ -f "$CONFIG_FILE" ]]; then
    cat "$CONFIG_FILE"
  else
    info "no config yet — created on first /model, /system, /agent use"
  fi
  echo
  info "config file: $CONFIG_FILE"
  info "chats dir:   $CHATS_DIR"
  info "env file:    $ENV_FILE"
  info "history:     $HISTORY_FILE"
}

cmd_version() {
  section "Version"
  echo "  ai-runner: $VERSION"
  echo "  repo:      $REPO_URL"
  echo "  app dir:   $APP_DIR"
  if [[ -x "$VENV/bin/python" ]]; then
    echo "  python:    $("$VENV/bin/python" --version 2>&1)"
  fi
}

# ============================================================================
#  MAIN — banner, setup, clear, chat
# ============================================================================
main() {
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
      # 1. setup phase — visible output while installing
      ensure_env
      ensure_key
      section "Preparing runner"
      write_tools
      write_tui
      ok "runner ready"

      # 2. clear screen, show only banner
      sleep 0.15
      clear
      print_banner

      # 3. hand off to chat (skips the Rich header via AI_RUNNER_QUIET)
      export AI_RUNNER_QUIET=1
      cmd_tui

      # 4. after chat exits
      echo
      section "Chat closed"
      printf '%s  goodbye · %s%s\n' "$DM" "$REPO_URL" "$RS"
      ;;
    *)
      err "unknown mode: $1"
      echo "usage: $0 [chat|ask|health|config|version]"
      exit 1
      ;;
  esac
}

main "$@"
