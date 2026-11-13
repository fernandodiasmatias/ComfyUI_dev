#!/usr/bin/env bash
# Smoke test for ComfyUI Linux Portable (CPU). Run it inside the target container/host,
# preferably as a non-root user. Only needs bash, coreutils and the package itself:
# all HTTP checks use the embedded Python.
#
#   smoke_test.sh [-t tarball] [-s sha256] [-d package_dir] [-c checkpoint] [-w workflow.json] [-p port]
#
#   -t  ComfyUI_linux_portable_cpu.tar.xz to extract into a temp dir (needs tar and xz)
#   -s  expected SHA256 of the tarball
#   -d  already extracted package dir (default: the directory containing this script, or ./ComfyUI_linux_portable)
#   -c  checkpoint file name present in ComfyUI/models/checkpoints; runs a 256x256, 4-step text-to-image workflow
#   -w  ComfyUI API-format workflow JSON to run instead of the built-in one
#   -p  port for the temporary server (default 8199)
#
# Environment: EXPECT_PY (3.13.14), EXPECT_TORCH (2.14.1+cpu), MIN_MEM_GB (8), WF_TIMEOUT (900 s).
# The server runs with temp output/temp/user/input directories, so the install is left untouched.
# Exit code: 0 if nothing failed (warnings allowed), 1 otherwise.
set -u

TARBALL=""; SHA=""; DIR=""; CKPT=""; WORKFLOW=""; PORT=8199
while getopts "t:s:d:c:w:p:h" opt; do
    case "$opt" in
        t) TARBALL="$OPTARG" ;; s) SHA="$OPTARG" ;; d) DIR="$OPTARG" ;;
        c) CKPT="$OPTARG" ;; w) WORKFLOW="$OPTARG" ;; p) PORT="$OPTARG" ;;
        *) sed -n '2,17p' "$0"; exit 2 ;;
    esac
done
EXPECT_PY="${EXPECT_PY:-3.13.14}"
EXPECT_TORCH="${EXPECT_TORCH:-2.14.1+cpu}"
MIN_MEM_GB="${MIN_MEM_GB:-8}"
export WF_TIMEOUT="${WF_TIMEOUT:-900}"

PASS=0; FAIL=0; WARN=0
pass() { PASS=$((PASS + 1)); echo "[PASS] $*"; }
fail() { FAIL=$((FAIL + 1)); echo "[FAIL] $*"; }
warn() { WARN=$((WARN + 1)); echo "[WARN] $*"; }
info() { echo "[INFO] $*"; }

TMP="$(mktemp -d)"
SERVER_PID=""
cleanup() {
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null && wait "$SERVER_PID" 2>/dev/null
    rm -rf "$TMP"
}
trap cleanup EXIT

echo "== Environment =="
[ -r /etc/os-release ] && info "OS: $(. /etc/os-release && echo "$PRETTY_NAME")"
info "kernel: $(uname -sr), arch: $(uname -m)"
[ "$(uname -m)" = "x86_64" ] && pass "architecture x86_64" || fail "architecture is $(uname -m), package is x86_64 only"

GLIBC="$(ldd --version 2>&1 | head -n 1 | grep -oE '[0-9]+\.[0-9]+$')"
if [ -n "$GLIBC" ] && [ "$(printf '%s\n2.28\n' "$GLIBC" | sort -V | head -n 1)" = "2.28" ]; then
    pass "glibc $GLIBC (>= 2.28)"
else
    fail "glibc '${GLIBC:-unknown}' (need >= 2.28)"
fi

if [ "$(id -u)" = "0" ]; then warn "running as root; also test as a non-root user"; else pass "running as non-root user ($(id -un))"; fi

if grep -qw avx2 /proc/cpuinfo 2>/dev/null; then pass "CPU has AVX2"; else warn "CPU without AVX2: PyTorch will be slow or may fail"; fi
info "CPU threads visible: $(nproc 2>/dev/null)"

MEM_KB="$(awk '/MemAvailable/ {print $2}' /proc/meminfo 2>/dev/null)"
LIMIT=""
for f in /sys/fs/cgroup/memory.max /sys/fs/cgroup/memory/memory.limit_in_bytes; do
    [ -r "$f" ] && LIMIT="$(cat "$f")" && break
done
MEM_GB=$(( ${MEM_KB:-0} / 1024 / 1024 ))
if [ -n "$LIMIT" ] && [ "$LIMIT" != "max" ] && [ "$LIMIT" -lt 9000000000000000 ] 2>/dev/null; then
    LIM_GB=$(( LIMIT / 1024 / 1024 / 1024 ))
    info "container memory limit: ${LIM_GB} GB (host available: ${MEM_GB} GB)"
    [ "$LIM_GB" -lt "$MIN_MEM_GB" ] && MEM_GB="$LIM_GB"
else
    info "no container memory limit; available: ${MEM_GB} GB"
