"""Collects license texts of the npm packages bundled in comfyui-frontend-package.

The frontend wheel ships a minified bundle plus source maps; the maps list the node_modules
packages that went into the bundle. Licenses are read from the npm registry tarballs.

Usage: python -s collect_npm_licenses.py <frontend_static_dir> <output_dir>
"""
import io
import json
import re
import sys
import tarfile
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

LICENSE_NAMES = ("licen", "copying", "notice", "patents")


def bundled_packages(static_dir):
    packages = set()
    for path in Path(static_dir).rglob("*.map"):
        try:
            sources = json.loads(path.read_text(encoding="utf-8")).get("sources", [])
        except ValueError:
            continue
        for source in sources:
            match = re.search(r"node_modules/\.pnpm/((?:@[^/@]+\+)?[^/@]+)@([^/_]+)", source)
            if match:
                packages.add((match.group(1).replace("+", "/"), match.group(2)))
    return sorted(packages)


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def collect(package):
    name, version = package
    meta = json.loads(fetch(f"https://registry.npmjs.org/{urllib.parse.quote(name, safe='@')}/{version}"))
    license_ = meta.get("license")
    if isinstance(license_, dict):
        license_ = license_.get("type")
    texts = {}
    with tarfile.open(fileobj=io.BytesIO(fetch(meta["dist"]["tarball"])), mode="r:gz") as tar:
        for member in tar.getmembers():
            base = member.name.split("/", 1)[-1]
            if member.isfile() and "/" not in base and base.lower().startswith(LICENSE_NAMES):
                texts[base] = tar.extractfile(member).read()
    return name, version, license_ or "UNKNOWN", texts


def collect_safe(package):
    try:
        return collect(package)
    except Exception as error:
        return package[0], package[1], f"ERROR: {error}", {}


static_dir, out = sys.argv[1], Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
packages = bundled_packages(static_dir)
with ThreadPoolExecutor(8) as pool:
    results = list(pool.map(collect_safe, packages))

with open(out / "NPM_SUMMARY.txt", "w", encoding="utf-8") as summary:
    summary.write("npm packages bundled in comfyui-frontend-package (name, version, license, license files)\n\n")
    for name, version, license_, texts in results:
        summary.write(f"{name} | {version} | {license_} | {', '.join(sorted(texts)) or 'no license file in package'}\n")
        for filename, data in texts.items():
            dest = out / f"{name.replace('/', '__')}-{version}" / filename
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
print(f"{len(results)} npm packages, licenses in {out}")
