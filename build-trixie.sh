#!/bin/bash
# Build the goldenhelix trixie (Debian 13) core image.
#
# Tags:
#   ghdesktop-core-trixie:$(arch)-debian-trixie-$DAY  ← variant-specific, dated
#   ghdesktop-core-trixie:latest                       ← variant-specific, moving
#   ghdesktop-core:$DAY                                ← unsuffixed, dated (reproducible base)
#   ghdesktop-core:latest                              ← unsuffixed, moving
#
# Downstream builds (office-web, varseq) consume the dated unsuffixed
# tag for reproducibility — they read `LAST_BUILD.tag` (written below)
# to know which date to pin to. Override at the downstream call site
# with CORE_TAG=... if you want to pin to an older build.
#
# Trixie is the only variant we actively maintain — the unsuffixed tag
# IS the trixie build.

set -euo pipefail

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
  -t ${REGISTRY}/ghdesktop-core:${DAY} \
  -t ${REGISTRY}/ghdesktop-core:latest \
  --build-arg BASE_IMAGE="${BASE}" \
  --build-arg DISTRO="${DISTRO}" \
  --build-arg KASMVNC_DEB="src/trixie/kasmvncserver.deb" \
  -f ${DOCKERFILE} .

# Record the dated tag so downstream builds (office-web) can pin to it
# without referencing :latest. Override at the downstream call with
# CORE_TAG=... if you need to point at an older build.
echo "${DAY}" > LAST_BUILD.tag
echo "Wrote LAST_BUILD.tag: ${DAY}"
