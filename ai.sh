#!/usr/bin/env bash
# ============================================================
#   AI RUNNER  ·  DeepSeek  ·  Web + Terminal UI
#   Repo:  https://github.com/AyhanMansur/AyhanX-Agent
#
#   Usage:
#     ./ai.sh                → interactive menu
#     ./ai.sh web [port]     → browser UI on :8080
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
  printf '  %s%sAI Runner%s   %s·%s   %sDeepSeek%s   %s·%s   %sWeb + Terminal%s   %s·%s   %sv1.0%s\n\n' \
    "$BD" "$B4" "$RS" "$DM" "$RS" "$BD" "$RS" "$DM" "$RS" "$DM" "$RS" \
    "$DM" "$RS" "$DM" "$RS"
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
    "$VENV/bin/python" -c 'import fastapi,uvicorn,httpx,pydantic,rich' 2>/dev/null || rebuild=1
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
      fastapi "uvicorn[standard]" httpx pydantic rich
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
}

# ============================================================
#  WRITE: TUI
# ============================================================
write_tui() {
  cat > "$APP_DIR/tui.py" <<'PYEOF'
"""Terminal chat client for DeepSeek with Rich."""
import json
import os

import httpx
from rich.console import Console
from rich.panel import Panel
from rich.prompt import Prompt
from rich.rule import Rule

API_KEY = os.environ["DEEPSEEK_API_KEY"]
BASE_URL = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
MODEL = os.environ.get("DEEPSEEK_MODEL", "deepseek-chat")

console = Console()


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
                    console.print(f"[red]\n[!] HTTP {r.status_code}: {body}[/]")
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
        "[dim]DeepSeek Chat · /help for commands[/]",
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
#  WRITE: WEB APP
# ============================================================
write_web() {
  cat > "$APP_DIR/app.py" <<'PYEOF'
"""AI Runner — DeepSeek Chat + Agent (FastAPI backend + single HTML UI)."""
import json
import os
import sqlite3
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.responses import HTMLResponse, StreamingResponse
from pydantic import BaseModel

API_KEY = os.environ["DEEPSEEK_API_KEY"]
BASE_URL = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
MODEL = os.environ.get("DEEPSEEK_MODEL", "deepseek-chat")
DB_PATH = Path(os.environ.get("DB_PATH", Path.home() / ".ai_platform" / "chats.db"))
DB_PATH.parent.mkdir(parents=True, exist_ok=True)


def db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with db() as c:
        c.executescript(
            """
            CREATE TABLE IF NOT EXISTS conversations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL DEFAULT 'New chat',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                conversation_id INTEGER NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            );
            """
        )


TOOLS = [
    {"type": "function", "function": {
        "name": "get_current_time",
        "description": "Return current UTC date/time in ISO format.",
        "parameters": {"type": "object", "properties": {}},
    }},
    {"type": "function", "function": {
        "name": "calculate",
        "description": "Evaluate a simple arithmetic expression.",
        "parameters": {"type": "object", "properties": {
            "expression": {"type": "string", "description": "e.g. '2+3*4'"}
        }, "required": ["expression"]},
    }},
    {"type": "function", "function": {
        "name": "list_files",
        "description": "List files in the user's home directory.",
        "parameters": {"type": "object", "properties": {
            "subdir": {"type": "string", "description": "optional subfolder"}
        }},
    }},
]


def tool_get_current_time(_a):
    return datetime.now(timezone.utc).isoformat()


def tool_calculate(a):
    expr = a.get("expression", "")
    if not expr or any(ch not in "0123456789+-*/(). %" for ch in expr):
        return f"Error: invalid expression {expr!r}"
    try:
        return str(eval(expr, {"__builtins__": {}}, {}))
    except Exception as e:
        return f"Error: {e}"


def tool_list_files(a):
    base = Path.home()
    target = (base / a.get("subdir", "")).resolve()
    if target != base and base not in target.parents:
        return "Error: access denied"
    if not target.exists():
        return f"Error: {target} not found"
    items = sorted(target.iterdir())[:100]
    return json.dumps([f"{p.name}{'/' if p.is_dir() else ''}" for p in items])


TOOL_IMPL = {
    "get_current_time": tool_get_current_time,
    "calculate": tool_calculate,
    "list_files": tool_list_files,
}


async def deepseek_chat(messages, tools=None, stream=False):
    payload = {"model": MODEL, "messages": messages, "stream": stream}
    if tools:
        payload["tools"] = tools
        payload["tool_choice"] = "auto"
    headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
    client = httpx.AsyncClient(timeout=120)

    if stream:
        async def gen():
            async with client.stream(
                "POST", f"{BASE_URL}/chat/completions", headers=headers, json=payload
            ) as r:
                if r.status_code >= 400:
                    body = (await r.aread()).decode(errors="replace")
                    yield {"__error__": f"HTTP {r.status_code}: {body}"}
                    await client.aclose(); return
                async for line in r.aiter_lines():
                    if not line or not line.startswith("data:"):
                        continue
                    data = line[5:].strip()
                    if data == "[DONE]":
                        break
                    try:
                        obj = json.loads(data)
                    except json.JSONDecodeError:
                        continue
                    delta = obj["choices"][0].get("delta", {})
                    if (chunk := delta.get("content")):
                        yield {"text": chunk}
            await client.aclose()
        return gen()

    try:
        r = await client.post(f"{BASE_URL}/chat/completions", headers=headers, json=payload)
        if r.status_code >= 400:
            return {"__error__": f"HTTP {r.status_code}: {r.text}"}
        return r.json()
    finally:
        await client.aclose()


@asynccontextmanager
async def lifespan(_app):
    init_db()
    yield


app = FastAPI(lifespan=lifespan)


class ChatReq(BaseModel):
    conversation_id: int | None = None
    message: str
    agent: bool = False


def _sse(obj):
    return f"data: {json.dumps(obj, ensure_ascii=False)}\n\n"


@app.get("/api/conversations")
def list_convs():
    with db() as c:
        rows = c.execute("SELECT id,title,created_at FROM conversations ORDER BY id DESC").fetchall()
    return [dict(r) for r in rows]


@app.delete("/api/conversations/{cid}")
def del_conv(cid: int):
    with db() as c:
        c.execute("DELETE FROM conversations WHERE id=?", (cid,))
    return {"ok": True}


@app.get("/api/conversations/{cid}/messages")
def get_msgs(cid: int):
    with db() as c:
        rows = c.execute(
            "SELECT id,role,content,created_at FROM messages "
            "WHERE conversation_id=? ORDER BY id", (cid,)
        ).fetchall()
    return [dict(r) for r in rows]


@app.post("/api/chat")
async def chat(req: ChatReq):
    text = req.message.strip()
    if not text:
        raise HTTPException(400, "empty message")

    cid = req.conversation_id
    with db() as c:
        if cid is None:
            cur = c.execute("INSERT INTO conversations(title) VALUES(?)",
                            (text[:40] or "New chat",))
            cid = cur.lastrowid
        c.execute("INSERT INTO messages(conversation_id,role,content) VALUES(?,?,?)",
                  (cid, "user", text))
        rows = c.execute(
            "SELECT role,content FROM messages WHERE conversation_id=? ORDER BY id",
            (cid,)
        ).fetchall()
    history = [{"role": r["role"], "content": r["content"]} for r in rows
               if r["role"] in ("user", "assistant", "system")]

    async def streamer():
        try:
            if req.agent:
                working = list(history)
                for _ in range(6):
                    resp = await deepseek_chat(working, tools=TOOLS, stream=False)
                    if "__error__" in resp:
                        yield _sse({"error": resp["__error__"]}); return
                    msg = resp["choices"][0]["message"]
                    calls = msg.get("tool_calls") or []
                    if not calls:
                        content = msg.get("content") or ""
                        with db() as c:
                            c.execute(
                                "INSERT INTO messages(conversation_id,role,content) VALUES(?,?,?)",
                                (cid, "assistant", content),
                            )
                        yield _sse({"delta": content, "done": True, "conversation_id": cid})
                        return
                    working.append(msg)
                    for tc in calls:
                        name = tc["function"]["name"]
                        try:
                            args = json.loads(tc["function"].get("arguments") or "{}")
                        except json.JSONDecodeError:
                            args = {}
                        yield _sse({"tool": name, "args": args})
                        result = TOOL_IMPL.get(name, lambda _: "unknown tool")(args)
                        working.append({"role": "tool", "tool_call_id": tc["id"],
                                        "content": result})
                        yield _sse({"tool_result": result})
                yield _sse({"delta": "[stopped: max iterations]", "done": True,
                            "conversation_id": cid}); return

            full = []
            stream = await deepseek_chat(history, stream=True)
            async for item in stream:
                if "__error__" in item:
                    yield _sse({"error": item["__error__"]}); return
                full.append(item["text"])
                yield _sse({"delta": item["text"]})
            answer = "".join(full)
            if not answer:
                yield _sse({"error": "empty response from API"}); return
            with db() as c:
                c.execute("INSERT INTO messages(conversation_id,role,content) VALUES(?,?,?)",
                          (cid, "assistant", answer))
            yield _sse({"done": True, "conversation_id": cid})
        except Exception as e:
            yield _sse({"error": f"{type(e).__name__}: {e}"})

    return StreamingResponse(streamer(), media_type="text/event-stream")


@app.get("/health")
def health():
    return {"ok": True, "model": MODEL, "provider": "deepseek"}


HTML = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<title>AI Runner · DeepSeek</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
:root{--bg:#0a0f1c;--panel:#0f172a;--panel2:#172033;--line:#1e293b;--fg:#e2e8f0;
--dim:#94a3b8;--blue:#3b82f6;--cyan:#22d3ee;--red:#ef4444;--amber:#f59e0b;
--user:#1e3a8a;--bot:#111827}
*{box-sizing:border-box}
html,body{margin:0;height:100%;background:var(--bg);color:var(--fg);
font:14.5px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
#app{display:flex;height:100vh}
#sidebar{width:280px;background:var(--panel);border-right:1px solid var(--line);
display:flex;flex-direction:column}
#sidebar header{padding:16px;border-bottom:1px solid var(--line);
display:flex;align-items:center;gap:10px}
.brand{font-weight:700;font-size:14px}
.brand .dot{display:inline-block;width:8px;height:8px;border-radius:50%;
background:var(--cyan);margin-right:8px;box-shadow:0 0 8px var(--cyan)}
#newchat{margin:14px;padding:10px;background:linear-gradient(135deg,var(--blue),var(--cyan));
color:#fff;border:none;border-radius:8px;cursor:pointer;font-weight:600;font-size:13px}
#newchat:hover{filter:brightness(1.1)}
#convs{flex:1;overflow-y:auto;padding:0 10px 14px}
.conv{padding:9px 12px;border-radius:8px;cursor:pointer;font-size:13px;color:var(--dim);
display:flex;justify-content:space-between;align-items:center;gap:6px;margin-bottom:2px;
transition:background .15s}
.conv:hover,.conv.active{background:var(--panel2);color:var(--fg)}
.conv.active{box-shadow:inset 3px 0 0 var(--blue)}
.conv span{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.conv .del{opacity:0;color:var(--red);padding:0 4px;font-size:13px}
.conv:hover .del{opacity:1}
main{flex:1;display:flex;flex-direction:column;min-width:0}
#topbar{padding:14px 22px;border-bottom:1px solid var(--line);
display:flex;align-items:center;gap:16px;background:var(--panel)}
#title{flex:1;font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.toggle{display:flex;align-items:center;gap:7px;font-size:12.5px;
color:var(--dim);user-select:none;cursor:pointer}
.toggle input{accent-color:var(--cyan)}
#chat{flex:1;overflow-y:auto;padding:26px 20px 140px}
.msg{max-width:820px;margin:0 auto 20px;display:flex;gap:12px}
.avatar{width:32px;height:32px;border-radius:8px;display:flex;align-items:center;
justify-content:center;font-size:11px;font-weight:700;flex-shrink:0}
.user .avatar{background:var(--user);color:#93c5fd}
.bot .avatar{background:var(--bot);color:var(--cyan);border:1px solid var(--line)}
.bubble{flex:1;min-width:0;padding:12px 15px;border-radius:10px;
white-space:pre-wrap;word-wrap:break-word}
.user .bubble{background:var(--user)}
.bot .bubble{background:var(--bot);border:1px solid var(--line)}
.err .bubble{background:#7f1d1d;border:1px solid var(--red)}
.tool{max-width:820px;margin:-10px auto 14px;font-size:12px;color:var(--amber);
padding-left:44px;font-family:ui-monospace,monospace}
#composer{position:fixed;bottom:0;left:280px;right:0;
background:linear-gradient(transparent,var(--bg) 40%);padding:14px 20px 18px}
#cwrap{max-width:820px;margin:0 auto;background:var(--panel);
border:1px solid var(--line);border-radius:12px;padding:10px;
display:flex;gap:8px;align-items:flex-end;transition:border-color .15s}
#cwrap:focus-within{border-color:var(--blue)}
#input{flex:1;background:transparent;border:none;outline:none;color:var(--fg);
font:inherit;resize:none;max-height:200px;padding:6px;line-height:1.5}
#send{width:36px;height:36px;border:none;border-radius:8px;color:#fff;cursor:pointer;
background:linear-gradient(135deg,var(--blue),var(--cyan));font-size:15px}
#send:disabled{opacity:.5;cursor:not-allowed}
.hint{max-width:820px;margin:8px auto 0;font-size:11px;color:var(--dim);text-align:center}
code{background:#0a0f1c;padding:2px 6px;border-radius:4px;font-size:90%;
border:1px solid var(--line)}
pre{background:#0a0f1c;padding:12px;border-radius:8px;border:1px solid var(--line);
overflow-x:auto}
@media(max-width:760px){#composer{left:0}}
</style></head><body>
<div id="app">
<aside id="sidebar">
<header><div class="brand"><span class="dot"></span>AI Runner</div></header>
<button id="newchat">+ New chat</button>
<div id="convs"></div>
</aside>
<main>
<div id="topbar">
<div id="title">New chat</div>
<label class="toggle"><input type="checkbox" id="agentToggle"> Agent</label>
</div>
<div id="chat"></div>
<div id="composer">
<div id="cwrap">
<textarea id="input" rows="1"
placeholder="Message DeepSeek…  (Enter to send · Shift+Enter newline)"></textarea>
<button id="send" title="Send">➤</button>
</div>
<div class="hint">tools: <code>time</code> <code>calculate</code> <code>list_files</code></div>
</div>
</main></div>
<script>
const $=s=>document.querySelector(s);
const chatEl=$('#chat'),convsEl=$('#convs'),inputEl=$('#input');
const sendBtn=$('#send'),agentToggle=$('#agentToggle'),titleEl=$('#title');
let currentConv=null,streaming=false;
const api=async(p,o={})=>{const r=await fetch(p,{headers:{'Content-Type':'application/json'},...o});
if(!r.ok)throw new Error(await r.text());return r.json();};
const esc=s=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const md=s=>esc(s).replace(/```([\s\S]*?)```/g,'<pre><code>$1</code></pre>')
.replace(/`([^`]+)`/g,'<code>$1</code>');
async function loadConvs(){
const list=await api('/api/conversations');
convsEl.innerHTML='';
for(const c of list){
const d=document.createElement('div');
d.className='conv'+(c.id===currentConv?' active':'');
d.innerHTML=`<span>${esc(c.title)}</span><span class="del" title="delete">✕</span>`;
d.querySelector('span').onclick=()=>openConv(c.id,c.title);
d.querySelector('.del').onclick=async e=>{
e.stopPropagation();
if(!confirm('Delete this chat?'))return;
await api('/api/conversations/'+c.id,{method:'DELETE'});
if(currentConv===c.id){currentConv=null;chatEl.innerHTML='';titleEl.textContent='New chat';}
loadConvs();};
convsEl.appendChild(d);}}
async function openConv(id,title){
currentConv=id;titleEl.textContent=title||'Chat';chatEl.innerHTML='';
const msgs=await api(`/api/conversations/${id}/messages`);
msgs.forEach(m=>appendMsg(m.role,m.content));
loadConvs();scrollDown();}
function appendMsg(role,content,cls=''){
const w=document.createElement('div');
w.className='msg '+(role==='user'?'user':'bot')+(cls?' '+cls:'');
w.innerHTML=`<div class="avatar">${role==='user'?'U':'AI'}</div>
<div class="bubble">${md(content)}</div>`;
chatEl.appendChild(w);return w.querySelector('.bubble');}
function appendTool(text){const t=document.createElement('div');
t.className='tool';t.textContent='🔧 '+text;chatEl.appendChild(t);scrollDown();}
const scrollDown=()=>chatEl.scrollTop=chatEl.scrollHeight;
async function send(){
const text=inputEl.value.trim();
if(!text||streaming)return;
inputEl.value='';inputEl.style.height='auto';
appendMsg('user',text);
const bubble=appendMsg('assistant','…');
streaming=true;sendBtn.disabled=true;let answer='';
try{
const r=await fetch('/api/chat',{method:'POST',headers:{'Content-Type':'application/json'},
body:JSON.stringify({conversation_id:currentConv,message:text,agent:agentToggle.checked})});
if(!r.ok)throw new Error('HTTP '+r.status+': '+(await r.text()));
const reader=r.body.getReader(),dec=new TextDecoder();let buf='';
while(true){const{done,value}=await reader.read();if(done)break;
buf+=dec.decode(value,{stream:true});let idx;
while((idx=buf.indexOf('\n\n'))>=0){const chunk=buf.slice(0,idx);buf=buf.slice(idx+2);
const line=chunk.split('\n').find(l=>l.startsWith('data: '));if(!line)continue;
const obj=JSON.parse(line.slice(6));
if(obj.error){bubble.parentElement.classList.add('err');bubble.textContent='⚠ '+obj.error;}
else if(obj.delta){answer+=obj.delta;bubble.innerHTML=md(answer);scrollDown();}
else if(obj.tool)appendTool(`call ${obj.tool} ${JSON.stringify(obj.args)}`);
else if(obj.tool_result)appendTool(obj.tool_result);
else if(obj.done&&!currentConv){currentConv=obj.conversation_id;loadConvs();}}}
if(!answer&&!bubble.textContent.startsWith('⚠'))bubble.textContent='(no content)';
}catch(e){bubble.parentElement.classList.add('err');bubble.textContent='⚠ '+e.message;}
finally{streaming=false;sendBtn.disabled=false;inputEl.focus();}}
$('#newchat').onclick=()=>{currentConv=null;chatEl.innerHTML='';titleEl.textContent='New chat';
inputEl.focus();loadConvs();};
sendBtn.onclick=send;
inputEl.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();send();}});
inputEl.addEventListener('input',()=>{inputEl.style.height='auto';
inputEl.style.height=Math.min(inputEl.scrollHeight,200)+'px';});
loadConvs();inputEl.focus();
</script></body></html>"""


@app.get("/", response_class=HTMLResponse)
def index():
    return HTML
PYEOF
}

# ============================================================
#  MENU + COMMANDS
# ============================================================
show_menu() {
  echo
  section "Choose mode"
  cat <<EOF

   ${B4}1${RS})  ${BD}web${RS}     → browser UI at http://localhost:8080
   ${B4}2${RS})  ${BD}tui${RS}     → terminal chat (Rich)
   ${B4}3${RS})  ${BD}ask${RS}     → one-shot: ask a prompt
   ${B4}4${RS})  ${BD}health${RS}  → test DeepSeek API
   ${B4}q${RS})  quit

EOF
}

cmd_web() {
  local port="${1:-8080}"
  section "Starting web server on :$port"
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  printf '%s  →%s http://localhost:%s\n' "$B4" "$RS" "$port"
  [[ -n "$ip" ]] && printf '%s  →%s http://%s:%s  (LAN)\n' "$B4" "$RS" "$ip" "$port"
  printf '%s  Ctrl+C to stop%s\n\n' "$DM" "$RS"

  ( cd "$APP_DIR" && "$VENV/bin/uvicorn" app:app --host 0.0.0.0 --port "$port" ) || true

  echo
  section "Server stopped"
  printf '%s  press Enter to return to menu…%s\n' "$DM" "$RS"
  read -r _ || true
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
import os, sys
import httpx
p = sys.argv[1]
h = {"Authorization": f"Bearer {os.environ['DEEPSEEK_API_KEY']}",
     "Content-Type": "application/json"}
r = httpx.post(
    "https://api.deepseek.com/chat/completions", headers=h,
    json={"model": os.environ.get("DEEPSEEK_MODEL", "deepseek-chat"),
          "messages": [{"role": "user", "content": p}]},
    timeout=60,
)
if r.status_code >= 400:
    print(f"HTTP {r.status_code}: {r.text}", file=sys.stderr); sys.exit(1)
print(r.json()["choices"][0]["message"]["content"])
PY
}

cmd_health() {
  "$VENV/bin/python" - <<'PY'
import os
import httpx
h = {"Authorization": f"Bearer {os.environ['DEEPSEEK_API_KEY']}",
     "Content-Type": "application/json"}
try:
    r = httpx.post(
        "https://api.deepseek.com/chat/completions", headers=h,
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
write_web

case "${1:-menu}" in
  web)   shift; cmd_web "$@" ;;
  tui)   cmd_tui ;;
  ask)   shift; cmd_ask "$@" ;;
  health) cmd_health ;;
  menu|"")
    while true; do
      show_menu
      read -r -p "  > " choice
      case "$choice" in
        1) cmd_web 8080 ;;
        2) cmd_tui ;;
        3) read -r -p "  prompt: " p; cmd_ask "$p" ;;
        4) cmd_health ;;
        q|Q) exit 0 ;;
        *) warn "unknown choice" ;;
      esac
    done
    ;;
  *)  err "unknown mode: $1"; echo "usage: $0 [web|tui|ask|health|menu]"; exit 1 ;;
esac
