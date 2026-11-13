#!/usr/bin/env bash
# Builds ComfyUI_linux_portable (CPU only) on Rocky Linux 8.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
SRC="$ROOT/ComfyUI_source"
OUT="${WORK_DIR:-$ROOT/ComfyUI_linux}"
PORTABLE="$OUT/ComfyUI_linux_portable"
PY_VERSION="${PY_VERSION:-3.13.14}"
PBS_TAG="${PBS_TAG:-20260610}"
TORCH_PINS="${TORCH_PINS:-torch==2.14.1 torchvision==0.29.1 torchaudio==2.11.0}"

rm -rf "$PORTABLE"
mkdir -p "$PORTABLE" "$ROOT/ComfyUI_linux"

# 1. embedded python (python-build-standalone)
API="https://api.github.com/repos/astral-sh/python-build-standalone/releases/tags/$PBS_TAG"
PY_URL="$(curl -fsSL --retry 5 --retry-delay 5 "$API" | grep -oE "https://[^\"]*cpython-${PY_VERSION}(%2B|[+])[0-9]*-x86_64-unknown-linux-gnu-install_only\.tar\.gz" | head -n 1)"
[ -n "$PY_URL" ] || { echo "python $PY_VERSION install_only build not found (set PBS_TAG)"; exit 1; }
echo "Downloading $PY_URL"
curl -fsSL --retry 5 --retry-delay 5 "$PY_URL" -o "$OUT/python.tar.gz"
tar -xzf "$OUT/python.tar.gz" -C "$PORTABLE"
mv "$PORTABLE/python" "$PORTABLE/python_embeded"
rm "$OUT/python.tar.gz"
PY="$PORTABLE/python_embeded/bin/python3"
[ -e "$PORTABLE/python_embeded/bin/python" ] || ln -s python3 "$PORTABLE/python_embeded/bin/python"

# 2. ComfyUI
mkdir "$PORTABLE/ComfyUI"
tar -C "$SRC" --exclude=.git --exclude=.github --exclude=tests --exclude=tests-unit \
    --exclude=__pycache__ -cf - . | tar -C "$PORTABLE/ComfyUI" -xf -
echo 'local-portable' > "$PORTABLE/ComfyUI/.comfy_environment"

# update/update.py needs a git repo tracking origin/master (the Windows CI keeps one too)
git -C "$PORTABLE/ComfyUI" init -q -b master
git -C "$PORTABLE/ComfyUI" remote add origin https://github.com/comfyanonymous/ComfyUI.git
git -C "$PORTABLE/ComfyUI" fetch -q --depth 150 origin master
git -C "$PORTABLE/ComfyUI" reset -q origin/master

# 3. dependencies
"$PY" -s -m pip install --no-cache-dir --upgrade pip
"$PY" -s -m pip install --no-cache-dir $TORCH_PINS --index-url https://download.pytorch.org/whl/cpu
"$PY" -s -m pip install --no-cache-dir -r "$SRC/requirements.txt" pygit2
"$PY" -s -m pip uninstall -y comfyui-workflow-templates-media-image comfyui-workflow-templates-media-video comfyui-workflow-templates-media-other

# 4. taesd previews
TMP="$(mktemp -d)"
git clone --depth 1 https://github.com/comfyanonymous/taesd "$TMP/taesd"
mkdir -p "$PORTABLE/ComfyUI/models/vae_approx"
cp "$TMP"/taesd/*.safetensors "$PORTABLE/ComfyUI/models/vae_approx/"
rm -rf "$TMP"

# 5. scripts
mkdir "$PORTABLE/update"
cp "$SRC"/.ci/update_windows/update.py "$PORTABLE/update/"
cp -r "$ROOT"/linux_base_files/* "$PORTABLE/"
chmod +x "$PORTABLE"/*.sh "$PORTABLE"/update/*.sh

# 5b. license texts and build info (GPL compliance for redistribution)
"$PY" -s "$ROOT/scripts/collect_licenses.py" "$PORTABLE/THIRD_PARTY_LICENSES" "$PORTABLE/LICENSE"
"$PY" -s -m pip freeze > "$PORTABLE/requirements-freeze.txt"
{
    echo "ComfyUI version: $(sed -n 's/^__version__ = "\(.*\)"/\1/p' "$SRC/comfyui_version.py")"
    echo "ComfyUI git HEAD of the update repo (origin/master at build time): $(git -C "$PORTABLE/ComfyUI" rev-parse HEAD)"
    echo "Python: $("$PY" -s -c 'import sys;print(sys.version)')"
    echo "python-build-standalone tag: $PBS_TAG ($PY_URL)"
    echo "torch pins: $TORCH_PINS (index https://download.pytorch.org/whl/cpu)"
    echo "Built on: $(. /etc/os-release && echo "$PRETTY_NAME") on $(date -u +%Y-%m-%d)"
} > "$PORTABLE/BUILD_INFO.txt"

# 6. package
tar -C "$OUT" -cf - ComfyUI_linux_portable | xz -9e -T0 > "$OUT/ComfyUI_linux_portable_cpu.tar.xz"
if [ "$OUT" != "$ROOT/ComfyUI_linux" ]; then
    cp "$OUT/ComfyUI_linux_portable_cpu.tar.xz" "$ROOT/ComfyUI_linux/"
fi
echo "Done: $ROOT/ComfyUI_linux/ComfyUI_linux_portable_cpu.tar.xz"
