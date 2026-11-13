#!/usr/bin/env bash
# ============================================================
#   AI PLATFORM  ·  DeepSeek Chat + Agent  ·  single-file app
#   Usage:  ./ai_platform.sh [port]      (default: 8080)
# ============================================================
set -euo pipefail

PORT="${1:-8080}"
APP_DIR="${HOME}/.ai_platform"
VENV="${APP_DIR}/.venv"
PY_APP="${APP_DIR}/app.py"

# ---------- ANSI palette ----------
if [[ -t 1 ]]; then
  B1=$'\e[38;5;33m'    # deep blue
  B2=$'\e[38;5;39m'    # bright blue
  B3=$'\e[38;5;45m'    # cyan-blue
  B4=$'\e[38;5;51m'    # aqua
  BD=$'\e[1m'
  DM=$'\e[2m'
  RS=$'\e[0m'
else
  B1= B2= B3= B4= BD= DM= RS=
fi

# ---------- Banner (aligned + gradient) ----------
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
  printf '  %s%sAI Platform%s   %s·%s   %sDeepSeek Chat + Agent%s   %s·%s   %sv1.0%s\n\n' \
    "$BD" "$B4" "$RS" "$DM" "$RS" "$BD" "$RS" "$DM" "$RS" "$DM" "$RS"
}

# ---------- Small helpers ----------
section() { printf '%s%s▸ %s%s\n' "$BD" "$B3" "$*" "$RS"; }
ok()      { printf '%s  ✓%s %s\n' "$B4" "$RS" "$*"; }
warn()    { printf '%s  !%s %s\n' "$B3" "$RS" "$*"; }
err()     { printf '%s  ✗%s %s\n' "$B1" "$RS" "$*" >&2; }

# ---------- Run ----------
print_banner

section "Checking environment"
command -v python3 >/dev/null || { err "python3 not found"; exit 1; }
ok "python3 $(python3 -c 'import sys;print(".".join(map(str,sys.version_info[:2])))')"

# ---------- venv ----------
if [[ ! -d "$VENV" ]]; then
  section "First run · creating virtualenv"
  mkdir -p "$APP_DIR"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --upgrade pip
  "$VENV/bin/pip" install --quiet fastapi "uvicorn[standard]" httpx pydantic
  ok "dependencies installed"
else
  ok "virtualenv ready"
fi

# ---------- API key ----------
if [[ -z "${DEEPSEEK_API_KEY:-}" && -f "$APP_DIR/.env" ]]; then
  set -o allexport; . "$APP_DIR/.env"; set +o allexport
fi
if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
  section "API key"
  warn "DEEPSEEK_API_KEY not set"
  read -r -p "  paste your key: " DEEPSEEK_API_KEY
  [[ -z "$DEEPSEEK_API_KEY" ]] && { err "required"; exit 1; }
  printf 'DEEPSEEK_API_KEY=%s\n' "$DEEPSEEK_API_KEY" > "$APP_DIR/.env"
  chmod 600 "$APP_DIR/.env"
  ok "saved to $APP_DIR/.env"
else
  ok "API key loaded"
fi

# ---------- Write app.py ----------
section "Writing backend"

cat > "$PY_APP" <<'PYEOF'
"""AI Platform — DeepSeek Chat + Agent (FastAPI + single-page UI)."""
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


# ---------- Database ----------
def db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with db() as c:
        c.executescript(
            """
            CREATE TABLE IF NOT EXISTS conversations (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                title      TEXT NOT NULL DEFAULT 'New chat',
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE TABLE IF NOT EXISTS messages (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                conversation_id INTEGER NOT NULL,
                role            TEXT NOT NULL,
                content         TEXT NOT NULL,
                created_at      TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
            );
            """
        )


