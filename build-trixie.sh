#!/bin/bash
# Build the goldenhelix trixie (Debian 13) core image. Distinct tag
# from the bookworm-based ghdesktop-core for side-by-side testing —
# trixie ships XFCE 4.20 (vs bookworm's 4.18).

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
  --build-arg BASE_IMAGE="${BASE}" \
  --build-arg DISTRO="${DISTRO}" \
  --build-arg KASMVNC_DEB="src/trixie/kasmvncserver.deb" \
  -f ${DOCKERFILE} .
