#!/usr/bin/env bash
cd "$(dirname "$(readlink -f "$0")")" || exit 1
./python_embeded/bin/python -s ComfyUI/main.py --cpu "$@"
