
<div align="center" dir="rtl">

# ◆ AyhanX-Agent

**کلاینت ترمینالی پریمیوم برای چت با DeepSeek — استایل Claude Code**

[![Version](https://img.shields.io/badge/version-3.2.0-40e0d0?style=flat-square)](./ai.sh)
[![License](https://img.shields.io/badge/license-MIT-34d399?style=flat-square)](./LICENSE)
[![Python](https://img.shields.io/badge/python-3.10%20–%203.13-5eead4?style=flat-square)](https://python.org)
[![Platform](https://img.shields.io/badge/platform-linux-fbbf24?style=flat-square)]()
[![Stars](https://img.shields.io/github/stars/AyhanMansur/AyhanX-Agent?style=flat-square&color=40e0d0)](https://github.com/AyhanMansur/AyhanX-Agent/stargazers)

</div>

---

<div dir="rtl">

## 🎬 یک نگاه

```
     ░███               ░██                              ░██    ░██            ░███                                        ░██    
  ░██░██              ░██                               ░██  ░██            ░██░██                                       ░██    
 ░██  ░██  ░██    ░██ ░████████   ░██████   ░████████    ░██░██            ░██  ░██   ░████████  ░███████  ░████████  ░████████ 
░█████████ ░██    ░██ ░██    ░██       ░██  ░██    ░██    ░███    ░██████ ░█████████ ░██    ░██ ░██    ░██ ░██    ░██    ░██    
░██    ░██ ░██    ░██ ░██    ░██  ░███████  ░██    ░██   ░██░██           ░██    ░██ ░██    ░██ ░█████████ ░██    ░██    ░██    
░██    ░██ ░██   ░███ ░██    ░██ ░██   ░██  ░██    ░██  ░██  ░██          ░██    ░██ ░██   ░███ ░██        ░██    ░██    ░██    
░██    ░██  ░█████░██ ░██    ░██  ░█████░██ ░██    ░██ ░██    ░██         ░██    ░██  ░█████░██  ░███████  ░██    ░██     ░████ 
                  ░██                                                                       ░██                                 
            ░███████                                                                  ░███████                                  

  ◆ AyhanX-Agent  · DeepSeek terminal · v3.2.0
  ────────────────────────────────────────────────
```

</div>

---

<div dir="rtl">

## ✨ چرا AyhanX-Agent؟

یک فایل شل. یک دستور. یک تجربه‌ی پریمیوم ترمینالی.

بدون منوی شلوغ، بدون پنل وب، بدون تنظیمات پیچیده. فقط بزن و چت کن.

- 🎨 **رابط ترمینالی پریمیوم** — لوگوی گرادیانت، chip های مدل و حالت، bottom toolbar زنده، اسپینرهای نرم
- 🌊 **پاسخ‌های streaming** — کلمه‌به‌کلمه، با رندر زنده Markdown داخل پنل‌های گِرد
- 🛠️ **Agent Mode** — ۵ ابزار داخلی برای محاسبه، خوندن فایل، لیست دایرکتوری و اجرای شل امن
- 💾 **مدیریت گفتگو** — ذخیره/بارگذاری خودکار، `last.json` برای ادامه‌ی چت قبلی
- 🎯 **۱۲ دستور اسلش** — با autocomplete و پیشنهاد
- 📝 **ورودی چندخطی** — `Esc+Enter` برای خط جدید، `↑↓` برای تاریخچه
- 🔄 **پشتیبانی از مدل‌های سفارشی** — با `/model add NAME` هر مدلی رو اضافه کن
- 🚀 **نصب بدون پیکربندی** — Python خودکار از طریق `uv` دانلود می‌شه
- 🔧 **Fallback به mirror ایرانی** — اگه PyPI فیلتر بود، خودکار سوییچ می‌کنه
- 🔐 **کلید امن** — `chmod 600` + ورودی مخفی

</div>

---

<div dir="rtl">

## 🚀 نصب

### نصب یک‌خطی

```bash
bash <(curl -Ls https://raw.githubusercontent.com/AyhanMansur/AyhanX-Agent/main/ai.sh)
```

### یا clone و اجرا

```bash
git clone https://github.com/AyhanMansur/AyhanX-Agent.git
cd AyhanX-Agent
chmod +x ai.sh
./ai.sh
```

**در اولین اجرا:**

1. Python 3.12 (در صورت نیاز) به‌طور خودکار نصب می‌شه
2. پکیج‌ها از نزدیک‌ترین mirror (از جمله `runflare` برای ایران) نصب می‌شن
3. ازت کلید DeepSeek خواسته می‌شه (به‌صورت مخفی وارد می‌کنی)
4. صفحه پاک می‌شه و فقط لوگو + چت می‌بینی ✅

</div>

---

<div dir="rtl">

## 🔑 دریافت کلید API

اگه حساب DeepSeek نداری:

1. ثبت‌نام: [platform.deepseek.com](https://platform.deepseek.com)
2. ساخت کلید: [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys)
3. شارژ حساب (حداقل ~$2): [platform.deepseek.com/top_up](https://platform.deepseek.com/top_up)

> ⚠️ **اگه `HTTP 402` دیدی، یعنی حسابت شارژ نداره.** DeepSeek رایگان نیست ولی خیلی ارزونه (~$0.14 به ازای ۱ میلیون توکن ورودی).

**جایگزین‌های رایگان:**

```bash
# OpenRouter (مدل‌های free)
export DEEPSEEK_API_KEY="sk-or-v1-..."
export DEEPSEEK_BASE_URL="https://openrouter.ai/api/v1"
export DEEPSEEK_MODEL="deepseek/deepseek-chat-v3-0324:free"
./ai.sh

# Ollama (کاملاً لوکال)
export DEEPSEEK_API_KEY="ollama"
export DEEPSEEK_BASE_URL="http://localhost:11434/v1"
export DEEPSEEK_MODEL="qwen2.5:3b"
./ai.sh
```

</div>

---

<div dir="rtl">

## 🎮 استفاده

```bash
./ai.sh                # چت (پیش‌فرض)
./ai.sh ask "prompt"   # یک سؤال، یک جواب
./ai.sh health         # تست اتصال API
./ai.sh config         # نمایش فایل‌های پیکربندی
./ai.sh version        # نمایش نسخه
```

### داخل چت

| دستور | توضیح |
|---|---|
| `/help` | لیست همه‌ی دستورات |
| `/new` | شروع گفتگوی جدید |
| `/clear` | پاک کردن صفحه |
| `/model` | نمایش مدل‌های موجود |
| `/model NAME` | سوییچ مدل |
| `/model add NAME` | اضافه کردن مدل سفارشی |
| `/system TEXT` | تنظیم system prompt |
| `/agent` | روشن/خاموش کردن حالت agent |
| `/save [NAME]` | ذخیره‌ی گفتگو |
| `/load NAME` | بارگذاری گفتگوی ذخیره‌شده |
| `/chats` | لیست گفتگوهای ذخیره‌شده |
| `/history` | نمایش گفتگوی فعلی |
| `/info` | خلاصه‌ی پیکربندی |
| `/exit` | خروج |

### کلیدها

| کلید | عملکرد |
|---|---|
| `Enter` | ارسال پیام |
| `Esc + Enter` | خط جدید |
| `Ctrl + J` | خط جدید |
| `↑` / `↓` | تاریخچه‌ی ورودی |
| `Tab` | تکمیل خودکار دستور |
| `Ctrl + C` | لغو پاسخ فعلی |
| `Ctrl + D` | خروج |

</div>

---

<div dir="rtl">

## 🛠️ ابزارهای Agent Mode

با فعال کردن `/agent`، DeepSeek خودش تصمیم می‌گیره کی ابزار صدا بزنه:

| ابزار | کار |
|---|---|
| `get_current_time` | ساعت و تاریخ UTC |
| `calculate` | ماشین‌حساب امن (eval ایزوله) |
| `list_directory` | لیست فایل‌های `~` |
| `read_file` | خوندن فایل متنی (محدودیت 10KB) |
| `run_shell` | اجرای دستور شل امن (timeout 15s، دستورات مخرب بلاک) |

**مثال:**

```
❯ الان ساعت چنده و 45×12 چند میشه؟

  ⚙ get_current_time({})
    └ 2024-11-13T10:30:00+00:00
  ⚙ calculate({"expression": "45*12"})
    └ 540

◆ DeepSeek
┌────────────────────────────────────────────────────────────┐
│ الان ساعت 10:30 UTC است و 45 × 12 = 540.                   │
└────────────────────────────────────────────────────────────┘
```

</div>

---

<div dir="rtl">

## 💾 فایل‌ها و پیکربندی

همه‌چیز داخل `~/.ai_platform/`:

```
~/.ai_platform/
├── .env              # کلید API (chmod 600)
├── config.json       # مدل، system prompt، حالت agent، مدل‌های سفارشی
├── history.txt       # تاریخچه‌ی ↑↓
├── install.log       # لاگ نصب
├── runner/
│   ├── __init__.py
│   ├── tools.py      # پیاده‌سازی ابزارها
│   └── tui.py        # رابط ترمینالی (prompt_toolkit + Rich)
├── chats/
│   ├── last.json     # آخرین گفتگو (برای resume)
│   └── *.json        # گفتگوهای ذخیره‌شده
└── .venv/            # محیط مجازی Python
```

</div>

---

<div dir="rtl">

## 🖼️ اسکرین‌شات‌ها

<div align="center">

### صفحه‌ی شروع

```
     ░███               ░██                              ░██    ░██            ░███                              
  ░██░██              ░██                               ░██  ░██            ░██░██                             
 ░██  ░██  ░██    ░██ ░████████   ░██████   ░████████    ░██░██            ░██  ░██   ░████████  ░███████  ...
░█████████ ░██    ░██ ░██    ░██       ░██  ░██    ░██    ░███    ░██████ ░█████████ ░██    ░██ ░██    ░██ ...
...

  ◆ AyhanX-Agent  · DeepSeek terminal · v3.2.0
  ────────────────────────────────────────────────

  ◆ AyhanX-Agent   v3.2.0        deepseek-chat   CHAT
  ╭────────────────────────────────────────────────────────────╮
  │                                                            │
  ╰────────────────────────────────────────────────────────────╯
  type a message · /help for commands · Ctrl+D to exit

❯ _
```

### داخل چت

```
╭────────────────────────────────────────────────────────────╮
│ ◆ AyhanX-Agent  v3.2.0        deepseek-chat   CHAT         │
╰────────────────────────────────────────────────────────────╯

 you  سلام، خودت رو معرفی کن

 ◆ DeepSeek
┌────────────────────────────────────────────────────────────┐
│ سلام! من DeepSeek هستم، یک مدل زبانی پیشرفته که می‌تونم    │
│ توی برنامه‌نویسی، نوشتن، تحلیل و خیلی چیزهای دیگه کمکت      │
│ کنم. چطور می‌تونم امروز بهت کمک کنم؟                        │
└────────────────────────────────────────────────────────────┘

❯ _
```

### Agent Mode

```
❯ /agent
  agent mode on — tools enabled

❯ فایل‌های پروژه‌هام چیا هستن؟

  ⚙ list_directory({"path": "projects"})
    └ ["web-app/", "ai-runner/", "notes.md"]

◆ DeepSeek
┌────────────────────────────────────────────────────────────┐
│ داخل پوشه‌ی projects این‌ها رو داری:                        │
│ - web-app (پوشه)                                           │
│ - ai-runner (پوشه)                                         │
│ - notes.md (فایل)                                          │
└────────────────────────────────────────────────────────────┘
```

### بعد از خروج

```
  ────────────────────────────────────────────────
  ◆ thanks for using AyhanX-Agent
  https://github.com/AyhanMansur/AyhanX-Agent

  ◆ What next?   [r] resume last chat   [n] new chat   [a] add model   [q] quit
```

</div>

</div>

---

<div dir="rtl">

## 🧪 بررسی اتصال

```bash
./ai.sh health
```

خروجی:

```
  ▍Connection check
  endpoint  https://api.deepseek.com
  model     deepseek-chat
  status    200
  reply     'OK'
  ✔ connected
```

**خطاهای رایج:**

| کد | معنی | راه‌حل |
|---|---|---|
| `200` | ✅ همه چیز اوکیه | آماده‌ای برای چت |
| `401` | کلید نامعتبر | کلید جدید بساز |
| `402` | حساب شارژ نداره | [top_up](https://platform.deepseek.com/top_up) |
| `429` | Rate limit | چند لحظه صبر کن |
| DNS error | اینترنت/DNS خراب | `echo "nameserver 1.1.1.1" > /etc/resolv.conf` |

</div>

---

<div dir="rtl">

## 🔐 امنیت

- کلید API در `~/.ai_platform/.env` با `chmod 600` ذخیره می‌شه
- ورودی کلید به‌صورت **مخفی** (بدون نمایش در ترمینال)
- ابزار `run_shell` دستورات مخرب (`rm -rf /`، `mkfs` و …) رو بلاک می‌کنه
- `read_file` و `list_directory` محدود به `$HOME`
- `calculate` از `eval` با `__builtins__` خالی استفاده می‌کنه
- **هرگز `.env` رو commit نکن** — توی `.gitignore` بذارش

</div>

---

<div dir="rtl">

## 🏗️ چطور کار می‌کنه؟

`ai.sh` یک نصب‌کننده‌ی **تک‌فایلی** هست:

1. Python 3.10–3.13 رو پیدا می‌کنه (اگه نبود، `uv` نصب می‌کنه و Python 3.12 دانلود می‌کنه)
2. یه venv می‌سازه توی `~/.ai_platform/.venv`
3. `httpx`، `rich`، `prompt_toolkit` رو نصب می‌کنه (با mirror fallback)
4. کدهای Python رو توی `~/.ai_platform/runner/` می‌نویسه
5. `clear` می‌کنه، لوگو رو نشون می‌ده و می‌ره داخل چت

کل کد Python **داخل خود bash اسکریپت** با heredoc جاسازی شده — هیچ فایل اضافه‌ای دانلود نمی‌شه.

</div>

---

<div dir="rtl">

## 🧩 پیش‌نیازها

- **bash** (4.0+)
- **curl**
- **Linux** (تست شده روی Kali، Ubuntu، Debian)
- **Python 3.10–3.13** (اگه نبود، خودکار از طریق `uv` نصب می‌شه)

بدون `pip`، بدون `venv`، بدون پیکربندی دستی — همه چیز خودکار.

</div>

---

<div dir="rtl">

## 🛣️ نقشه‌ی راه

- [x] چت ترمینالی با streaming
- [x] Agent mode با ۵ ابزار
- [x] ذخیره/بارگذاری گفتگو
- [x] مدل‌های سفارشی
- [x] Resume گفتگوی قبلی
- [x] Bottom toolbar زنده
- [ ] تم‌های رنگی متعدد
- [ ] Export به Markdown
- [ ] پشتیبانی از چند provider در یک جا
- [ ] حالت `--json` برای اسکریپت‌نویسی
- [ ] پلاگین برای tool های سفارشی کاربر

</div>

---

<div dir="rtl">

## 🤝 مشارکت

اگه ایده‌ای برای ابزار جدید، بهبود UI یا هر چیز دیگه‌ای داری — issue باز کن یا PR بفرست. استقبال می‌کنم.

</div>

---

<div dir="rtl">

## 📜 لایسنس

MIT — هر کاری خواستی بکن.

</div>

---

<div dir="rtl">

## 🙏 قدردانی

- ساخته شده با [prompt_toolkit](https://github.com/prompt-toolkit/python-prompt-toolkit) و [Rich](https://github.com/Textualize/rich)
- الهام گرفته از [Claude Code](https://claude.ai/code) و [aichat](https://github.com/sigoden/aichat)
- قدرت گرفته از [DeepSeek](https://deepseek.com)

</div>

---

<div align="center" dir="rtl">

**⭐ اگه این پروژه بهت کمک کرد، یه ستاره بده ⭐**

[🐛 گزارش باگ](https://github.com/AyhanMansur/AyhanX-Agent/issues) · [💡 پیشنهاد ویژگی](https://github.com/AyhanMansur/AyhanX-Agent/issues) · [📖 مستندات](./README.md)

ساخته شده با ❤️ توسط [Ayhan Mansur](https://github.com/AyhanMansur)

</div>
---
