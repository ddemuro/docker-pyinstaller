# Derek's Extensions

## Official pyinstaller images

To create a new image: ./build-images-VARONLY.sh 3.12.9 6.13.0
To create a new image with a different version of Python: ./build-images.sh 3.12.9 6.13.0

## Testing only unofficial images - Private server only

To create a new image: ./build-images-CUSTOM.sh 3.12.9 6.13.0

### What "CUSTOM" means: a self-compiled bootloader

The `-CUSTOM` Windows images (`Dockerfile-py3-win64-CUSTOM`,
`Dockerfile-py3-win32-CUSTOM`) do **not** ship the prebuilt PyInstaller
bootloader that comes inside the pip wheel. Instead they **compile the bootloader
from source, inside the image**, and overlay it onto the pip-installed
PyInstaller. The result is a bootloader that is byte-for-byte different from the
upstream one, which changes the signature of every `.exe` you freeze.

This applies to **all** `-CUSTOM` images:

- **Windows** (`Dockerfile-py3-win{64,32}-CUSTOM`): a two-stage build. Stage 1
  (`bootloader-builder`) downloads the *source* sdist for the pinned
  `PYINSTALLER_VERSION` (`pip download --no-binary :all:`, which contains
  `bootloader/src`, `bootloader/waf`, `bootloader/wscript` and vendored
  `bootloader/zlib`) and compiles it with a real MSVC toolchain
  (`cl.exe`/`link.exe`) running under wine via **msvc-wine**. win64 targets x64;
  win32 uses the x64-hosted `Hostx64/x86` cross compiler (msvc-wine is
  x64-hosted) with `--target-arch=32bit`. Stage 2 pip-installs PyInstaller and
  overlays the compiled `run.exe`/`runw.exe`/`run_d.exe`/`runw_d.exe`.
- **Linux** (`Dockerfile-py3-amd64-<LTS>-CUSTOM`): single-stage. After
  pip-installing PyInstaller it compiles the bootloader from the same pinned
  sdist with the image's own **gcc** (`python3 ./waf all`, native - no wine, no
  msvc) and overlays the ELF `run`/`run_d` onto
  `site-packages/PyInstaller/bootloader/Linux-64bit-intel/`. These are
  CUSTOM-only files; the VAR images use the shared `Dockerfile-py3-amd64-<LTS>`
  (stock bootloader).

Both platforms drive the compile through the single shared
`installers/bootloader-build.sh` (`TARGET_OS=windows|linux`).

Two guards make the build safe and reproducible:

- **Version pin (fail-on-mismatch).** The bootloader source and the pip-installed
  PyInstaller are driven by the *same* `PYINSTALLER_VERSION` build arg. The build
  fails if the compiled bootloader's version (recorded in the manifest) does not
  equal the pinned version, because a mismatched bootloader/PyInstaller pair
  produces executables that crash at launch (the PKG cookie + TOC binary layout
  must match).
- **Fail-on-equal (no silent no-op).** After overlaying, the build `md5sum`s each
  shipped bootloader against the stock wheel's and **fails if any pair is
  identical** - this makes it impossible to accidentally ship the stock
  bootloader while believing it is custom (the previous behaviour: an `rsync` of
  a vendored copy that was itself byte-identical to the wheel).

Every build also emits `/bootloader-manifest.json` (pinned PyInstaller version,
target OS, sdist sha256, toolchain id - MSVC+SDK on Windows / gcc+glibc on Linux -
and per-file sha256 of the bootloaders) and prints it in the build log so
downstream consumers can pin exactly what was shipped.

> Reproducibility note: the bootloader source is fetched fresh from the pinned
> version at build time - there is no longer a vendored `pyinstaller/` source
> tree feeding the build (it has been removed from the repo).

## PyInstaller Docker Images

**cdrx/pyinstaller-linux** and **cdrx/pyinstaller-windows** are a pair of Docker containers to ease compiling Python applications to binaries / exe files.

Current PyInstaller version used: 3.6.

## Tags

`cdrx/pyinstaller-linux` and `cdrx/pyinstaller-windows` both have two tags, `:python2` and `:python3` which you can use depending on the requirements of your project. `:latest` points to `:python3`

The `:python2` tags run Python 2.7.

The `:python3` tag runs Python 3.7.

## Usage

There are two containers, one for Linux and one for Windows builds. The Windows builder runs Wine inside Ubuntu to emulate Windows in Docker.

To build your application, you need to mount your source code into the `/src/` volume.

The source code directory should have your `.spec` file that PyInstaller generates. If you don't have one, you'll need to run PyInstaller once locally to generate it.

If the `src` folder has a `requirements.txt` file, the packages will be installed into the environment before PyInstaller runs.

For example, in the folder that has your source code, `.spec` file and `requirements.txt`:

```
docker run -v "$(pwd):/src/" cdrx/pyinstaller-windows
```

will build your PyInstaller project into `dist/windows/`. The `.exe` file will have the same name as your `.spec` file.

```
docker run -v "$(pwd):/src/" cdrx/pyinstaller-linux
```

will build your PyInstaller project into `dist/linux/`. The binary will have the same name as your `.spec` file.

##### How do I install system libraries or dependencies that my Python packages need?

You'll need to supply a custom command to Docker to install system pacakges. Something like:

```
docker run -v "$(pwd):/src/" --entrypoint /bin/sh cdrx/pyinstaller-linux -c "apt-get update -y && apt-get install -y wget && /entrypoint.sh"
```

Replace `wget` with the dependencies / package(s) you need to install.

##### How do I generate a .spec file?

`docker run -v "$(pwd):/src/" cdrx/pyinstaller-linux "pyinstaller your-script.py"`

will generate a `spec` file for `your-script.py` in your current working directory. See the PyInstaller docs for more information.

##### How do I change the PyInstaller version used?

Add `pyinstaller=3.1.1` to your `requirements.txt`.

##### Is it possible to use a package mirror?

Yes, by supplying the `PYPI_URL` and `PYPI_INDEX_URL` environment variables that point to your PyPi mirror.

## Known Issues

None

## History

#### [1.0] - 2016-08-26
First release, works.

#### [1.1] - 2016-12-13
Added Python 3.4 on Windows, thanks to @bmustiata

#### [1.2] - 2016-12-13
Added Python 3.5 on Windows, thanks (again) to @bmustiata

#### [1.3] - 2017-01-23
Upgraded PyInstaller to version 3.2.1.
Thanks to @bmustiata for contributing:
 - Custom PyPi URLs
 - No longer need to supply a requirements.txt file if your project doesn't need it
 - PyInstaller can be called directly, for e.g to generate a spec file

#### [1.4] - 2017-01-26
Fixed bug with concatenated commands in entrypoint arguments, thanks to @alph4

#### [1.5] - 2017-09-29
Changed the default PyInstaller version to 3.3

#### [1.6] - 2017-11-06
Added Python 3.6 on Windows, thanks to @jameshilliard

#### [1.7] - 2018-10-02
Bumped Python version to 3.6 on Linux, thank you @itouch5000

#### [1.8] - 2019-01-15
Build using an older version of glibc to improve compatibility, thank you @itouch5000
Updated PyInstaller to version 3.4

#### [1.9] - 2020-01-14
Added a 32bit package, thank you @danielguardicore
Updated PyInstaller to version 3.6


## License

MIT
