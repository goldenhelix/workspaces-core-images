#!/bin/bash
# Build the goldenhelix noble (Ubuntu 24.04) core image. Distinct tag
# from the bookworm-based ghdesktop-core in appstream-core-images so
# the two can sit side-by-side for testing.

NAME1=ubuntu
NAME2=noble
BASE=ubuntu:24.04
DISTRO=ubuntu
DOCKERFILE=dockerfile-gh-core
REGISTRY=registry.goldenhelix.com/public
DAY=$(date +'%y%m%d')

XFCE_420="${XFCE_420:-false}"

docker build \
  -t ${REGISTRY}/ghdesktop-core-noble:$(arch)-${NAME1}-${NAME2}-${DAY} \
  -t ${REGISTRY}/ghdesktop-core-noble:latest \
  --build-arg BASE_IMAGE="${BASE}" \
  --build-arg DISTRO="${DISTRO}" \
  --build-arg XFCE_420="${XFCE_420}" \
  -f ${DOCKERFILE} .