fi
[ "$MEM_GB" -ge "$MIN_MEM_GB" ] && pass "memory ${MEM_GB} GB (>= ${MIN_MEM_GB})" || warn "memory ${MEM_GB} GB is below ${MIN_MEM_GB} GB; large models will fail"
[ -r /sys/fs/cgroup/cpu.max ] && info "cpu.max: $(cat /sys/fs/cgroup/cpu.max)"
info "free space in $TMP: $(df -Pm "$TMP" | awk 'NR==2 {print $4}') MB"
command -v getenforce >/dev/null 2>&1 && info "SELinux: $(getenforce)"

echo "== Package =="
if [ -n "$TARBALL" ]; then
    [ -f "$TARBALL" ] || { fail "tarball not found: $TARBALL"; echo "Summary: $PASS passed, $FAIL failed, $WARN warnings"; exit 1; }
    if [ -n "$SHA" ]; then
        ACTUAL="$(sha256sum "$TARBALL" | cut -d' ' -f1)"
        if [ "${ACTUAL,,}" = "${SHA,,}" ]; then pass "tarball SHA256 matches"; else fail "tarball SHA256 differs: $ACTUAL"; fi
    else
        info "tarball SHA256: $(sha256sum "$TARBALL" | cut -d' ' -f1) (pass -s to verify)"
    fi
    if tar -xJf "$TARBALL" -C "$TMP"; then pass "tarball extracted"; else fail "tarball extraction failed"; fi
    DIR="$TMP/ComfyUI_linux_portable"
fi
[ -z "$DIR" ] && { [ -x "$(dirname "$(readlink -f "$0")")/python_embeded/bin/python" ] && DIR="$(dirname "$(readlink -f "$0")")" || DIR="./ComfyUI_linux_portable"; }
DIR="$(cd "$DIR" 2>/dev/null && pwd)" || { fail "package dir not found"; echo "Summary: $PASS passed, $FAIL failed, $WARN warnings"; exit 1; }
info "package dir: $DIR"
PY="$DIR/python_embeded/bin/python"
MISSING=""
for f in python_embeded/bin/python ComfyUI/main.py run_cpu.sh LICENSE SOURCE_OFFER.txt THIRD_PARTY_LICENSES/SUMMARY.txt requirements-freeze.txt update/update_comfyui.sh; do
    [ -e "$DIR/$f" ] || MISSING="$MISSING $f"
done
[ -z "$MISSING" ] && pass "expected files present" || fail "missing files:$MISSING"
[ -x "$PY" ] || { fail "embedded python not executable"; echo "Summary: $PASS passed, $FAIL failed, $WARN warnings"; exit 1; }

echo "== Python and torch =="
PYV="$("$PY" -s -c 'import platform;print(platform.python_version())' 2>&1)"
[ "$PYV" = "$EXPECT_PY" ] && pass "python $PYV" || fail "python is '$PYV', expected $EXPECT_PY"
TV="$("$PY" -s -c 'import torch;print(torch.__version__)' 2>&1 | tail -n 1)"
[ "$TV" = "$EXPECT_TORCH" ] && pass "torch $TV" || warn "torch is '$TV', expected $EXPECT_TORCH"
if "$PY" -s -c 'import av, pygit2, aiohttp, PIL, safetensors, transformers' 2>"$TMP/imports.log"; then
    pass "key imports (av, pygit2, aiohttp, PIL, safetensors, transformers)"
else
    fail "import error: $(tail -n 1 "$TMP/imports.log")"
fi
if (cd "$DIR/ComfyUI" && git -c safe.directory='*' rev-parse --is-inside-work-tree >/dev/null 2>&1); then pass "ComfyUI git repo present (update scripts need it)"; else warn "ComfyUI is not a git repo: update scripts will fail"; fi

echo "== ComfyUI quick test =="
if "$PY" -s "$DIR/ComfyUI/main.py" --quick-test-for-ci --cpu --output-directory "$TMP/qt_out" --temp-directory "$TMP/qt_temp" --input-directory "$TMP/qt_in" > "$TMP/quick.log" 2>&1; then
    pass "main.py --quick-test-for-ci --cpu"
else
    fail "quick test failed (last lines below)"; tail -n 15 "$TMP/quick.log"
fi

echo "== Server =="
mkdir -p "$TMP/out" "$TMP/temp" "$TMP/user" "$TMP/input"
cat > "$TMP/client.py" <<'EOF'
import json, os, sys, time, urllib.error, urllib.request

base = f"http://127.0.0.1:{sys.argv[2]}"


def get(path):
    with urllib.request.urlopen(base + path, timeout=30) as r:
        return r.status, r.read()


cmd = sys.argv[1]
if cmd == "wait":
    deadline = time.time() + 180
    while time.time() < deadline:
        try:
            get("/")
            sys.exit(0)
        except (urllib.error.URLError, OSError):
            time.sleep(2)
    sys.exit(1)
elif cmd == "get":
    status, body = get(sys.argv[3])
    print(status, len(body))
elif cmd == "stats":
    print(json.loads(get("/system_stats")[1])["devices"][0]["type"])
