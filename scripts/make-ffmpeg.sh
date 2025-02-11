#!/bin/bash
# TODO: build library more fit to what we really need.

./ffmpeg-android-maker/ffmpeg-android-maker.sh


mv ./ffmpeg-android-maker/build/ffmpeg ../src/dependecies/android

##DIR="$(pwd)/src/ffmpeg"
##cd "$DIR"

##./configure \
##	--prefix="${DIR}/build"
##	--disable-doc \
##	--disable-programs \
##	--disable-avdevice \
##	--disable-swresample \
##	--disable-postproc \
##	--disable-network \
##	--disable-debug \
##	--disable-static \
##	--enable-shared \
##	--enable-pic

##make -j$(nproc)
##make install

### Android
### ./configure \
###  --enable-cross-compile \
###  --target-os=android \
###  --arch=arm64 \
###  --enable-shared \
###  --disable-static \
###  --disable-programs
