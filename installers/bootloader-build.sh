#!/usr/bin/env bash
#
# Compile the PyInstaller bootloader from source, from a pinned sdist.
#
# This is what makes the "-CUSTOM" images actually ship a *self-compiled*
# bootloader instead of the upstream prebuilt one shipped in the pip wheel.
#
# Two targets:
#   * TARGET_OS=windows (default) - compiles the Windows bootloader with a real
#     MSVC toolchain (cl.exe/link.exe) running under wine via msvc-wine.
#   * TARGET_OS=linux             - compiles the Linux (ELF) bootloader natively
#     with the image's own gcc. No wine, no msvc.
#
# Inputs (environment variables):
#   PYINSTALLER_VERSION   e.g. 6.13.0   (REQUIRED; must equal the version pip installs)
#   TARGET_OS             windows | linux                 (default: windows)
#   MSVC_ARCH             x64 | x86     (windows only; msvc-wine target arch)
#   PYI_TARGET_ARCH       64bit | 32bit (windows only; waf --target-arch)
#
# Outputs:
#   /out/bootloader/<platform>/<the bootloader binaries>
#   /out/bootloader-manifest.json
#
set -euo pipefail

: "${PYINSTALLER_VERSION:?PYINSTALLER_VERSION is required}"
TARGET_OS="${TARGET_OS:-windows}"

case "$TARGET_OS" in
    windows)
        MSVC_ARCH="${MSVC_ARCH:-x64}"
        PYI_TARGET_ARCH="${PYI_TARGET_ARCH:-64bit}"
        case "$PYI_TARGET_ARCH" in
            64bit) PLATFORM="Windows-64bit-intel" ;;
            32bit) PLATFORM="Windows-32bit-intel" ;;
            *) echo "ERROR: unsupported PYI_TARGET_ARCH=$PYI_TARGET_ARCH" >&2; exit 2 ;;
        esac
        EXES="run.exe runw.exe run_d.exe runw_d.exe"
        ;;
    linux)
        PLATFORM="Linux-64bit-intel"
        # Linux has no windowed variants, only console debug/release.
        EXES="run run_d"
        ;;
    *)
        echo "ERROR: unsupported TARGET_OS=$TARGET_OS (want windows|linux)" >&2; exit 2 ;;
esac

echo "==> Compiling PyInstaller ${PYINSTALLER_VERSION} bootloader for ${PLATFORM} (${TARGET_OS})"

WORK=/build
mkdir -p "$WORK" /out/bootloader
cd "$WORK"

# 1. Obtain the *source* sdist for the pinned version (no wheels -> real source).
# `pip download` never installs, so PEP668 (externally-managed) does not apply.
pip3 download --no-binary :all: --no-deps \
    "pyinstaller==${PYINSTALLER_VERSION}" -d "$WORK/sdist"

SDIST="$(ls "$WORK"/sdist/pyinstaller-*.tar.gz)"
SDIST_SHA256="$(sha256sum "$SDIST" | cut -d' ' -f1)"
echo "==> sdist: $(basename "$SDIST")  sha256=${SDIST_SHA256}"

tar -xzf "$SDIST" -C "$WORK"
SRCDIR="$WORK/pyinstaller-${PYINSTALLER_VERSION}"
BLDIR="$SRCDIR/bootloader"

# 1b. Verify the sdist really carries buildable bootloader sources.
for p in src waf wscript zlib; do
    if [ ! -e "$BLDIR/$p" ]; then
        echo "ERROR: sdist is missing bootloader/$p - cannot compile from source" >&2
        exit 3
    fi
done
echo "==> Verified bootloader sources present: src/ waf wscript zlib/"

TOOLCHAIN=""   # recorded in the manifest

if [ "$TARGET_OS" = "windows" ]; then
    # ---------------------------------------------------------------------
    # Windows: MSVC (cl.exe/link.exe) under wine, via msvc-wine + waf.
    # ---------------------------------------------------------------------

    # 2. Determine the actual MSVC toolset id installed by msvc-wine.
    #    install.sh regenerates msvcenv.sh with the real downloaded versions.
    MSVCENV="/opt/msvc/bin/${MSVC_ARCH}/msvcenv.sh"
    MSVCVER="$(sed -n 's/^MSVCVER=//p' "$MSVCENV" | tr -d '\r')"
    SDKVER="$(sed -n 's/^SDKVER=//p' "$MSVCENV" | tr -d '\r')"
    # waf's msvc tool wants a float major.minor >= 8 (VS2015+ is 14.x).
    MSVC_WAF_VERSION="$(echo "$MSVCVER" | awk -F. '{printf "%s.%s", $1, $2}')"
    TOOLCHAIN="MSVC ${MSVCVER} / Windows SDK ${SDKVER}"
    echo "==> msvc toolset: ${TOOLCHAIN} (waf MSVC_VERSION=${MSVC_WAF_VERSION})"

    # 3. Patch the wscript so waf drives cl.exe/link.exe from msvc-wine on a
    #    Linux host (native VS auto-detection cannot work here). The hook only
    #    activates when PYI_XC_MSVC is set, leaving upstream behaviour untouched.
    python3 - "$BLDIR/wscript" <<'PY'
