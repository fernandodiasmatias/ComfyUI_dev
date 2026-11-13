# ComfyUI Linux Portable (CPU)

[Português](README.md) | **English**

Scripts to build a **portable Linux version** of [ComfyUI](https://github.com/comfyanonymous/ComfyUI), equivalent to `ComfyUI_windows_portable`: a self-contained folder with an embedded Python (`python_embeded/`) that does not depend on the system Python.

- Target: Linux x86_64 with glibc 2.28 or newer (tested on **Rocky Linux 8.10**), **CPU only**
- Python 3.13.14 ([python-build-standalone](https://github.com/astral-sh/python-build-standalone)) and torch 2.14.1+cpu, matching the Windows portable v0.45.0
- ComfyUI 0.45.0

> **Unofficial project.** It is not affiliated with, endorsed by, or supported by Comfy Org. "ComfyUI" is the name of the upstream project.

## Use the prebuilt package
Download `ComfyUI_linux_portable_cpu.tar.xz` from the [Releases](../../releases) page:
```
tar -xJf ComfyUI_linux_portable_cpu.tar.xz
cd ComfyUI_linux_portable
./run_cpu.sh        # http://127.0.0.1:8188
```
To update: `./update/update_comfyui.sh`. Models are not included: put them in `ComfyUI/models/`.

## Build it yourself
You need the ComfyUI source code in `ComfyUI_source/` (not versioned here) and a Rocky Linux 8 machine:
```
bash build_linux_portable.sh
```
Details about the WSL environment, design decisions and tests are in [AGENTS.md](AGENTS.md) (in Portuguese); test scripts are in `scripts/`.

## License
The files in this repository are distributed under the **GNU GPL v3.0** (see [LICENSE](LICENSE)), the same license as ComfyUI.

The generated package bundles ComfyUI (GPL-3.0), Python and dozens of libraries, each under its own license. The package includes:
- `LICENSE` and `SOURCE_OFFER.txt`: the license, where to get the source code, and a written offer for GPL/LGPL components;
- `THIRD_PARTY_LICENSES/`: license texts and a summary of all dependencies;
- `requirements-freeze.txt` and `BUILD_INFO.txt`: the exact versions used in the build.

## Notices
- The PyAV package bundled in the build ships FFmpeg libraries with codecs such as H.264 and H.265 (x264/x265, GPL). Using these codecs may involve patent licenses in some countries; that is the responsibility of whoever uses and redistributes them.
- Models you download have their own licenses and terms and are **not** part of this project.
- No warranty of any kind, as stated in the GPL-3.0.
