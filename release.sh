#!/bin/sh

# stbtt dep
cd src/extlib/stb_truetype && \
curl "https://raw.githubusercontent.com/nothings/stb/master/stb_truetype.h" > stb_truetype.h && \
cc -I. -c -o stb_truetype.o stb_truetype.c && \
ar rcs stb_truetype.a stb_truetype.o && \
rm stb_truetype.o && \
cd ../../..

# opengl dep
# cd src/extlib/opengl
# rm -rf ./*
# rm -rf ./.git
# git clone "https://github.com/ps4star/OdinGL" ./
# cd ../../..

# NOTE: for the sdl2 dep, we just require it to be on the system for Linux (stock vendor:sdl2 setup)

# Build
odin build src/ -collection:sote=./ -out:out/sote -define:DEBUG=true -o:speed && \
patchelf --set-rpath '$ORIGIN/.' out/sote