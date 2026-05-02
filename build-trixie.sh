#!/bin/bash
# Build the goldenhelix trixie (Debian 13) core image.
#
# Tags BOTH:
#   ghdesktop-core-trixie:latest      ← variant-specific
#   ghdesktop-core:latest             ← unsuffixed default (what
#                                       Dockerfile.varseq and the rest
#                                       of varseq/server/build/build.mjs
#                                       expect for BASE_IMAGE).
#
# Trixie is the only variant we actively maintain — the unsuffixed tag
# IS the trixie build.

NAME1=debian
NAME2=trixie
BASE=debian:trixie-slim
DISTRO=debian
DOCKERFILE=dockerfile-gh-core
REGISTRY=registry.goldenhelix.com/public
DAY=$(date +'%y%m%d')

docker build \
  -t ${REGISTRY}/ghdesktop-core-trixie:$(arch)-${NAME1}-${NAME2}-${DAY} \
  -t ${REGISTRY}/ghdesktop-core-trixie:latest \
  -t ${REGISTRY}/ghdesktop-core:latest \
  --build-arg BASE_IMAGE="${BASE}" \
  --build-arg DISTRO="${DISTRO}" \
  --build-arg KASMVNC_DEB="src/trixie/kasmvncserver.deb" \
  -f ${DOCKERFILE} .