elif cmd == "checkpoints":
    info = json.loads(get("/object_info/CheckpointLoaderSimple")[1])
    print("\n".join(info["CheckpointLoaderSimple"]["input"]["required"]["ckpt_name"][0]))
elif cmd == "run":
    prompt = json.load(open(sys.argv[3]))
    req = urllib.request.Request(base + "/prompt", json.dumps({"prompt": prompt}).encode(), {"Content-Type": "application/json"})
    try:
        pid = json.load(urllib.request.urlopen(req))["prompt_id"]
    except urllib.error.HTTPError as e:
        print("REJECTED", e.read().decode()[:1500])
        sys.exit(1)
    start = time.time()
    while time.time() - start < float(os.environ["WF_TIMEOUT"]):
        history = json.loads(get(f"/history/{pid}")[1])
        if pid in history:
            status = history[pid]["status"]
            print(f"STATUS {status['status_str']} in {time.time() - start:.1f}s")
            if status["status_str"] != "success":
                print(json.dumps(status["messages"])[-1500:])
                sys.exit(1)
            sys.exit(0)
        time.sleep(3)
    print("TIMEOUT")
    sys.exit(1)
EOF
"$PY" -s "$DIR/ComfyUI/main.py" --cpu --port "$PORT" --disable-auto-launch \
    --output-directory "$TMP/out" --temp-directory "$TMP/temp" --user-directory "$TMP/user" \
    --input-directory "$TMP/input" --database-url "sqlite:///$TMP/comfy.db" > "$TMP/server.log" 2>&1 &
SERVER_PID=$!
if "$PY" -s "$TMP/client.py" wait "$PORT"; then
    pass "server answers on port $PORT"
else
    fail "server did not start within 180 s (log tail below)"; tail -n 20 "$TMP/server.log"
fi
for path in / /system_stats /object_info/KSampler; do
    out="$("$PY" -s "$TMP/client.py" get "$PORT" "$path" 2>&1)"
    case "$out" in 200*) pass "GET $path -> $out" ;; *) fail "GET $path -> $out" ;; esac
done
DEV="$("$PY" -s "$TMP/client.py" stats "$PORT" 2>&1)"
[ "$DEV" = "cpu" ] && pass "ComfyUI device is cpu" || warn "ComfyUI device reported: $DEV"

HEXPORT="$(printf '%04X' "$PORT")"
EXPOSED="$(awk -v p=":$HEXPORT" '$4 == "0A" && index($2, p) { split($2, a, ":"); if (a[1] ~ /^0+$/) print a[1] }' /proc/net/tcp /proc/net/tcp6 2>/dev/null | head -n 1)"
if grep -qi ":$HEXPORT " /proc/net/tcp /proc/net/tcp6 2>/dev/null; then
    [ -z "$EXPOSED" ] && pass "server listens on loopback only (no --listen)" || warn "server listens on all interfaces"
else
    info "could not inspect listening sockets"
fi

if [ -n "$CKPT" ] || [ -n "$WORKFLOW" ]; then
    echo "== Workflow =="
    if [ -n "$WORKFLOW" ]; then
        cp "$WORKFLOW" "$TMP/workflow.json"
    else
        if ! "$PY" -s "$TMP/client.py" checkpoints "$PORT" | grep -qxF "$CKPT"; then
            fail "checkpoint '$CKPT' not found in ComfyUI/models/checkpoints; available:"
            "$PY" -s "$TMP/client.py" checkpoints "$PORT" | sed 's/^/        /'
            CKPT=""
        else
            cat > "$TMP/workflow.json" <<EOF
{
 "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "$CKPT"}},
 "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 256, "height": 256, "batch_size": 1}},
 "6": {"class_type": "CLIPTextEncode", "inputs": {"text": "a red apple on a wooden table, photo", "clip": ["4", 1]}},
 "7": {"class_type": "CLIPTextEncode", "inputs": {"text": "blurry, text", "clip": ["4", 1]}},
 "3": {"class_type": "KSampler", "inputs": {"seed": 1, "steps": 4, "cfg": 7.0, "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0, "model": ["4", 0], "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0]}},
 "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
 "9": {"class_type": "SaveImage", "inputs": {"filename_prefix": "smoke", "images": ["8", 0]}}
}
EOF
        fi
    fi
    if [ -f "$TMP/workflow.json" ]; then
        if "$PY" -s "$TMP/client.py" run "$PORT" "$TMP/workflow.json"; then
            pass "workflow executed"
            if [ -z "$WORKFLOW" ]; then
                ls "$TMP/out"/smoke_*.png >/dev/null 2>&1 && pass "output image written ($(du -k "$TMP"/out/smoke_*.png | head -n 1 | cut -f1) KB)" || fail "no output image found"
            fi
        else
            fail "workflow failed"; tail -n 20 "$TMP/server.log"
        fi
    fi
else
    info "workflow skipped (pass -c <checkpoint> or -w <workflow.json>)"
fi

echo
echo "Summary: $PASS passed, $FAIL failed, $WARN warnings"
[ "$FAIL" -eq 0 ]
