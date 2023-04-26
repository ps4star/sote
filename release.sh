#!/bin/sh

odin build src/ -out:out/sote -define:DEBUG=true -o:speed && patchelf --set-rpath '$ORIGIN/.' out/sote