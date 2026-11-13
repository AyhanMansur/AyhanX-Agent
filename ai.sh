write_tui() {
  cat > "$APP_DIR/tui.py" <<'PYEOF'
"""AI Runner — Claude Code style terminal chat for DeepSeek."""
import json
import os
import sys

import httpx
from prompt_toolkit import PromptSession
from prompt_toolkit.formatted_text import HTML
from prompt_toolkit.key_binding import KeyBindings
from prompt_toolkit.styles import Style
from rich.console import Console
from rich.panel import Panel
from rich.text import Text

API_KEY = os.environ["DEEPSEEK_API_KEY"]
BASE_URL = os.environ.get("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
MODEL = os.environ.get("DEEPSEEK_MODEL", "deepseek-chat")

console = Console()

# Prompt style — just the arrow, cyan
prompt_style = Style.from_dict({
    "arrow": "ansicyan bold",
    "continuation": "ansibrightblack",
})

# Key bindings: Enter submits, Shift+Enter / Esc+Enter / Ctrl+J inserts newline
kb = KeyBindings()

@kb.add("enter")
def _(event):
    event.current_buffer.validate_and_handle()

@kb.add("escape", "enter")
def _(event):
    event.current_buffer.insert_text("\n")

@kb.add("c-j")
def _(event):
    event.current_buffer.insert_text("\n")

# HTTP error hints
HINTS = {
    401: "invalid API key — create one at platform.deepseek.com/api_keys",
    402: "insufficient balance — top up at platform.deepseek.com/top_up",
    429: "rate limited — wait a few seconds",
    500: "server error — try again",
    503: "service unavailable — try again later",
}


def error_message(status: int, body: str) -> str:
    msg = body
    try:
        j = json.loads(body)
        msg = j.get("error", {}).get("message", body)
    except Exception:
        pass
    hint = HINTS.get(status, "")
    return msg + (f"  —  {hint}" if hint else "")


def banner():
    console.print()
    console.print(
        Panel(
            Text.from_markup(
                "[bold cyan]✻[/] [bold]AI Runner[/]  [dim]·[/]  "
                f"[white]{MODEL}[/]\n\n"
                "[dim]/help[/] [dim]for commands[/]   "
                "[dim]/clear[/] [dim]to clear[/]   "
                "[dim]/new[/] [dim]new chat[/]   "
                "[dim]/exit[/] [dim]to quit[/]\n"
                "[dim]Shift+Enter for newline · Ctrl+C to cancel · Ctrl+D to exit[/]"
            ),
            border_style="dim cyan",
            padding=(0, 2),
        )
    )
    console.print()


def stream_reply(messages):
    headers = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
    payload = {"model": MODEL, "messages": messages, "stream": True}
    full: list[str] = []

    console.print("[cyan bold]⏺[/] ", end="", highlight=False)

    try:
        with httpx.Client(timeout=120) as client:
            with client.stream("POST", f"{BASE_URL}/chat/completions",
                               headers=headers, json=payload) as r:
                if r.status_code >= 400:
                    body = r.read().decode(errors="replace")
                    console.print(f"[red]{error_message(r.status_code, body)}[/]")
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
                        console.print(chunk, end="", highlight=False,
                                      markup=False, soft_wrap=True)
        console.print()
        console.print()
        return "".join(full)
    except httpx.RequestError as e:
        console.print(f"[red]network error: {e}[/]")
        return ""


def cmd_help():
    console.print(
        Panel(
            Text.from_markup(
                "[cyan]/new[/]      start a new conversation\n"
                "[cyan]/help[/]     show this help\n"
                "[cyan]/model[/]    show current model\n"
                "[cyan]/clear[/]    clear the screen\n"
                "[cyan]/exit[/]     quit\n\n"
                "[dim]Tips:[/]\n"
                "[dim]  · Enter to send, Shift+Enter for newline[/]\n"
                "[dim]  · Ctrl+C to cancel a response[/]\n"
                "[dim]  · Ctrl+D to exit[/]"
            ),
            title="[bold cyan]commands[/]",
            border_style="dim cyan",
            padding=(1, 2),
        )
    )


def main():
    banner()
    history: list[dict] = []
    session = PromptSession(
        key_bindings=kb,
        multiline=True,
        style=prompt_style,
        prompt_continuation=lambda width, line_number, is_soft_wrap: "  ",
        complete_while_typing=False,
    )

    while True:
        try:
            text = session.prompt(HTML("<arrow>❯ </arrow>"))
        except KeyboardInterrupt:
            console.print("[dim]^C[/]")
            continue
        except EOFError:
            console.print("[dim]bye[/]")
            return

        text = text.strip()
        if not text:
            continue

        if text.startswith("/"):
            cmd = text.lower().split()[0]
            if cmd in ("/exit", "/quit"):
                return
            if cmd == "/help":
                cmd_help(); continue
            if cmd == "/clear":
                console.clear(); banner(); continue
            if cmd == "/model":
                console.print(f"[cyan]{MODEL}[/]"); continue
            if cmd == "/new":
                history.clear()
                console.print("[dim]· new conversation[/]")
                continue
            console.print(f"[red]unknown command: {text}[/]")
            continue

        console.print()
        history.append({"role": "user", "content": text})

        try:
            answer = stream_reply(history)
        except KeyboardInterrupt:
            console.print("\n[dim]^C cancelled[/]")
            history.pop()
            continue

        if answer:
            history.append({"role": "assistant", "content": answer})
        else:
            history.pop()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n[dim]bye[/]")
PYEOF
}
