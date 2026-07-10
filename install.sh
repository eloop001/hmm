#!/bin/bash
set -eu
set -o pipefail

BASE_URL="https://raw.githubusercontent.com/eloop001/hmm/main"
INSTALL_DIR="$HOME/.local/bin"
FILES="hmm gemini.py cmdhelper.py oshelp.md"

# ── 1. Request the Google API Key securely (works even when piped) ──────────
printf "Enter your Google Gemini API Key: "
if [ -t 0 ]; then
    stty -echo; read -r GOOGLE_API_KEY; stty echo; echo
else
    # stdin is the piped script; read from the terminal instead
    stty -echo < /dev/tty; read -r GOOGLE_API_KEY < /dev/tty; stty echo < /dev/tty; echo
fi
if [ -z "$GOOGLE_API_KEY" ]; then
    echo "ERROR: empty API key." >&2; exit 1
fi
echo "API key received (${#GOOGLE_API_KEY} characters)."

# ── 2. Locate python3 ────────────────────────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found on PATH." >&2; exit 1
fi
echo "Found python3: $(command -v python3)"

# ── 3. venv ──────────────────────────────────────────────────────────────────
VENV_DIR="$HOME/.local/share/hmm/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment at $VENV_DIR..."
    if ! python3 -m venv "$VENV_DIR"; then
        echo "ERROR: failed to create the virtual environment." >&2
        echo "On Debian/Ubuntu, install the venv module first, e.g.:" >&2
        echo "  sudo apt install python3-venv" >&2
        exit 1
    fi
fi
VENV_PYTHON="$VENV_DIR/bin/python"
if [ ! -x "$VENV_PYTHON" ]; then
    echo "ERROR: virtual environment at $VENV_DIR is missing its python binary." >&2
    echo "Try removing $VENV_DIR and re-running this installer." >&2
    exit 1
fi

# ── 4/5. Download ─────────────────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
echo "Downloading files to $INSTALL_DIR ..."
for FILE in $FILES; do
    echo "  Downloading $FILE ..."
    curl -fsSL "$BASE_URL/$FILE" -o "$INSTALL_DIR/$FILE"
done
curl -fsSL "$BASE_URL/requirements.txt" -o "$INSTALL_DIR/requirements.txt" || true

echo "Installing requirements into venv..."
if [ -s "$INSTALL_DIR/requirements.txt" ]; then
    "$VENV_PYTHON" -m pip install --quiet -r "$INSTALL_DIR/requirements.txt"
else
    "$VENV_PYTHON" -m pip install --quiet google-genai
fi

# ── 6. Executables + shebang patch (portable, no sed -i) ─────────────────────
chmod +x "$INSTALL_DIR/hmm" "$INSTALL_DIR/gemini.py" "$INSTALL_DIR/cmdhelper.py"
echo "Patching shebangs to use $VENV_PYTHON ..."
for PYFILE in "$INSTALL_DIR/gemini.py" "$INSTALL_DIR/cmdhelper.py"; do
    TMP="$PYFILE.tmp"
    printf '#!%s\n' "$VENV_PYTHON" > "$TMP"
    if head -1 "$PYFILE" | grep -q '^#!'; then
        tail -n +2 "$PYFILE" >> "$TMP"
    else
        cat "$PYFILE" >> "$TMP"
    fi
    mv "$TMP" "$PYFILE"
    chmod +x "$PYFILE"
done

# ── 7/8. Shell config + PATH ──────────────────────────────────────────────────
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

# ── 9. Store key (no sed, injection-safe) ─────────────────────────────────────
ENV_DIR="$HOME/.config/hmm"
ENV_FILE="$ENV_DIR/.env"
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
echo "Run 'hmm <your question>' to get a shell command."
