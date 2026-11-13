"""Collects license texts and a summary of every installed distribution.

Usage: python -s collect_licenses.py <output_dir> <gpl3_license_text>
"""
import shutil
import sys
from importlib import metadata
from pathlib import Path

LICENSE_NAMES = ("licen", "copying", "notice", "authors")

# packages whose metadata carries no license; verified against the upstream repositories
GPL3_OVERRIDES = {
    "comfyui-frontend-package": "https://github.com/Comfy-Org/ComfyUI_frontend",
    "comfy-aimdo": "https://github.com/Comfy-Org/comfy-aimdo",
}


def license_of(meta):
    expr = meta.get("License-Expression")
    if expr:
        return expr
    classifiers = [c.split("::")[-1].strip() for c in meta.get_all("Classifier") or [] if c.startswith("License ::")]
    if classifiers:
        return "; ".join(classifiers)
    text = (meta.get("License") or "").strip()
    return text.splitlines()[0][:80] if text else "UNKNOWN (see package files)"


def license_files(dist):
    root = Path(str(dist._path))
    for path in root.rglob("*"):
        if path.is_file() and path.name.lower().startswith(LICENSE_NAMES):
            yield path, path.relative_to(root)


out = Path(sys.argv[1])
gpl3_text = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
rows = []
for dist in sorted(metadata.distributions(), key=lambda d: d.metadata["Name"].lower()):
    meta = dist.metadata
    name, version = meta["Name"], dist.version
    key = name.lower().replace("_", "-")
    if key in GPL3_OVERRIDES:
        rows.append((name, version, "GPL-3.0 (per upstream repository; package metadata has no license)", GPL3_OVERRIDES[key]))
    else:
        rows.append((name, version, license_of(meta), meta.get("Home-page") or meta.get("Project-URL") or ""))
    found = False
    for src, rel in license_files(dist):
        found = True
        dest = out / f"{name}-{version}" / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dest)
    if key in GPL3_OVERRIDES and not found:
        dest = out / f"{name}-{version}" / "LICENSE"
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(gpl3_text, dest)

python_license = Path(sys.base_prefix) / "lib" / f"python{sys.version_info.major}.{sys.version_info.minor}" / "LICENSE.txt"
if python_license.exists():
    (out / "python").mkdir(exist_ok=True)
    shutil.copyfile(python_license, out / "python" / "LICENSE.txt")

with open(out / "SUMMARY.txt", "w", encoding="utf-8") as f:
    f.write("Python packages bundled in python_embeded (name, version, license, url)\n\n")
    for row in rows:
        f.write(" | ".join(str(c) for c in row) + "\n")
print(f"{len(rows)} packages, licenses in {out}")
