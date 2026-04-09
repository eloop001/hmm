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

You can also easily update `hmm` to the latest version by running:

```
:~$ hmm -update
```

There is even a failsafe, pretty useful for beginners. Even if you use the flag `-x` ***hmm*** will warn you, and will **not** run the command directly, if it will result in severe loss of data or corruption of the os.

```
:~$ hmm -x 'Remove all files and folders in my home folder.'
#WARNING: This command will permanently delete all files and folders in your home directory, which is an IRREVERSIBLE action that will result in total data loss; to proceed, run: rm -rf ~/*
```

## Pasting Errors and Logs (No Quotes Needed!)

If you need `hmm` to fix an error message, or if your query contains special characters like `'`, `"`, or `|`, using quotes on the command line can break. You can safely bypass this in two ways:

**1. Interactive Pasting Mode:**

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

**2. Piping (Advanced):**

You can pipe failing commands or logs directly into `hmm`:

```
:~$ cat error.log | hmm
```

## Technical Details & Transparency

We firmly believe in transparency when it comes to tools that read from your environment and make external network calls. Here is exactly what is happening under the hood:

### What the Installation Does

When you run the installation script (`install.sh`), it will:

1. **Download Scripts**: Fetch the required scripts (`hmm`, `gemini.py`, `cmdhelper.py`, and `oshelp.md`) directly from the [GitHub repository](https://github.com/eloop001/hmm) and place them in your `~/.local/bin` directory.
2. **Setup Environment**: create a lightweight environment at `~/.local/share/hmm/venv` using `python3 -m venv`.
3. **Install Dependencies**: Install the `google-genai` Python package into that isolated environment.
4. **Shell Configuration**: Prompt you for your Google Gemini API key, securely inject it into `~/.config/hmm/.env`, and add `~/.local/bin` to your PATH.

### External Calls and API Key

- `hmm` acts as a bridge between your local terminal and **Google GenAI**.
- Every time you run a query using `hmm`, it makes an API call to Google's Gemini API to determine the right command for you.
- Because of this, the tool **requires a Google Gemini API key** to function.

### OS Information Extraction

To ensure that the GenAI model returns a command that *actually works* on your specific machine, ***hmm*** extracts standard OS-level versioning context and sends it along with your query. The exact information extracted is:

- **On Linux:** The script reads `/etc/os-release` to find the exact distribution name via `PRETTY_NAME` or `NAME` (e.g., "Linux / Ubuntu 22.04 LTS"). If that fails, it falls back to your kernel version (`platform.release()`).
- **On macOS (Darwin):** The script dynamically pulls your exact macOS version using Python's `platform.mac_ver()` (e.g., "Mac / macOS 14.4.1").

## License

Apache 2


