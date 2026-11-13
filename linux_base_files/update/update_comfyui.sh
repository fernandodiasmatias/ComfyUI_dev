#!/usr/bin/env bash
cd "$(dirname "$(readlink -f "$0")")" || exit 1
export SSL_CERT_FILE="$(../python_embeded/bin/python -s -c 'import certifi;print(certifi.where())')"
../python_embeded/bin/python -s ./update.py ../ComfyUI/
if [ -f update_new.py ]; then
  mv -f update_new.py update.py
  echo "Running updater again since it got updated."
  ../python_embeded/bin/python -s ./update.py ../ComfyUI/ --skip_self_update
fi
