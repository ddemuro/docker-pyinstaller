#!/bin/bash

echo "Starting build process..."
docker build -f Dockerfile-py2-amd64 -t ddemuro/pyinstaller:py2-amd64 .
docker build -f Dockerfile-py2-win32 -t ddemuro/pyinstaller:py2-win32 .

docker build -f Dockerfile-py3-amd64 -t ddemuro/pyinstaller:py3-amd64 .
docker build -f Dockerfile-py3-i386 -t ddemuro/pyinstaller:py3-i386 .

docker build -f Dockerfile-py3-win32 -t ddemuro/pyinstaller:py3-win32 .
docker build -f Dockerfile-py3-win64 -t ddemuro/pyinstaller:py3-win64 .

echo "Build process completed."
 
# Push images to Docker Hub
docker push ddemuro/pyinstaller:py2-amd64
docker push ddemuro/pyinstaller:py2-win32
docker push ddemuro/pyinstaller:py3-amd64
docker push ddemuro/pyinstaller:py3-i386
docker push ddemuro/pyinstaller:py3-win32
docker push ddemuro/pyinstaller:py3-win64

echo "Images pushed to Docker Hub."