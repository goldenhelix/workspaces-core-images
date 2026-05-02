#!/bin/bash
set -e

# Download icons and add to cache
mkdir -p /usr/share/icons/hicolor/scalable/emblems
NAME=vs
# Directory from this script path
base_dir=$(dirname $0)
cp $base_dir/vs.svg /usr/share/icons/hicolor/scalable/emblems/${NAME}-emblem.svg
echo "[Icon Data]" >> /usr/share/icons/hicolor/scalable/emblems/${NAME}-emblem.icon
echo "DisplayName=${NAME}-emblem" >> /usr/share/icons/hicolor/scalable/emblems/${NAME}-emblem.icon
gtk-update-icon-cache -f /usr/share/icons/hicolor
