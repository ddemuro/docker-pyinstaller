#!/bin/bash

# Docker flags
FLAGS_NOCACHE="--no-cache --progress=plain"
FLAGS="--progress=plain"

FLAGTOUSE=$FLAGS

function printSuccessOrFail {
    if [ $? -eq 0 ]; then
        echo "Success."
    else
        echo "Failed."
        exit 1
    fi
}

echo "Starting build process..."

docker build $FLAGTOUSE -f Dockerfile-py2-amd64 -t ddemuro/pyinstaller:py2-amd64 .
printSuccessOrFail

docker build $FLAGTOUSE -f Dockerfile-py2-win32 -t ddemuro/pyinstaller:py2-win32 .
printSuccessOrFail

docker build $FLAGTOUSE -f Dockerfile-py3-amd64 -t ddemuro/pyinstaller:py3-amd64 .
printSuccessOrFail

docker build $FLAGTOUSE -f Dockerfile-py3-i386 -t ddemuro/pyinstaller:py3-i386 .
printSuccessOrFail

docker build $FLAGTOUSE -f Dockerfile-py3-win32 -t ddemuro/pyinstaller:py3-win32 .
printSuccessOrFail

docker build $FLAGTOUSE -f Dockerfile-py3-win64 -t ddemuro/pyinstaller:py3-win64 .
printSuccessOrFail

echo "Build process completed."
 
# Push images to Docker Hub
# Grab today's date
TODAY=$(date +"%Y%m%d")

# Tag the images with the date
docker tag ddemuro/pyinstaller:py2-amd64 ddemuro/pyinstaller:py2-amd64-$TODAY
docker tag ddemuro/pyinstaller:py2-win32 ddemuro/pyinstaller:py2-win32-$TODAY
docker tag ddemuro/pyinstaller:py3-amd64 ddemuro/pyinstaller:py3-amd64-$TODAY
docker tag ddemuro/pyinstaller:py3-i386 ddemuro/pyinstaller:py3-i386-$TODAY
docker tag ddemuro/pyinstaller:py3-win32 ddemuro/pyinstaller:py3-win32-$TODAY
docker tag ddemuro/pyinstaller:py3-win64 ddemuro/pyinstaller:py3-win64-$TODAY

# Push the images to Docker Hub
# Push with the date
docker push ddemuro/pyinstaller:py2-amd64-$TODAY
docker push ddemuro/pyinstaller:py2-win32-$TODAY
docker push ddemuro/pyinstaller:py3-amd64-$TODAY
docker push ddemuro/pyinstaller:py3-i386-$TODAY
docker push ddemuro/pyinstaller:py3-win32-$TODAY
docker push ddemuro/pyinstaller:py3-win64-$TODAY

# Refresh latest tags
docker push ddemuro/pyinstaller:py2-amd64
docker push ddemuro/pyinstaller:py2-win32
docker push ddemuro/pyinstaller:py3-amd64
docker push ddemuro/pyinstaller:py3-i386
docker push ddemuro/pyinstaller:py3-win32
docker push ddemuro/pyinstaller:py3-win64

# Tag for private repo dkrhub.takelan.com/ddemuro
docker tag ddemuro/pyinstaller:py2-amd64 dkrhub.takelan.com/ddemuro/pyinstaller:py2-amd64
docker tag ddemuro/pyinstaller:py2-win32 dkrhub.takelan.com/ddemuro/pyinstaller:py2-win32
docker tag ddemuro/pyinstaller:py3-amd64 dkrhub.takelan.com/ddemuro/pyinstaller:py3-amd64
docker tag ddemuro/pyinstaller:py3-i386 dkrhub.takelan.com/ddemuro/pyinstaller:py3-i386
docker tag ddemuro/pyinstaller:py3-win32 dkrhub.takelan.com/ddemuro/pyinstaller:py3-win32
docker tag ddemuro/pyinstaller:py3-win64 dkrhub.takelan.com/ddemuro/pyinstaller:py3-win64

# Private repo today tag
docker tag ddemuro/pyinstaller:py2-amd64 dkrhub.takelan.com/ddemuro/pyinstaller:py2-amd64-$TODAY
docker tag ddemuro/pyinstaller:py2-win32 dkrhub.takelan.com/ddemuro/pyinstaller:py2-win32-$TODAY
docker tag ddemuro/pyinstaller:py3-amd64 dkrhub.takelan.com/ddemuro/pyinstaller:py3-amd64-$TODAY
docker tag ddemuro/pyinstaller:py3-i386 dkrhub.takelan.com/ddemuro/pyinstaller:py3-i386-$TODAY
docker tag ddemuro/pyinstaller:py3-win32 dkrhub.takelan.com/ddemuro/pyinstaller:py3-win32-$TODAY
docker tag ddemuro/pyinstaller:py3-win64 dkrhub.takelan.com/ddemuro/pyinstaller:py3-win64-$TODAY

# Push to private repo
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py2-amd64
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py2-win32
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-amd64
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-i386
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-win32
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-win64

# Push to private repo with today tag
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py2-amd64-$TODAY
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py2-win32-$TODAY
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-amd64-$TODAY
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-i386-$TODAY
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-win32-$TODAY
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-win64-$TODAY

echo "Images pushed to Docker Hub."