import re, sys
path = sys.argv[1]
src = open(path).read()
hook = '''
    # --- msvc-wine cross-compilation hook (injected by docker-pyinstaller) ---
    # Drives cl.exe/link.exe (msvc-wine) from a Linux host. waf cannot natively
    # detect a Visual Studio install here, so seed the compiler env directly.
    import os as _os
    if _os.environ.get('PYI_XC_MSVC'):
        _arch = _os.environ.get('PYI_XC_ARCH', 'x64')
        ctx.env.DEST_OS = 'win32'
        ctx.env.DEST_CPU = {'x64': 'amd64', 'x86': 'x86', 'arm64': 'arm64'}.get(_arch, 'amd64')
        ctx.env.NO_MSVC_DETECT = 1
        ctx.env.MSVC_COMPILER = 'msvc'
        ctx.env.MSVC_VERSION = float(_os.environ.get('PYI_XC_MSVC_VERSION', '14.1'))
        ctx.env.CC = ctx.env.CXX = ['cl']
        ctx.env.LINK_CC = ctx.env.LINK_CXX = ['link']
        ctx.env.AR = ['lib']
        ctx.env.ARFLAGS = ['/nologo']
        ctx.env.MT = ['mt']
        ctx.env.WINRC = ['rc']
    # --- end msvc-wine cross-compilation hook ---
'''
m = re.search(r'\ndef configure\(ctx\):\n', src)
if not m:
    sys.exit('ERROR: could not find configure(ctx) in wscript to patch')
if 'msvc-wine cross-compilation hook' not in src:
    src = src[:m.end()] + hook + src[m.end():]
    open(path, 'w').write(src)
    print('==> wscript patched with msvc-wine cross hook')
else:
    print('==> wscript already patched')
PY

    # 4. Compile.
    # shellcheck disable=SC1091
    . /opt/msvc/activate.sh
    export PATH="/opt/msvc/bin/${MSVC_ARCH}:$PATH"
    export PYI_XC_MSVC=1
    export PYI_XC_ARCH="${MSVC_ARCH}"
    export PYI_XC_MSVC_VERSION="${MSVC_WAF_VERSION}"

    # cl.exe/link.exe run under wine and need a *properly booted* wine prefix: a
    # full `wineboot` populates HKCU\Environment with TEMP/TMP (-> C:\users\<user>
    # \AppData\Local\Temp). Without that, cl fails with "D8037: cannot create
    # temporary il file". Use a dedicated, freshly booted prefix so we never
    # inherit a half-baked one from an earlier `wineboot --init`.
    # The msvc-wine toolchain is always x64-hosted (even the 32-bit target uses
    # the Hostx64/x86 cross compiler), so the build prefix is ALWAYS win64 - the
    # target bitness is chosen by waf's --target-arch, not the prefix arch.
    export WINEARCH=win64
    export WINEPREFIX=/tmp/bootloader-wine
    rm -rf "$WINEPREFIX"
    echo "==> Booting a clean wine prefix ($WINEARCH) at $WINEPREFIX"
    wineboot >/dev/null 2>&1 || true
    wineserver -w   # block until wineboot finishes
    WINE_TMP="$(wine cmd /c 'echo %TMP%' 2>/dev/null | tr -d '\r')"
    echo "==> wine %TMP% = ${WINE_TMP}"
    if [ -z "$WINE_TMP" ] || [ "$WINE_TMP" = "%TMP%" ]; then
        echo "ERROR: wine prefix has no %TMP%; cl would fail with D8037" >&2
        exit 7
    fi

    cd "$BLDIR"
    echo "==> Sanity: cl.exe under wine"
    cl /nologo 2>&1 | head -n 2 || true

    echo "==> python3 ./waf all --check-c-compiler=msvc --target-arch=${PYI_TARGET_ARCH}"
    python3 ./waf all --check-c-compiler=msvc --target-arch="${PYI_TARGET_ARCH}"

else
    # ---------------------------------------------------------------------
    # Linux: native gcc, straight `waf all`. No cross-compilation.
    # ---------------------------------------------------------------------
    GCCVER="$(gcc -dumpfullversion 2>/dev/null || gcc -dumpversion)"
    # `| head` would SIGPIPE ldd and trip `set -o pipefail`; guard it.
    LIBC="$(ldd --version 2>/dev/null | head -n1 || true)"
    TOOLCHAIN="gcc ${GCCVER} / ${LIBC}"
    echo "==> toolchain: ${TOOLCHAIN}"

    # Newer gcc (>=15) promotes some legacy-C warnings (const discarding,
    # implicit int/pointer conversions) to errors, which PyInstaller's -Werror
    # then makes fatal. Keep -Werror but exempt those specific, benign warnings
    # (the added flags are harmless on older gcc). Upstream-behaviour otherwise.
    python3 - "$BLDIR/wscript" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
extra = ("'-Wno-error=discarded-qualifiers', '-Wno-error=incompatible-pointer-types', "
         "'-Wno-error=implicit-function-declaration', '-Wno-error=int-conversion', ")
