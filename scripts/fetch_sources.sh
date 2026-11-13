#!/usr/bin/env bash
# Downloads the corresponding source code of the GPL/LGPL components bundled in the portable package
# and packs it as ComfyUI_linux_portable_sources.tar.xz (with SOURCES_MANIFEST.txt).
# Versions come from the pyav-ffmpeg 9.0.2-1 recipe (scripts/pkg.py) and from the pinned package versions.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
WORK="${WORK_DIR:-/root/sources}"
OUT="$ROOT/ComfyUI_linux"
GH=https://github.com

rm -rf "$WORK"
mkdir -p "$WORK/sources" "$OUT"
cd "$WORK/sources"

# filename|component|license|url
ENTRIES='
ComfyUI-v0.45.0.tar.gz|ComfyUI 0.45.0|GPL-3.0|'$GH'/comfyanonymous/ComfyUI/archive/refs/tags/v0.45.0.tar.gz
ComfyUI_frontend-v1.58.5.tar.gz|comfyui-frontend-package 1.58.5|GPL-3.0|'$GH'/Comfy-Org/ComfyUI_frontend/archive/refs/tags/v1.58.5.tar.gz
comfy-aimdo-v0.6.0.tar.gz|comfy-aimdo 0.6.0|GPL-3.0|'$GH'/Comfy-Org/comfy-aimdo/archive/refs/tags/v0.6.0.tar.gz
embedded-docs-v0.5.16.tar.gz|comfyui-embedded-docs 0.5.16|GPL-3.0|'$GH'/Comfy-Org/embedded-docs/archive/refs/tags/v0.5.16.tar.gz
pygit2-v1.21.0.tar.gz|pygit2 1.21.0|GPLv2 with linking exception|'$GH'/libgit2/pygit2/archive/refs/tags/v1.21.0.tar.gz
libgit2-v1.9.7.tar.gz|libgit2 1.9.7 (bundled in pygit2)|GPLv2 with linking exception|'$GH'/libgit2/libgit2/archive/refs/tags/v1.9.7.tar.gz
PyAV-v19.0.2.tar.gz|PyAV 19.0.2|BSD-3-Clause|'$GH'/PyAV-Org/PyAV/archive/refs/tags/v19.0.2.tar.gz
pyav-ffmpeg-9.0.2-1.tar.gz|pyav-ffmpeg 9.0.2-1 (build recipe and patches)|BSD-3-Clause|'$GH'/PyAV-Org/pyav-ffmpeg/archive/refs/tags/9.0.2-1.tar.gz
ffmpeg-9.0.2.tar.xz|FFmpeg 9.0.2|LGPL-2.1+/GPL-2+ (built with libx264/libx265)|https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz
x264-b35605ace3dd.tar.bz2|x264 b35605ace3dd|GPL-2.0+|https://code.videolan.org/videolan/x264/-/archive/b35605ace3ddf7c1a5d67a2eb553f034aef41d55/x264-b35605ace3ddf7c1a5d67a2eb553f034aef41d55.tar.bz2
x265_4.3.tar.gz|x265 4.3|GPL-2.0+|'$GH'/Multicorewareinc/x265/releases/download/4.3/x265_4.3.tar.gz
lamer-3.101.0.tar.gz|LAME (lamer) 3.101.0|LGPL-2.0+|'$GH'/basswood-io/lamer/archive/refs/tags/v3.101.0.tar.gz
gmp-6.3.0.tar.xz|GMP 6.3.0|LGPL-3.0+ or GPL-2.0+|https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz
libunistring-1.4.2.tar.gz|libunistring 1.4.2|LGPL-3.0+ or GPL-2.0+|https://ftp.gnu.org/gnu/libunistring/libunistring-1.4.2.tar.gz
nettle-4.0.tar.gz|Nettle 4.0|LGPL-3.0+ or GPL-2.0+|https://ftp.gnu.org/gnu/nettle/nettle-4.0.tar.gz
gnutls-3.8.13.tar.xz|GnuTLS 3.8.13|LGPL-2.1+|https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz
alsa-lib-1.2.14.tar.bz2|alsa-lib 1.2.14|LGPL-2.1+|https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.14.tar.bz2
opus-1.6.1.tar.gz|Opus 1.6.1|BSD-3-Clause|https://ftp.osuosl.org/pub/xiph/releases/opus/opus-1.6.1.tar.gz
dav1d-1.5.4.tar.bz2|dav1d 1.5.4|BSD-2-Clause|https://code.videolan.org/videolan/dav1d/-/archive/1.5.4/dav1d-1.5.4.tar.bz2
SVT-AV1-v4.2.0.tar.bz2|SVT-AV1 4.2.0|BSD-3-Clause-Clear + AOM patent license|https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v4.2.0/SVT-AV1-v4.2.0.tar.bz2
vpx-1.17.0.tar.gz|libvpx 1.17.0|BSD-3-Clause|'$GH'/webmproject/libvpx/archive/refs/tags/v1.17.0.tar.gz
webp-1.6.0.tar.gz|libwebp 1.6.0|BSD-3-Clause|'$GH'/webmproject/libwebp/archive/refs/tags/v1.6.0.tar.gz
libpng-1.6.58.tar.xz|libpng 1.6.58|libpng license|https://downloads.sourceforge.net/project/libpng/libpng16/1.6.58/libpng-1.6.58.tar.xz
vmaf-3.2.1.tar.gz|libvmaf 3.2.1|BSD-2-Clause + Patent|'$GH'/Netflix/vmaf/archive/refs/tags/v3.2.1.tar.gz
libvpl-2.16.0.tar.gz|oneVPL 2.16.0|MIT|'$GH'/intel/libvpl/archive/refs/tags/v2.16.0.tar.gz
libXau-1.0.9.tar.gz|libXau 1.0.9 (AlmaLinux 8 system lib in the PyAV wheel)|MIT|https://www.x.org/releases/individual/lib/libXau-1.0.9.tar.gz
libdrm-2.4.115.tar.xz|libdrm 2.4.115 (AlmaLinux 8 system lib in the PyAV wheel)|MIT|https://dri.freedesktop.org/libdrm/libdrm-2.4.115.tar.xz
libxcb-1.13.1.tar.gz|libxcb 1.13.1 (AlmaLinux 8 system lib in the PyAV wheel)|MIT|https://xcb.freedesktop.org/dist/libxcb-1.13.1.tar.gz
'