# ---------- Agent tools ----------
TOOLS: list[dict[str, Any]] = [
    {
        "type": "function",
        "function": {
            "name": "get_current_time",
            "description": "Return current UTC date/time in ISO format.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "calculate",
            "description": "Evaluate a simple arithmetic expression.",
            "parameters": {
                "type": "object",
                "properties": {
                    "expression": {"type": "string", "description": "e.g. '2+3*4'"}
                },
                "required": ["expression"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_files",
            "description": "List files in the user's home directory.",
            "parameters": {
                "type": "object",
                "properties": {
                    "subdir": {"type": "string", "description": "optional subfolder"}
                },
            },
        },
    },
]


def tool_get_current_time(_a: dict) -> str:
    return datetime.now(timezone.utc).isoformat()


def tool_calculate(a: dict) -> str:
    expr = a.get("expression", "")
    if not expr or any(ch not in "0123456789+-*/(). %" for ch in expr):
        return f"Error: invalid expression {expr!r}"
    try:
        return str(eval(expr, {"__builtins__": {}}, {}))  # noqa: S307
    except Exception as e:
        return f"Error: {e}"


def tool_list_files(a: dict) -> str:
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


# ---------- DeepSeek client ----------
async def deepseek_chat(messages, tools=None, stream=False):
    payload: dict[str, Any] = {"model": MODEL, "messages": messages, "stream": stream}
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
                        yield chunk
            await client.aclose()
        return gen()

    try:
        r = await client.post(f"{BASE_URL}/chat/completions", headers=headers, json=payload)
        r.raise_for_status()
        return r.json()
    finally:
        await client.aclose()


# ---------- FastAPI ----------
@asynccontextmanager
async def lifespan(_app: FastAPI):
    init_db()
    yield


app = FastAPI(lifespan=lifespan)


class ChatReq(BaseModel):
    conversation_id: int | None = None
    message: str
    agent: bool = False


def _sse(obj: dict) -> str:
    return f"data: {json.dumps(obj, ensure_ascii=False)}\n\n"


@app.get("/api/conversations")
def list_convs():
    with db() as c:
        rows = c.execute(
            "SELECT id, title, created_at FROM conversations ORDER BY id DESC"
        ).fetchall()
    return [dict(r) for r in rows]


@app.post("/api/conversations")
def new_conv():
    with db() as c:
        cur = c.execute("INSERT INTO conversations (title) VALUES ('New chat')")
    return {"id": cur.lastrowid, "title": "New chat"}


@app.delete("/api/conversations/{cid}")
def del_conv(cid: int):
    with db() as c:
        c.execute("DELETE FROM conversations WHERE id=?", (cid,))
    return {"ok": True}


@app.get("/api/conversations/{cid}/messages")
def get_msgs(cid: int):
    with db() as c:
        rows = c.execute(
            "SELECT id, role, content, created_at FROM messages "
            "WHERE conversation_id=? ORDER BY id",
            (cid,),
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
            cur = c.execute(
                "INSERT INTO conversations (title) VALUES (?)",
                (text[:40] or "New chat",),
            )
            cid = cur.lastrowid
        c.execute(
            "INSERT INTO messages (conversation_id, role, content) VALUES (?,?,?)",
            (cid, "user", text),
        )
        rows = c.execute(
            "SELECT role, content FROM messages WHERE conversation_id=? ORDER BY id",
            (cid,),
        ).fetchall()
    history = [
        {"role": r["role"], "content": r["content"]}
        for r in rows
        if r["role"] in ("user", "assistant", "system")
    ]

    async def streamer():
        try:
            if req.agent:
                working = list(history)
                for _ in range(6):
                    resp = await deepseek_chat(working, tools=TOOLS, stream=False)
                    msg = resp["choices"][0]["message"]
                    calls = msg.get("tool_calls") or []
                    if not calls:
                        content = msg.get("content") or ""
                        with db() as c:
                            c.execute(
                                "INSERT INTO messages (conversation_id, role, content) "
                                "VALUES (?,?,?)",
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
                        impl = TOOL_IMPL.get(name)
                        result = impl(args) if impl else f"Error: unknown tool {name}"
                        working.append(
                            {"role": "tool", "tool_call_id": tc["id"], "content": result}
                        )
                        yield _sse({"tool_result": result})
                yield _sse({"delta": "\n[!] agent stopped: max iterations",
                            "done": True, "conversation_id": cid})
                return

            full: list[str] = []
            async for chunk in await deepseek_chat(history, stream=True):
                full.append(chunk)
                yield _sse({"delta": chunk})
            answer = "".join(full)
            with db() as c:
                c.execute(
                    "INSERT INTO messages (conversation_id, role, content) VALUES (?,?,?)",
                    (cid, "assistant", answer),
                )
            yield _sse({"done": True, "conversation_id": cid})
        except Exception as e:  # noqa: BLE001
            yield _sse({"error": str(e)})

    return StreamingResponse(streamer(), media_type="text/event-stream")


@app.get("/health")
def health():
    return {"ok": True, "model": MODEL}


# ---------- Frontend ----------
HTML = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>AI Runner · DeepSeek</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
:root{
  --bg:#0a0f1c; --panel:#0f172a; --panel2:#172033; --line:#1e293b;
  --fg:#e2e8f0; --dim:#94a3b8;
  --blue:#3b82f6; --blue2:#60a5fa; --cyan:#22d3ee;
  --green:#10b981; --red:#ef4444; --amber:#f59e0b;
  --user:#1e3a8a; --bot:#111827;
}
*{box-sizing:border-box}
html,body{margin:0;height:100%;background:var(--bg);color:var(--fg);
  font:14.5px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
#app{display:flex;height:100vh}
#sidebar{width:280px;background:var(--panel);border-right:1px solid var(--line);
  display:flex;flex-direction:column}
#sidebar header{padding:16px;border-bottom:1px solid var(--line);
  display:flex;align-items:center;gap:10px}
.brand{font-weight:700;font-size:14px;letter-spacing:.4px}
.brand .dot{display:inline-block;width:8px;height:8px;border-radius:50%;
  background:var(--cyan);margin-right:8px;box-shadow:0 0 8px var(--cyan)}
#newchat{margin:14px;padding:10px;background:linear-gradient(135deg,var(--blue),var(--cyan));
  color:#fff;border:none;border-radius:8px;cursor:pointer;font-weight:600;font-size:13px}
#newchat:hover{filter:brightness(1.1)}
#convs{flex:1;overflow-y:auto;padding:0 10px 14px}
.conv{padding:9px 12px;border-radius:8px;cursor:pointer;font-size:13px;color:var(--dim);
  display:flex;justify-content:space-between;align-items:center;gap:6px;margin-bottom:2px;
  transition:background .15s}
.conv:hover{background:var(--panel2);color:var(--fg)}
.conv.active{background:var(--panel2);color:var(--fg);box-shadow:inset 3px 0 0 var(--blue)}
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
</style>
</head>
<body>
<div id="app">
  <aside id="sidebar">
    <header><div class="brand"><span class="dot"></span>AI Runner</div></header>
    <button id="newchat">+ New chat</button>
    <div id="convs"></div>
  </aside>
  <main>
    <div id="topbar">
      <div id="title">New chat</div>
      <label class="toggle"><input type="checkbox" id="agentToggle"> Agent mode</label>
    </div>
    <div id="chat"></div>
    <div id="composer">
      <div id="cwrap">
        <textarea id="input" rows="1"
          placeholder="Message DeepSeek…  (Enter to send · Shift+Enter newline)"></textarea>
        <button id="send" title="Send">➤</button>
      </div>
      <div class="hint">DeepSeek · Agent tools: <code>time</code>
        <code>calculate</code> <code>list_files</code></div>
    </div>
  </main>
</div>
<script>
const $ = s => document.querySelector(s);
const chatEl = $('#chat'), convsEl = $('#convs'), inputEl = $('#input');
const sendBtn = $('#send'), agentToggle = $('#agentToggle'), titleEl = $('#title');
let currentConv = null, streaming = false;

const api = async (p, o={}) => {
  const r = await fetch(p, {headers:{'Content-Type':'application/json'}, ...o});
  if(!r.ok) throw new Error(await r.text());
  return r.json();
};
const esc = s => s.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const md = s => esc(s)
  .replace(/```([\s\S]*?)```/g, '<pre><code>$1</code></pre>')
  .replace(/`([^`]+)`/g, '<code>$1</code>');

async function loadConvs(){
  const list = await api('/api/conversations');
  convsEl.innerHTML = '';
  for(const c of list){
    const d = document.createElement('div');
    d.className = 'conv' + (c.id === currentConv ? ' active' : '');
    d.innerHTML = `<span>${esc(c.title)}</span><span class="del" title="delete">✕</span>`;
    d.querySelector('span').onclick = () => openConv(c.id, c.title);
    d.querySelector('.del').onclick = async e => {
      e.stopPropagation();
      if(!confirm('Delete this chat?')) return;
      await api('/api/conversations/'+c.id, {method:'DELETE'});
      if(currentConv === c.id){ currentConv = null; chatEl.innerHTML=''; titleEl.textContent='New chat'; }
      loadConvs();
    };
    convsEl.appendChild(d);
  }
}

async function openConv(id, title){
  currentConv = id; titleEl.textContent = title || 'Chat'; chatEl.innerHTML = '';
  const msgs = await api(`/api/conversations/${id}/messages`);
  msgs.forEach(m => appendMsg(m.role, m.content));
  loadConvs(); scrollDown();
}

function appendMsg(role, content){
  const w = document.createElement('div');
  w.className = 'msg ' + (role === 'user' ? 'user' : 'bot');
  w.innerHTML = `<div class="avatar">${role==='user'?'U':'AI'}</div>
                 <div class="bubble">${md(content)}</div>`;
  chatEl.appendChild(w);
  return w.querySelector('.bubble');
}

function appendTool(text){
  const t = document.createElement('div');
  t.className = 'tool'; t.textContent = '🔧 ' + text;
  chatEl.appendChild(t); scrollDown();
}

const scrollDown = () => chatEl.scrollTop = chatEl.scrollHeight;

async function send(){
  const text = inputEl.value.trim();
  if(!text || streaming) return;
  inputEl.value = ''; inputEl.style.height = 'auto';
  appendMsg('user', text);
  const bubble = appendMsg('assistant', '…');
  streaming = true; sendBtn.disabled = true;
  let answer = '';
  try{
    const r = await fetch('/api/chat', {
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify({conversation_id: currentConv, message: text, agent: agentToggle.checked})
    });
    if(!r.ok) throw new Error(await r.text());
    const reader = r.body.getReader(), dec = new TextDecoder();
    let buf = '';
    while(true){
      const {done, value} = await reader.read();
      if(done) break;
      buf += dec.decode(value, {stream:true});
      let idx;
      while((idx = buf.indexOf('\n\n')) >= 0){
        const chunk = buf.slice(0, idx); buf = buf.slice(idx+2);
        const line = chunk.split('\n').find(l => l.startsWith('data: '));
        if(!line) continue;
        const obj = JSON.parse(line.slice(6));
        if(obj.error)       bubble.textContent = '⚠ ' + obj.error;
        else if(obj.delta)  { answer += obj.delta; bubble.innerHTML = md(answer); scrollDown(); }
        else if(obj.tool)         appendTool(`call ${obj.tool} ${JSON.stringify(obj.args)}`);
        else if(obj.tool_result)  appendTool(obj.tool_result);
        else if(obj.done && !currentConv) currentConv = obj.conversation_id, loadConvs();
      }
    }
    if(!answer) bubble.textContent = '(no content)';
  }catch(e){ bubble.textContent = '⚠ ' + e.message; }
  finally{ streaming = false; sendBtn.disabled = false; inputEl.focus(); }
}

$('#newchat').onclick = () => {
  currentConv = null; chatEl.innerHTML = ''; titleEl.textContent = 'New chat';
  inputEl.focus(); loadConvs();
};
sendBtn.onclick = send;
inputEl.addEventListener('keydown', e => {
  if(e.key === 'Enter' && !e.shiftKey){ e.preventDefault(); send(); }
});
inputEl.addEventListener('input', () => {
  inputEl.style.height = 'auto';
  inputEl.style.height = Math.min(inputEl.scrollHeight, 200) + 'px';
});
loadConvs(); inputEl.focus();
</script>
</body>
</html>
"""


@app.get("/", response_class=HTMLResponse)
def index():
    return HTML
PYEOF

chmod 600 "$PY_APP"
ok "backend written to $PY_APP"

# ---------- Launch ----------
section "Starting server"
printf '%s  →%s http://localhost:%s%s\n' "$B4" "$RS" "$PORT" "$RS"
printf '%s  →%s http://%s:%s%s   (LAN)%s\n' \
  "$B4" "$RS" "$(hostname -I 2>/dev/null | awk '{print $1}' || echo localhost)" \
  "$PORT" "$DM" "$RS"
printf '%s  stop with Ctrl+C%s\n\n' "$DM" "$RS"

export DEEPSEEK_API_KEY
cd "$APP_DIR"
exec "$VENV/bin/uvicorn" app:app --host 0.0.0.0 --port "$PORT"
