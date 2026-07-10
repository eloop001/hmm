#!/bin/bash
set -eu
set -o pipefail

BASE_URL="https://raw.githubusercontent.com/eloop001/hmm/main"
INSTALL_DIR="$HOME/.local/bin"
FILES="hmm gemini.py cmdhelper.py oshelp.md requirements.txt"
VENV_DIR="$HOME/.local/share/hmm/venv"
ENV_DIR="$HOME/.config/hmm"
ENV_FILE="$ENV_DIR/.env"

TMP_DIR=""
cleanup() { [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT
trap 'echo "" >&2; echo "ERROR: installation failed. Fix the problem reported above and re-run the installer. Your previous installation (if any) was left untouched." >&2' ERR

# ── 1. Prerequisites ─────────────────────────────────────────────────────────
for CMD in curl python3; do
    if ! command -v "$CMD" >/dev/null 2>&1; then
        echo "ERROR: '$CMD' is required but was not found on PATH." >&2
        exit 1
    fi
done
if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)'; then
    echo "ERROR: python3 >= 3.9 is required (found: $(python3 --version 2>&1))." >&2
    exit 1
fi
echo "Found python3: $(command -v python3)"

# ── 2. Request the Google API Key securely (works even when piped) ──────────
EXISTING_KEY=""
if [ -f "$ENV_FILE" ]; then
    EXISTING_KEY=$(grep '^GOOGLE_API_KEY=' "$ENV_FILE" | tail -n 1 | cut -d= -f2- | tr -d '"' || true)
fi
if [ -n "$EXISTING_KEY" ]; then
    printf "Enter your Google Gemini API Key (press Enter to keep the existing one): "
else
    printf "Enter your Google Gemini API Key: "
fi
if [ -t 0 ]; then
    stty -echo; read -r GOOGLE_API_KEY; stty echo; echo
elif [ -e /dev/tty ]; then
    # stdin is the piped script; read from the terminal instead
    stty -echo < /dev/tty; read -r GOOGLE_API_KEY < /dev/tty; stty echo < /dev/tty; echo
else
    echo "" >&2
    echo "ERROR: cannot prompt for the API key (no terminal available)." >&2
    echo "Download install.sh and run it directly:  bash install.sh" >&2
    exit 1
fi
if [ -z "$GOOGLE_API_KEY" ] && [ -n "$EXISTING_KEY" ]; then
    GOOGLE_API_KEY="$EXISTING_KEY"
    echo "Keeping the existing API key."
fi
if [ -z "$GOOGLE_API_KEY" ]; then
    echo "ERROR: empty API key." >&2; exit 1
fi
echo "API key received (${#GOOGLE_API_KEY} characters)."

# ── 3. Download everything to a staging area first ───────────────────────────
TMP_DIR=$(mktemp -d)
echo "Downloading hmm files ..."
for FILE in $FILES; do
    echo "  $FILE"
    if ! curl -fsSL "$BASE_URL/$FILE" -o "$TMP_DIR/$FILE"; then
        echo "ERROR: failed to download $BASE_URL/$FILE — check your network connection." >&2
        exit 1
    fi
    if [ ! -s "$TMP_DIR/$FILE" ]; then
        echo "ERROR: downloaded $FILE is empty." >&2
        exit 1
    fi
done

# ── 4. Virtual environment ────────────────────────────────────────────────────
VENV_PYTHON="$VENV_DIR/bin/python"
if [ ! -x "$VENV_PYTHON" ]; then
    echo "Creating virtual environment at $VENV_DIR..."
    rm -rf "$VENV_DIR"
    if ! python3 -m venv "$VENV_DIR"; then
        rm -rf "$VENV_DIR"
        echo "ERROR: failed to create the virtual environment." >&2
        echo "On Debian/Ubuntu, install the venv module first, e.g.:" >&2
        echo "  sudo apt install python3-venv" >&2
        exit 1
    fi
fi

# ── 5. Dependencies ───────────────────────────────────────────────────────────
echo "Installing dependencies into the virtual environment..."
if ! "$VENV_PYTHON" -m pip install --quiet --upgrade -r "$TMP_DIR/requirements.txt"; then
    echo "ERROR: failed to install Python dependencies (see pip output above)." >&2
    exit 1
fi
if ! "$VENV_PYTHON" -c "import google.genai" >/dev/null 2>&1; then
    echo "ERROR: dependency check failed — the 'google-genai' package did not install correctly." >&2
    exit 1
fi

# ── 6. Patch shebangs in staging, then install atomically ────────────────────
echo "Patching shebangs to use $VENV_PYTHON ..."
for PYFILE in "$TMP_DIR/gemini.py" "$TMP_DIR/cmdhelper.py"; do
    TMP="$PYFILE.patched"
    printf '#!%s\n' "$VENV_PYTHON" > "$TMP"
    if head -1 "$PYFILE" | grep -q '^#!'; then
        tail -n +2 "$PYFILE" >> "$TMP"
    else
        cat "$PYFILE" >> "$TMP"
    fi
    mv "$TMP" "$PYFILE"
done

# Sanity check: the Python files must at least compile before installing them
if ! "$VENV_PYTHON" -m py_compile "$TMP_DIR/gemini.py" "$TMP_DIR/cmdhelper.py"; then
    echo "ERROR: downloaded Python files failed a syntax check — installation aborted." >&2
    exit 1
fi
rm -rf "$TMP_DIR/__pycache__"

mkdir -p "$INSTALL_DIR"
echo "Installing files to $INSTALL_DIR ..."
for FILE in $FILES; do
    mv -f "$TMP_DIR/$FILE" "$INSTALL_DIR/$FILE"
done
chmod +x "$INSTALL_DIR/hmm" "$INSTALL_DIR/gemini.py" "$INSTALL_DIR/cmdhelper.py"

# ── 7. Shell config + PATH ────────────────────────────────────────────────────
case "${SHELL:-}" in
    */zsh)  CONFIG_FILE="$HOME/.zshrc" ;;
    */bash) CONFIG_FILE="$HOME/.bashrc" ;;
    *)      CONFIG_FILE="$HOME/.profile" ;;
esac
touch "$CONFIG_FILE"
if ! grep -q '\.local/bin' "$CONFIG_FILE"; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$CONFIG_FILE"
    echo "Added ~/.local/bin to PATH in $CONFIG_FILE"
fi

# ── 8. Store key (no sed, injection-safe) ─────────────────────────────────────
mkdir -p "$ENV_DIR"
if [ -f "$ENV_FILE" ]; then
    grep -v '^GOOGLE_API_KEY=' "$ENV_FILE" > "$ENV_FILE.tmp" || true
    mv "$ENV_FILE.tmp" "$ENV_FILE"
fi
printf 'GOOGLE_API_KEY="%s"\n' "$GOOGLE_API_KEY" >> "$ENV_FILE"
chmod 600 "$ENV_FILE"
echo "API key stored in $ENV_FILE"

echo
echo "Installation complete!"
echo "Open a new terminal (or run: source $CONFIG_FILE) and try:"
echo "  hmm <your question>     get a shell command"
echo "  hmm -x <your question>  get the command and run it"
echo "  hmm -key                change your API key"
echo "  hmm -update             update hmm to the latest version"