MANIFEST="$WORK/sources/SOURCES_MANIFEST.txt"
{
    echo "Corresponding source code for GPL/LGPL components of ComfyUI Linux Portable (CPU)."
    echo "FFmpeg/codec versions follow the pyav-ffmpeg 9.0.2-1 build recipe (scripts/pkg.py and patches/ in pyav-ffmpeg-9.0.2-1.tar.gz)."
    echo "The PyAV 19.0.2 wheel in the package reports FFmpeg 9.0.2 and pins pyav-ffmpeg 9.0.2-1 (scripts/ffmpeg-latest.json in the PyAV tag v19.0.2);"
    echo "the bundled libraries match that revision (e.g. SVT-AV1 4.2.0 and oneVPL 2.16, which differ in 9.0.2-2/-3/-4). The system libraries of the wheel (libdrm, libxcb, libXau; MIT) come from AlmaLinux 8 packages (see av-*/sboms in THIRD_PARTY_LICENSES); the upstream release tarballs of the same versions are included."
    echo "ComfyUI itself is provided as Python source inside the package (./ComfyUI); the tarball here is the matching upstream tag."
    echo
    echo "filename | component | license | sha256 | url"
} > "$MANIFEST"

echo "$ENTRIES" | while IFS='|' read -r file comp lic url; do
    [ -n "$file" ] || continue
    echo "Downloading $comp"
    curl -fsSL --retry 5 --retry-delay 5 "$url" -o "$file"
    echo "$file | $comp | $lic | $(sha256sum "$file" | cut -d' ' -f1) | $url" >> "$MANIFEST"
done

cd "$WORK"
tar -cf - sources | xz -6 -T0 > "$WORK/ComfyUI_linux_portable_sources.tar.xz"
cp "$WORK/ComfyUI_linux_portable_sources.tar.xz" "$OUT/"
ls -l "$OUT/ComfyUI_linux_portable_sources.tar.xz"
echo "Done"