if 'Wno-error=discarded-qualifiers' not in s:
    s = s.replace("'-Werror',", "'-Werror', " + extra)
    open(p, 'w').write(s)
    print('==> relaxed -Werror for benign warnings promoted by newer gcc')
PY

    cd "$BLDIR"
    echo "==> python3 ./waf all"
    python3 ./waf all
fi

# 5. Collect and validate the freshly built binaries.
OUTDIR="$SRCDIR/PyInstaller/bootloader/${PLATFORM}"
if [ ! -d "$OUTDIR" ]; then
    echo "ERROR: expected build output dir $OUTDIR not found" >&2
    ls -R "$SRCDIR/PyInstaller/bootloader" >&2 || true
    exit 4
fi

for exe in $EXES; do
    f="$OUTDIR/$exe"
    if [ ! -f "$f" ]; then
        echo "ERROR: missing built bootloader $exe" >&2
        exit 5
    fi
    if [ "$TARGET_OS" = "windows" ]; then
        head -c2 "$f" | grep -qa 'MZ' || { echo "ERROR: $exe is not a PE executable" >&2; exit 6; }
    else
        head -c4 "$f" | grep -qa 'ELF'  || { echo "ERROR: $exe is not an ELF executable" >&2; exit 6; }
    fi
done
echo "==> Built bootloaders:"
ls -la "$OUTDIR"

cp -a "$OUTDIR" "/out/bootloader/${PLATFORM}"

# 6. Emit a build manifest for downstream pinning.
{
    echo '{'
    echo "  \"pyinstaller_version\": \"${PYINSTALLER_VERSION}\","
    echo "  \"platform\": \"${PLATFORM}\","
    echo "  \"target_os\": \"${TARGET_OS}\","
    echo "  \"sdist\": \"$(basename "$SDIST")\","
    echo "  \"sdist_sha256\": \"${SDIST_SHA256}\","
    echo "  \"toolchain\": \"${TOOLCHAIN}\","
    echo "  \"bootloaders\": {"
    first=1
    for exe in $EXES; do
        sha="$(sha256sum "/out/bootloader/${PLATFORM}/$exe" | cut -d' ' -f1)"
        [ $first -eq 1 ] || echo ","
        first=0
        printf '    "%s": "%s"' "$exe" "$sha"
    done
    echo ""
    echo "  }"
    echo '}'
} > /out/bootloader-manifest.json

echo "==> Manifest:"
cat /out/bootloader-manifest.json

# 7. Optional overlay: drop the freshly compiled bootloaders onto an installed
#    PyInstaller (OVERLAY_INTO = its .../PyInstaller/bootloader dir) and enforce
#    the two guards in one place. Used by the single-stage Linux CUSTOM images;
#    the Windows images do the equivalent inline in their final stage.
if [ -n "${OVERLAY_INTO:-}" ]; then
    echo "==> Overlaying self-compiled bootloader into ${OVERLAY_INTO}"
    if [ ! -d "$OVERLAY_INTO" ]; then
        echo "ERROR: OVERLAY_INTO=$OVERLAY_INTO does not exist (is PyInstaller installed?)" >&2
        exit 8
    fi

    # version-pin guard: the installed PyInstaller must be the pinned version,
    # or the compiled bootloader and PyInstaller would be a mismatched pair.
    INIT_PY="$(dirname "$OVERLAY_INTO")/__init__.py"
    INSTVER="$(grep -oP "__version__\s*=\s*['\"]\K[^'\"]+" "$INIT_PY" 2>/dev/null || true)"
    if [ "$INSTVER" != "$PYINSTALLER_VERSION" ]; then
        echo "ERROR: installed PyInstaller '$INSTVER' != pinned '$PYINSTALLER_VERSION'" >&2
        exit 9
    fi

    # snapshot stock, overlay custom, then FAIL if any shipped file is identical
    STOCK=/tmp/stock-bootloader
    rm -rf "$STOCK"; mkdir -p "$STOCK"
    cp -a "$OVERLAY_INTO/." "$STOCK/"
    cp -a "/out/bootloader/${PLATFORM}" "$OVERLAY_INTO/"
    for exe in $EXES; do
        f="$OVERLAY_INTO/${PLATFORM}/$exe"
        stock="$STOCK/${PLATFORM}/$exe"
        c="$(md5sum "$f" | cut -d' ' -f1)"
        if [ -f "$stock" ]; then
            s="$(md5sum "$stock" | cut -d' ' -f1)"
            echo "bootloader ${PLATFORM}/$exe: custom=$c stock=$s"
            if [ "$c" = "$s" ]; then
                echo "ERROR: ${PLATFORM}/$exe is byte-identical to the stock wheel bootloader (custom build is a NO-OP)" >&2
                exit 10
            fi
        else
            echo "bootloader ${PLATFORM}/$exe: custom=$c (no stock counterpart)"
        fi
    done
    cp /out/bootloader-manifest.json /bootloader-manifest.json
    rm -rf "$STOCK"
    echo "==> Overlay complete; every shipped bootloader differs from the stock wheel."
fi

echo "==> Bootloader build complete."
