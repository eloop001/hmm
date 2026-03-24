#!/bin/bash
set -e

BASE_URL="https://raw.githubusercontent.com/eloop001/hmm/main"
INSTALL_DIR="$HOME/.local/bin"
FILES="hmm gemini.py cmdhelper.py oshelp.md"

# ── 1. Request the Google API Key securely ────────────────────────────────────
echo "Enter your Google Gemini API Key:"
read -r GOOGLE_API_KEY
echo "API key received (${#GOOGLE_API_KEY} characters)."

# ── 2. Locate python3 ────────────────────────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 not found on system PATH. Please install python3 and re-run." >&2
    exit 1
fi
echo "Found python3: $(command -v python3)"

# ── 3. Create venv and install dependencies ──────────────────────────────
VENV_DIR="$HOME/.local/share/hmm/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment at $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
else
    echo "Virtual environment already exists at $VENV_DIR, skipping creation."
fi
VENV_PYTHON="$VENV_DIR/bin/python"

# ── 4. Create install directory ───────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"

# ── 5. Download all files ─────────────────────────────────────────────────────
echo "Downloading files to $INSTALL_DIR ..."
for FILE in $FILES; do
    echo "  Downloading $FILE ..."
    curl -fsSL "$BASE_URL/$FILE" -o "$INSTALL_DIR/$FILE"
done
curl -fsSL "$BASE_URL/requirements.txt" -o "$INSTALL_DIR/requirements.txt" || true

# Install requirements
echo "Installing requirements into venv..."
if [ -f "requirements.txt" ]; then
    "$VENV_PYTHON" -m pip install --quiet -r requirements.txt
elif [ -f "$INSTALL_DIR/requirements.txt" ]; then
    "$VENV_PYTHON" -m pip install --quiet -r "$INSTALL_DIR/requirements.txt"
else
    "$VENV_PYTHON" -m pip install --quiet google-genai
fi

# ── 6. Make scripts executable ────────────────────────────────────────────────
chmod +x "$INSTALL_DIR/hmm"
chmod +x "$INSTALL_DIR/gemini.py"
chmod +x "$INSTALL_DIR/cmdhelper.py"

# ── 6b. Patch shebangs to use the venv's Python ─────────────────────────
echo "Patching shebangs to use $VENV_PYTHON ..."
for PYFILE in "$INSTALL_DIR/gemini.py" "$INSTALL_DIR/cmdhelper.py"; do
    if head -1 "$PYFILE" | grep -q '^#!'; then
        if [ "$(uname)" = "Darwin" ]; then
            sed -i '' "1s|^#!.*|#!$VENV_PYTHON|" "$PYFILE"
        else
            sed -i "1s|^#!.*|#!$VENV_PYTHON|" "$PYFILE"
        fi
    else
        echo "#!$VENV_PYTHON" > "$PYFILE.tmp"
        cat "$PYFILE" >> "$PYFILE.tmp"
        mv "$PYFILE.tmp" "$PYFILE"
        chmod +x "$PYFILE"
    fi
done

# ── 7. Identify shell config file ─────────────────────────────────────────────
if [ -f "$HOME/.zshrc" ]; then
    CONFIG_FILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    CONFIG_FILE="$HOME/.bashrc"
else
    CONFIG_FILE="$HOME/.profile"
    touch "$CONFIG_FILE"
fi

# ── 8. Add ~/.local/bin to PATH if needed ─────────────────────────────────────
if ! grep -q 'export PATH.*\.local/bin' "$CONFIG_FILE" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CONFIG_FILE"
    echo "Added ~/.local/bin to PATH in $CONFIG_FILE"
fi

# ── 9. Set GOOGLE_API_KEY in ~/.config/hmm/.env ──────────────────────────────
ENV_DIR="$HOME/.config/hmm"
ENV_FILE="$ENV_DIR/.env"
mkdir -p "$ENV_DIR"

if [ ! -f "$ENV_FILE" ]; then
    echo "GOOGLE_API_KEY=\"$GOOGLE_API_KEY\"" > "$ENV_FILE"
    echo "API Key written to $ENV_FILE"
else
    if grep -q "^GOOGLE_API_KEY=" "$ENV_FILE"; then
        if [ "$(uname)" = "Darwin" ]; then
            sed -i '' "s|^GOOGLE_API_KEY=.*|GOOGLE_API_KEY=\"$GOOGLE_API_KEY\"|" "$ENV_FILE"
        else
            sed -i "s|^GOOGLE_API_KEY=.*|GOOGLE_API_KEY=\"$GOOGLE_API_KEY\"|" "$ENV_FILE"
        fi
        echo "API Key updated in $ENV_FILE"
    else
        echo "GOOGLE_API_KEY=\"$GOOGLE_API_KEY\"" >> "$ENV_FILE"
        echo "API Key added to $ENV_FILE"
    fi
fi

# ── 10. Apply changes to the current session ──────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
export GOOGLE_API_KEY="$GOOGLE_API_KEY"

echo
echo "Installation complete!"
echo "  Files installed in : $INSTALL_DIR"
echo "  Shell config       : $CONFIG_FILE"
echo "  API key stored in  : $ENV_FILE"
echo
echo "Run 'hmm <your question>' to get a shell command."
echo "Run 'hmm -x <your question>' to generate and execute it immediately."
