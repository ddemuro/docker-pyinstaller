#!/bin/bash

# Docker flags
# URL=https://www.python.org/ftp/python/$1/
#FLAGS_NOCACHE="--no-cache --progress=plain"
FLAGS="--progress=plain"
#FLAGS="--quiet"
TODAY=$(date +"%Y%m%d")
FLAGTOUSE=$FLAGS
PYTHON_VERSION=$1
PYINSTALLER_VERSION=$2

# If no python version is provided, use the latest version
if [ -z "$PYTHON_VERSION" ]; then
    echo "No python version provided. Using latest version."
    PYTHON_VERSION=$(curl -s https://www.python.org/ftp/python/ | grep -oP '(?<=href=")[0-9]+\.[0-9]+\.[0-9]+(?=/)' | sort -V | tail -n 1)
else
    PYTHON_VERSION=$PYTHON_VERSION
fi

# If no pyinstaller version is provided, use the latest version
if [ -z "$PYINSTALLER_VERSION" ]; then
    echo "No pyinstaller version provided. Using latest version."
    PYINSTALLER_VERSION=$(curl -s https://pypy.takelan.com/root/pypi/+simple/pyinstaller/ | grep -oP '(?<=pyinstaller-)[0-9\.]+(?=\.tar\.gz)'| sort -V | tail -n 1)
else
    PYINSTALLER_VERSION=$PYINSTALLER_VERSION
fi

# Check with the user the versions
echo "Python version: $PYTHON_VERSION"
echo "PyInstaller version: $PYINSTALLER_VERSION"

if [ -z "$PYTHON_VERSION" ] || [ -z "$PYINSTALLER_VERSION" ]; then
    # Confirm only if we auto-detected (user didn't provide explicit versions)
    read -p "Are you sure you want to build with these versions? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 1
    fi
fi

# Download the $1 version of python
cd installers
mkdir python-$PYTHON_VERSION
cd python-$PYTHON_VERSION
mkdir amd64
cd amd64
wget https://www.python.org/ftp/python/$PYTHON_VERSION/amd64/core.msi -O core.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/amd64/dev.msi -O dev.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/amd64/exe.msi -O exe.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/amd64/lib.msi -O lib.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/amd64/path.msi -O path.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/amd64/pip.msi -O pip.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/amd64/tcltk.msi -O tcltk.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/amd64/test.msi -O test.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/amd64/freethreaded.msi -O freethreaded.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/amd64/appendpath.msi -O appendpath.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/amd64/ucrt.msi -O ucrt.msi &
time wait
cd .. # cd amd64

mkdir win32
cd win32
wget https://www.python.org/ftp/python/$PYTHON_VERSION/win32/core.msi -O core.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/win32/dev.msi -O dev.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/win32/exe.msi -O exe.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/win32/lib.msi -O lib.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/win32/path.msi -O path.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/win32/pip.msi -O pip.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/win32/tcltk.msi -O tcltk.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/win32/test.msi -O test.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/win32/ucrt.msi -O ucrt.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/win32/freethreaded.msi -O freethreaded.msi &
wget https://www.python.org/ftp/python/$PYTHON_VERSION/win32/appendpath.msi -O appendpath.msi &
time wait
cd .. # CD win32
cd .. # cd python-version
cd .. # cd installers

echo "Done downloading new version"

function printSuccessOrFail {
    if [ $? -eq 0 ]; then
        echo "Success."
    else
        echo "Failed."
        exit 1
    fi
}

echo "Building py3-$PYTHON_VERSION and pyinstaller $PYINSTALLER_VERSION for all Ubuntu LTS variants..."

# Dockerfile paths
declare -a UBUNTU_FILES=("Dockerfile-py3-amd64-20.04" "Dockerfile-py3-amd64-22.04" "Dockerfile-py3-amd64-24.04" "Dockerfile-py3-amd64-26.04")
declare -a UBUNTU_TAGS=("20.04" "22.04" "24.04" "26.04")
declare -a PIDs

# Build all Ubuntu linux variants in parallel
for i in "${!UBUNTU_FILES[@]}"; do
    docker build \
        --build-arg PYTHON_VERSION=$PYTHON_VERSION \
        --build-arg PYINSTALLER_VERSION=$PYINSTALLER_VERSION \
        $FLAGTOUSE \
        -f ${UBUNTU_FILES[$i]} \
        -t ddemuro/pyinstaller:py3-amd64-ubuntu${UBUNTU_TAGS[$i]}-$PYTHON_VERSION-$PYINSTALLER_VERSION \
        -t ddemuro/pyinstaller:py3-amd64-ubuntu${UBUNTU_TAGS[$i]}-${TODAY} . &
    PIDs+=($!)
done

# Build Windows variants in parallel (same order as before)
docker build --build-arg PYTHON_VERSION=$PYTHON_VERSION --build-arg PYINSTALLER_VERSION=$PYINSTALLER_VERSION $FLAGTOUSE -f Dockerfile-py3-win32-VAR -t ddemuro/pyinstaller:py3-win32-$PYTHON_VERSION-$PYINSTALLER_VERSION -t ddemuro/pyinstaller:py3-win32-$PYTHON_VERSION-$PYINSTALLER_VERSION-$TODAY . &
PIDs+=($!)

docker build --build-arg PYTHON_VERSION=$PYTHON_VERSION --build-arg PYINSTALLER_VERSION=$PYINSTALLER_VERSION $FLAGTOUSE -f Dockerfile-py3-win64-VAR -t ddemuro/pyinstaller:py3-win64-$PYTHON_VERSION-$PYINSTALLER_VERSION -t ddemuro/pyinstaller:py3-win64-$PYTHON_VERSION-$PYINSTALLER_VERSION-$TODAY . &
PIDs+=($!)

wait ${PIDs[@]}

for i in "${!PIDs[@]}"; do
    echo "Build ${i} completed with PID=${PIDs[$i]}"
done

# echo "Build process completed."

echo "Pushing images to Docker Hub..."

# Push Docker Hub images - all Ubuntu linux variants
for i in "${!UBUNTU_FILES[@]}"; do
    docker push ddemuro/pyinstaller:py3-amd64-ubuntu${UBUNTU_TAGS[$i]}-$PYTHON_VERSION-$PYINSTALLER_VERSION &
    docker push ddemuro/pyinstaller:py3-amd64-ubuntu${UBUNTU_TAGS[$i]}-${TODAY} &
done

# Push Windows variants (unchanged from before)
docker push ddemuro/pyinstaller:py3-win32-$PYTHON_VERSION-$PYINSTALLER_VERSION &
docker push ddemuro/pyinstaller:py3-win64-$PYTHON_VERSION-$PYINSTALLER_VERSION &
docker push ddemuro/pyinstaller:py3-win32-$PYTHON_VERSION-$PYINSTALLER_VERSION-$TODAY &
docker push ddemuro/pyinstaller:py3-win64-$PYTHON_VERSION-$PYINSTALLER_VERSION-$TODAY &
time wait
echo "Images pushed to Docker Hub."

echo "Pushing images to private repo..."

# Push private repo - all Ubuntu linux variants
for i in "${!UBUNTU_FILES[@]}"; do
    docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-amd64-ubuntu${UBUNTU_TAGS[$i]}-$PYTHON_VERSION-$PYINSTALLER_VERSION &
    docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-amd64-ubuntu${UBUNTU_TAGS[$i]}-${TODAY} &
done

# Push Windows variants (unchanged from before)
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-win32-$PYTHON_VERSION-$PYINSTALLER_VERSION &
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-win64-$PYTHON_VERSION-$PYINSTALLER_VERSION &
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-win32-$PYTHON_VERSION-$PYINSTALLER_VERSION-$TODAY &
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-win64-$PYTHON_VERSION-$PYINSTALLER_VERSION-$TODAY &
time wait
echo "Images pushed to private repo."

echo Done