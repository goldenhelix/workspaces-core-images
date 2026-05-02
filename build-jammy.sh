#!/bin/bash
# Build the goldenhelix jammy (Ubuntu 22.04) core image. Distinct tag
# from ghdesktop-core-noble for side-by-side testing — 24.04's xfce
# has been showing input-event glitches that 22.04 / 20.04 don't have,
# so jammy is the fallback if we need to pin away from noble.

NAME1=ubuntu
NAME2=jammy
BASE=ubuntu:22.04
DISTRO=ubuntu
DOCKERFILE=dockerfile-gh-core
REGISTRY=registry.goldenhelix.com/public
DAY=$(date +'%y%m%d')

docker build \
  -t ${REGISTRY}/ghdesktop-core-jammy:$(arch)-${NAME1}-${NAME2}-${DAY} \
  -t ${REGISTRY}/ghdesktop-core-jammy:latest \
  --build-arg BASE_IMAGE="${BASE}" \
  --build-arg DISTRO="${DISTRO}" \
  --build-arg KASMVNC_DEB="src/jammy/kasmvncserver.deb" \
  -f ${DOCKERFILE} .
