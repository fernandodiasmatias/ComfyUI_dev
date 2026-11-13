#!/usr/bin/env bash
cd "$(dirname "$(readlink -f "$0")")" || exit 1
./update_comfyui.sh
echo
echo "This will try to update pytorch and all python dependencies."
echo "If you just want to update normally, press Ctrl+C and run update_comfyui.sh instead."
read -r -p "Press Enter to continue..."
../python_embeded/bin/python -s -m pip install --upgrade torch==2.14.1 torchvision==0.29.1 torchaudio==2.11.0 --extra-index-url https://download.pytorch.org/whl/cpu -r ../ComfyUI/requirements.txt pygit2
