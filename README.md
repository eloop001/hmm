# hmm:  Command-Line Helper

Ever found yourself staring blankly at a blinking terminal cursor, wondering what the exact dark magic incantation is to extract a `.tar.gz` file? Or maybe you just can't remember the `find` command syntax to save your life? 

Welcome to ***hmm***! The ultra-light command-line helper built for folks completely new to the Linux/Mac command line, or just those of us whose brain cache gets mysteriously cleared a little too often. Just write `hmm` followd by what you want to do, and it will give you the exact command you need, or use `-x` and **execute the command right away.**

```bash
:~$ hmm 'where do I find the log files for docker?'
# Docker logs are typically located in /var/lib/docker/containers/ or accessible via 'sudo docker logs <container_id>'.'

:~$ hmm -x 'list all files in the current folder, ordered by size.'
Command: ls -lS
-rw-r--r--  1 mv   mv   3743358830 Mar 17 09:41  vid.mp4
-rw-rw-r--  1 mv   mv     78267034 Mar  3 12:09  snd.mp3


```

There is even a failsafe, pretty useful for beginners. Even if you use the flag `-x` ***hmm*** will warn you, and will **not** run the command directly, if it will result in severe loss of data or corruption of the os.

```bash
:~$ hmm -x 'Remove all files and folders in my home folder.'
#WARNING: This command will permanently delete all files and folders in your home directory, which is an IRREVERSIBLE action that will result in total data loss; to proceed, run: rm -rf ~/*
```



## Technical Details & Transparency

We firmly believe in transparency when it comes to tools that read from your environment and make external network calls. Here is exactly what is happening under the hood:

### What the Installation Does

When you run the installation script (`install.sh`), it will:

1. **Download Scripts**: Fetch the required scripts (`hmm`, `gpt.py`, `cmdhelper.py`, and `oshelp.md`) directly from the [GitHub repository](https://github.com/eloop001/hmm) and place them in your `~/.local/bin` directory.
2. **Setup Environment**: Locate your Conda or Miniconda installation, and create a lightweight, isolated environment named `hmm-helper` using Python 3.11. 
3. **Install Dependencies**: Install the `google-genai` Python package into that isolated Conda environment so it doesn't pollute your global Python setup.
4. **Shell Configuration**: Prompt you for your Google Gemini API key and securely inject it (along with `~/.local/bin` to your PATH) into your shell configuration file (like `~/.bashrc`, `~/.zshrc`, or `~/.profile`). 

### External Calls and API Key

- `hmm` acts as a bridge between your local terminal and **Google GenAI**.
- Every time you run a query using `hmm`, it makes an API call to Google's Gemini API to determine the right command for you.
- Because of this, the tool **requires a Google Gemini API key** to function. 

### OS Information Extraction

To ensure that the GenAI model returns a command that *actually works* on your specific machine,***hmm*** extracts standard OS-level versioning context and sends it along with your query. The exact information extracted is:

- **On Linux:** The script reads `/etc/os-release` to find the exact distribution name via `PRETTY_NAME` or `NAME` (e.g., "Linux / Ubuntu 22.04 LTS"). If that fails, it falls back to your kernel version (`platform.release()`).
- **On macOS (Darwin):** The script dynamically pulls your exact macOS version using Python's `platform.mac_ver()` (e.g., "Mac / macOS 14.4.1").

## License

MIT License
