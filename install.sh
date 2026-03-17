#!/bin/bash
set -e

BASE_URL="https://raw.githubusercontent.com/eloop001/hmm/main"
INSTALL_DIR="$HOME/.local/bin"
FILES="hmm gpt.py cmdhelper.py oshelp.md"

# ── 1. Request the Google API Key securely ────────────────────────────────────
echo "Enter your Google Gemini API Key:"
read -r GOOGLE_API_KEY
echo "API key received (${#GOOGLE_API_KEY} characters)."

# ── 2. Locate conda ──────────────────────────────────────────────────────────
CONDA_BASE=""
for candidate in \
    "$(command -v conda 2>/dev/null | xargs -I{} dirname {} | xargs -I{} dirname {})" \
    "$HOME/miniconda3" "$HOME/anaconda3" \
    "$HOME/opt/anaconda3" "/opt/homebrew/Caskroom/miniconda/base" "/opt/homebrew/anaconda3" \
    "$HOME/miniconda" "$HOME/anaconda" \
    "/opt/miniconda3" "/opt/anaconda3"; do
    if [ -f "$candidate/etc/profile.d/conda.sh" ]; then
        CONDA_BASE="$candidate"
        break
    fi
done

if [ -z "$CONDA_BASE" ]; then
    echo "ERROR: conda installation not found. Please install Miniconda/Anaconda and re-run." >&2
    exit 1
fi
echo "Found conda at: $CONDA_BASE"

# Source conda so we can use 'conda' commands in this script
# shellcheck disable=SC1090
. "$CONDA_BASE/etc/profile.d/conda.sh"

# ── 3. Create conda env and install google-genai ──────────────────────────────
CONDA_ENV="hmm-helper"
if conda env list | awk '{print $1}' | grep -qx "$CONDA_ENV"; then
    echo "Conda env '$CONDA_ENV' already exists, skipping creation."
else
    echo "Creating conda env '$CONDA_ENV' with Python 3.11..."
    conda create -y -n "$CONDA_ENV" python=3.11 -q
fi

echo "Installing google-genai into '$CONDA_ENV'..."
conda run -n "$CONDA_ENV" pip install --quiet google-genai

CONDA_PYTHON="$CONDA_BASE/envs/$CONDA_ENV/bin/python"

# ── 4. Create install directory ───────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"

# ── 5. Download all files ─────────────────────────────────────────────────────
echo "Downloading files to $INSTALL_DIR ..."
for FILE in $FILES; do
    echo "  Downloading $FILE ..."
    curl -fsSL "$BASE_URL/$FILE" -o "$INSTALL_DIR/$FILE"
done

# ── 6. Make scripts executable ────────────────────────────────────────────────
chmod +x "$INSTALL_DIR/hmm"
chmod +x "$INSTALL_DIR/gpt.py"
chmod +x "$INSTALL_DIR/cmdhelper.py"

# ── 6b. Patch shebangs to use the conda env's Python ─────────────────────────
echo "Patching shebangs to use $CONDA_PYTHON ..."
for PYFILE in "$INSTALL_DIR/gpt.py" "$INSTALL_DIR/cmdhelper.py"; do
    # Replace any existing shebang line (or add one if missing)
    if head -1 "$PYFILE" | grep -q '^#!'; then
        if [ "$(uname)" = "Darwin" ]; then
            sed -i '' "1s|^#!.*|#!$CONDA_PYTHON|" "$PYFILE"
        else
            sed -i "1s|^#!.*|#!$CONDA_PYTHON|" "$PYFILE"
        fi
    else
        echo "#!$CONDA_PYTHON" > "$PYFILE.tmp"
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

# ── 9. Set GOOGLE_API_KEY if not already present ──────────────────────────────
if ! grep -q "export GOOGLE_API_KEY=" "$CONFIG_FILE" 2>/dev/null; then
    echo "export GOOGLE_API_KEY=$GOOGLE_API_KEY" >> "$CONFIG_FILE"
    echo "API Key written to $CONFIG_FILE"
else
    # Update the existing value
    if [ "$(uname)" = "Darwin" ]; then
        sed -i '' "s|^export GOOGLE_API_KEY=.*|export GOOGLE_API_KEY=$GOOGLE_API_KEY|" "$CONFIG_FILE"
    else
        sed -i "s|^export GOOGLE_API_KEY=.*|export GOOGLE_API_KEY=$GOOGLE_API_KEY|" "$CONFIG_FILE"
    fi
    echo "API Key updated in $CONFIG_FILE"
fi

# ── 10. Apply changes to the current session ──────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
export GOOGLE_API_KEY="$GOOGLE_API_KEY"

echo
echo "Installation complete!"
echo "  Files installed in : $INSTALL_DIR"
echo "  Shell config       : $CONFIG_FILE"
echo
echo "Run 'hmm <your question>' to get a shell command."
echo "Run 'hmm -x <your question>' to generate and execute it immediately."
echo
echo "ACTION REQUIRED: Run the following to activate the key in your current session:"
echo "  source $CONFIG_FILE"

