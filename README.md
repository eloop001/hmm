# hmm: Command-Line Helper

Ever found yourself staring blankly at a blinking terminal cursor, wondering what the exact dark magic incantation is to extract a `.tar.gz` file? Or maybe you just can't remember the `find` command syntax to save your life?

Welcome to ***hmm***! The ultra-light command-line helper built for folks completely new to the Linux/Mac command line, or just those of us whose brain cache gets mysteriously cleared a little too often. Just write `hmm` followed by what you want to do, and it will give you the exact command you need, or use `-x` and **execute the command right away.**

```
:~$ hmm 'where do I find the log files for docker?'
# Docker logs are typically located in /var/lib/docker/containers/ or accessible via 'sudo docker logs <container_id>'.'

:~$ hmm -x 'list all files in the current folder, ordered by size.'
Command: ls -lS
-rw-r--r--  1 mv   mv   3743358830 Mar 17 09:41  vid.mp4
-rw-rw-r--  1 mv   mv     78267034 Mar  3 12:09  snd.mp3
```

## Installation

Simply run the following command:

```
curl -fsSL https://raw.githubusercontent.com/eloop001/hmm/main/install.sh | bash
```

## Updating
You can also easily update `hmm` to the latest version by running:

```
:~$ hmm -update
```

## Changing your API key

If your Google Gemini API key expires or you want to switch to a different one, run:

```
:~$ hmm -key
```

You will be prompted for the new key, which is validated against the API and stored in `~/.config/hmm/.env`. If `hmm` ever detects that your stored key has become invalid, it will automatically prompt you for a new one.

## Safety for beginners
There is even a failsafe, pretty useful for beginners. Even if you use the flag `-x` ***hmm*** will warn you, and will **not** run the command directly, if it will result in severe loss of data or corruption of the os.

```
:~$ hmm -x 'Remove all files and folders in my home folder.'
#WARNING: This command will permanently delete all files and folders in your home directory, which is an IRREVERSIBLE action that will result in total data loss; to proceed, run: rm -rf ~/*
```

## Pasting Errors and Logs

If you need `hmm` to fix an error message, or if your query contains special characters like `'`, `"`, or `|`, using quotes on the command line can break. You can safely bypass this in two ways:

### 1. Interactive Pasting Mode:

Just type `hmm` (or `hmm -x`) and press Enter. It will open a prompt where you can paste any error log without worrying about formatting or quotes. Press `Ctrl+D` when you are done pasting.

```
:~$ hmm
Hmm... No question provided.
Type your question or paste your error below.
(Press Ctrl+D when finished to submit)

npm ERR! code ENOENT
npm ERR! syscall open
npm ERR! path /home/user/package.json
[Ctrl+D]
# It looks like you are missing a package.json file. Run: npm init
```

### 2. Piping (Advanced):

You can pipe failing commands or logs directly into `hmm`:

```
:~$ cat error.log | hmm
```

## Technical Details & Transparency

We firmly believe in transparency when it comes to tools that read from your environment and make external network calls. Here is exactly what is happening under the hood:

### What the Installation Does

When you install **hmm**, it will:

1. **Download Scripts**: Fetch the required files (`hmm`, `gemini.py`, `cmdhelper.py`, `oshelp.md`, and `requirements.txt`) directly from the [GitHub repository](https://github.com/eloop001/hmm) into a temporary staging area, verify them, and then place them in your `~/.local/bin` directory — a failed download never leaves you with a broken installation.
2. **Setup Environment**: create a lightweight environment at `~/.local/share/hmm/venv` using `python3 -m venv`.
3. **Install Dependencies**: Install the `google-genai` Python package into that isolated environment.
4. **Shell Configuration**: Prompt you for your Google Gemini API key, securely inject it into `~/.config/hmm/.env`, and add `~/.local/bin` to your PATH.

### External Calls and API Key

- `hmm` acts as a bridge between your local terminal and **Google GenAI**.
- Every time you run a query using `hmm`, it makes an API call to Google's Gemini API to determine the right command for you.
- `hmm` uses stable (non-preview) Gemini models. If a model is ever retired or unavailable, it automatically falls back to the next stable model in its list.
- Because of this, the tool **requires a Google Gemini API key** to function. Use `hmm -key` to set or replace it at any time.

### What Information hmm Sends

For the AI to suggest a command that *actually works on your machine*, it needs a little context about your system. So along with your question, ***hmm*** sends a short, single line describing your environment. Nothing else about your files or activity is collected.

Here is every piece of that context, in plain terms, and why it helps:

| What we send | Example | Why it helps |
| --- | --- | --- |
| **Operating system & version** | `Linux / Ubuntu 22.04 LTS` or `Mac / macOS 14.4.1` | So commands match your OS. On Linux this comes from `/etc/os-release` (falling back to your kernel version); on Mac from `platform.mac_ver()`. |
| **CPU architecture** | `x86_64`, `arm64` | Some commands and downloads differ between Intel and ARM machines. |
| **Shell** | `/bin/bash`, `/bin/zsh` | So the syntax fits the shell you actually use. |
| **Package manager** | `apt`, `dnf`, `brew` | So "install X" gives you the right command for your system. |
| **Init / service manager** | `systemd`, `launchd` | So "start/stop/restart a service" uses the correct tool. |
| **Privilege** | `root`, `sudo available` | So commands add `sudo` only when it's needed and available. |
| **Local network address** | `192.168.1.42` | Helps with home/office network questions. This is only your machine's local (LAN) address. |
| **Installed tools** | `nginx, docker, postgres, ufw` | So answers match the software you actually have. We only check for a short, fixed list of common tools (web servers, containers, databases, firewalls). |

**What hmm deliberately does *not* collect or send:**

- Your **name, username, or hostname**.
- Your **public IP address** (the address the wider internet sees). Only your local network address is used, and it is never looked up from an outside service.
- The **contents of your files**, your command history, or anything you did not type into `hmm` yourself.

Every check above is a quick, local look-up (for example, "is this program installed?") — none of it makes an extra network call, and none of it reads personal data.

## License

Apache 2


