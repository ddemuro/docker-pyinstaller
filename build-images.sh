#!/bin/bash

# Docker flags
#FLAGS_NOCACHE="--no-cache --progress=plain"
#FLAGS="--progress=plain"
FLAGS="--quiet"
TODAY=$(date +"%Y%m%d")
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

docker build $FLAGTOUSE -f Dockerfile-py2-amd64 -t ddemuro/pyinstaller:py2-amd64-$TODAY -t ddemuro/pyinstaller:py2-amd64 . &
docker build $FLAGTOUSE -f Dockerfile-py2-win32 -t ddemuro/pyinstaller:py2-win32-$TODAY -t ddemuro/pyinstaller:py2-win32 . &
time wait

VERSIONS="3.9.9 3.12.3"

for VERSION in $VERSIONS; do
    echo "Building py3-$VERSION..."
    docker build $FLAGTOUSE -f Dockerfile-py3-amd64-$VERSION -t ddemuro/pyinstaller:py3-amd64-$VERSION -t ddemuro/pyinstaller:py3-amd64-$VERSION-$TODAY . &

    docker build $FLAGTOUSE -f Dockerfile-py3-i386-$VERSION -t ddemuro/pyinstaller:py3-i386-$VERSION -t ddemuro/pyinstaller:py3-i386-$VERSION-$TODAY . &

    docker build $FLAGTOUSE -f Dockerfile-py3-win32-$VERSION -t ddemuro/pyinstaller:py3-win32-$VERSION -t ddemuro/pyinstaller:py3-win32-$VERSION-$TODAY . &

    docker build $FLAGTOUSE -f Dockerfile-py3-win64-$VERSION -t ddemuro/pyinstaller:py3-win64-$VERSION -t ddemuro/pyinstaller:py3-win64-$VERSION-$TODAY . &
done

time wait

# echo "Build process completed."
 
# # Push images to Docker Hub
# # Grab today's date
# 

# # Push the images to Docker Hub
# # Push with the date
docker push ddemuro/pyinstaller:py2-amd64 &
docker push ddemuro/pyinstaller:py2-win32 &
docker push ddemuro/pyinstaller:py2-amd64-$TODAY &
docker push ddemuro/pyinstaller:py2-win32-$TODAY &
time wait
echo "Images pushed to Docker Hub."

for VERSION in $VERSIONS; do
    docker push ddemuro/pyinstaller:py3-amd64-$VERSION &
    docker push ddemuro/pyinstaller:py3-i386-$VERSION &
    docker push ddemuro/pyinstaller:py3-win32-$VERSION &
    docker push ddemuro/pyinstaller:py3-win64-$VERSION &

    docker push ddemuro/pyinstaller:py3-amd64-$VERSION-$TODAY &
    docker push ddemuro/pyinstaller:py3-i386-$VERSION-$TODAY &
    docker push ddemuro/pyinstaller:py3-win32-$VERSION-$TODAY &
    docker push ddemuro/pyinstaller:py3-win64-$VERSION-$TODAY &
done
time wait
echo "Images pushed to Docker Hub."


docker push dkrhub.takelan.com/ddemuro/pyinstaller:py2-amd64 &
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py2-win32 &
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py2-amd64-$TODAY &
docker push dkrhub.takelan.com/ddemuro/pyinstaller:py2-win32-$TODAY &
time wait
echo "Images pushed to private repo."

for VERSION in $VERSIONS; do
    docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-amd64-$VERSION &
    docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-i386-$VERSION &
    docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-win32-$VERSION &
    docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-win64-$VERSION &

    docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-amd64-$VERSION-$TODAY &
    docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-i386-$VERSION-$TODAY &
    docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-win32-$VERSION-$TODAY &
    docker push dkrhub.takelan.com/ddemuro/pyinstaller:py3-win64-$VERSION-$TODAY &
done
time wait
echo "Images pushed to private repo."

echo Done