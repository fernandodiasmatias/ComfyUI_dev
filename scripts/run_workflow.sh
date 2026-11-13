set -x
rm -rf /root/wf && mkdir /root/wf && cd /root/wf
tar -xJf /root/build/ComfyUI_linux_portable_cpu.tar.xz
cd ComfyUI_linux_portable
cat > ComfyUI/extra_model_paths.yaml <<'EOF'
local_models:
    base_path: /mnt/d/models
    checkpoints: checkpoints
EOF
./run_cpu.sh --port 8198 > /root/wf/server.log 2>&1 &
SP=$!
for i in $(seq 1 60); do curl -s -o /dev/null http://127.0.0.1:8198/ && break; sleep 2; done
cat > /root/wf/run.py <<'EOF'
import json, time, urllib.request
base = "http://127.0.0.1:8198"
prompt = {
 "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "SD1.5/v1-5-pruned-emaonly.ckpt"}},
 "5": {"class_type": "EmptyLatentImage", "inputs": {"width": 256, "height": 256, "batch_size": 1}},
 "6": {"class_type": "CLIPTextEncode", "inputs": {"text": "a red apple on a wooden table, photo", "clip": ["4", 1]}},
 "7": {"class_type": "CLIPTextEncode", "inputs": {"text": "blurry, text", "clip": ["4", 1]}},
 "3": {"class_type": "KSampler", "inputs": {"seed": 1, "steps": 4, "cfg": 7.0, "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0, "model": ["4", 0], "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0]}},
 "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
 "9": {"class_type": "SaveImage", "inputs": {"filename_prefix": "cpu_test", "images": ["8", 0]}},
}
req = urllib.request.Request(base + "/prompt", json.dumps({"prompt": prompt}).encode(), {"Content-Type": "application/json"})
try:
    pid = json.load(urllib.request.urlopen(req))["prompt_id"]
except urllib.error.HTTPError as e:
    print("REJECTED", e.read().decode()); raise SystemExit(1)
t = time.time()
while time.time() - t < 900:
    h = json.load(urllib.request.urlopen(f"{base}/history/{pid}"))
    if pid in h:
        s = h[pid]["status"]
        print("STATUS", s["status_str"], round(time.time() - t, 1), "s")
        print(json.dumps(h[pid]["outputs"]))
        if s["status_str"] != "success": print(json.dumps(s["messages"])[-1500:])
        break
    time.sleep(3)
else:
    print("TIMEOUT")
EOF
./python_embeded/bin/python -s /root/wf/run.py
ls -l ComfyUI/output
kill $SP
tail -5 /root/wf/server.log
