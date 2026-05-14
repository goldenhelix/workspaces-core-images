#!/bin/bash
### every exit != 0 fails the script
set -e

# should also source $STARTUPDIR/generate_container_user
source $HOME/.bashrc

# Set lang values
if [ "${LC_ALL}" != "en_US.UTF-8" ]; then
  export LANG=${LC_ALL}
  export LANGUAGE=${LC_ALL}
fi

# Dbus
export $(dbus-launch)

## correct forwarding of shutdown signal
cleanup () {
    kill -s SIGTERM $!
    exit 0
}
trap cleanup SIGINT SIGTERM

add_vnc_user() {
  local username="$1"
  local password="$2"
  local permission_option="$3"

  echo "Adding user $username"
  echo -e "$password\n$password" | kasmvncpasswd $permission_option \
    -u "$username" $HOME/.kasmpasswd
}

## resolve_vnc_connection
VNC_IP=$(hostname -i)

# first entry is control, second is view (if only one is valid for both)
mkdir -p "$HOME/.vnc"
add_vnc_user "$VNC_USER" "$VNC_PW" "-wo"
#add_vnc_user "$VNC_USER-ro" "$VNC_PW"
unset VNC_PW # don't need it anymore
chmod 0600 $HOME/.kasmpasswd

# Pre-write ~/.vnc/kasmvnc.yaml with sane defaults BEFORE kasmvncserver
# runs. The perl wrapper otherwise drops in its hard-coded default (see
# unix/vncserver:1216) which sets logging.level=100 — that emits per-
# frame [DEBUG] SoftwareEncoder spam in the container log.
#
# level=10 here keeps connect/disconnect events + warnings + errors but
# drops the per-frame trace lines. Bump KASMVNC_VERBOSE_LOGGING in the
# environment for the chatty version.
LOG_LEVEL=10
[ -n "$KASMVNC_VERBOSE_LOGGING" ] && LOG_LEVEL=100

cat <<EOF > $HOME/.vnc/kasmvnc.yaml
logging:
  log_writer_name: all
  log_dest: logfile
  level: $LOG_LEVEL
EOF

if [ -n "$IDLE_TIMEOUT" ]; then
  cat <<EOF >> $HOME/.vnc/kasmvnc.yaml
server:
  auto_shutdown:
    no_user_session_timeout: $IDLE_TIMEOUT
    inactive_user_session_timeout: $IDLE_TIMEOUT
EOF
fi

# Try to create a username based directory, only update .config/user-dirs.dirs if it succeeds
set +e
mkdir -p $HOME/Workspace/Documents/$USERNAME
if [ -d $HOME/Workspace/Documents/$USERNAME ]; then
  cat <<EOF > $HOME/.config/user-dirs.dirs
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_DOCUMENTS_DIR="$HOME/Workspace/Documents/$USERNAME"
EOF
  BOOKMARKS_FILE="$HOME/.config/gtk-3.0/bookmarks"
  mkdir -p "$(dirname "$BOOKMARKS_FILE")"
  : > "$BOOKMARKS_FILE"
  for folder in "$HOME/Workspace"/*/; do
    [ -d "$folder" ] || continue
    # Add the directory to the bookmarks file in the required format
    escaped_folder=$(echo "$folder" | sed 's/ /%20/g')
    echo "file://$escaped_folder" >> "$BOOKMARKS_FILE"
  done
fi
set -e

# Generate SSL certificate
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout $HOME/.vnc/self.pem -out $HOME/.vnc/self.pem -subj "/C=US/ST=VA/L=None/O=None/OU=DoFu/CN=kasm/emailAddress=none@none.none" &> $HOME/.vnc/vnc_startup.log

if [[ $DEBUG == true ]]; then
  echo "remove old vnc locks to be a reattachable container"
fi
vncserver -kill $DISPLAY &> $HOME/.vnc/vnc_startup.log \
    || rm -rfv /tmp/.X*-lock /tmp/.X11-unix &> $HOME/.vnc/vnc_startup.log \
    || echo "no locks present"


[ -n "$KASMVNC_VERBOSE_LOGGING" ] && verbose_logging_option="-debug"

# UnixRelay sockets — see KasmVNC repo unix/{openurl,download,upload,host}/README.md.
#   openurl  : kasmvnc-open-url    → kasmweb opens link in user's browser
#   download : kasmvnc-file-download → kasmweb triggers <a download> click
#   upload   : kasmvnc-upload-daemon ← kasmweb sends bytes after drag-drop
#   host     : kasmvnc-host          → kasmweb forwards JSON to parent iframe
DISPLAY_NUM="${DISPLAY#:}"
OPENURL_SOCK="/tmp/kasmvnc-openurl-${DISPLAY_NUM}.sock"
DOWNLOAD_SOCK="/tmp/kasmvnc-download-${DISPLAY_NUM}.sock"
UPLOAD_SOCK="/tmp/kasmvnc-upload-${DISPLAY_NUM}.sock"
HOST_SOCK="/tmp/kasmvnc-host-${DISPLAY_NUM}.sock"
rm -f "$OPENURL_SOCK" "$DOWNLOAD_SOCK" "$UPLOAD_SOCK" "$HOST_SOCK"

vncserver $DISPLAY -select-de manual -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION -FrameRate=$MAX_FRAME_RATE -websocketPort $NO_VNC_PORT -sslOnly -interface 0.0.0.0 -BlacklistThreshold=0 -FreeKeyMappings -UnixRelay openurl:"$OPENURL_SOCK" -UnixRelay download:"$DOWNLOAD_SOCK" -UnixRelay upload:"$UPLOAD_SOCK" -UnixRelay host:"$HOST_SOCK" $VNCOPTIONS $verbose_logging_option &> $STARTUPDIR/no_vnc_startup.log

# Seed the user's Thunar custom-actions file with our "Download" entry
# (right-click on a file/folder → Download → triggers kasmvnc-file-download).
# Only seed if the user has no uca.xml yet — never clobber existing.
if [ -f /usr/share/kasmvnc/thunar-uca.xml ] && [ ! -e "$HOME/.config/Thunar/uca.xml" ]; then
    mkdir -p "$HOME/.config/Thunar"
    cp /usr/share/kasmvnc/thunar-uca.xml "$HOME/.config/Thunar/uca.xml"
fi

# Background upload daemon. Has to run as the desktop user with the same
# DISPLAY env so it finds the right socket name; runs after vncserver
# created the relay socket. Daemon survives session lifetime; tee its
# log so we can debug.
(
    for _ in $(seq 1 30); do
        [ -S "$UPLOAD_SOCK" ] && break
        sleep 0.5
    done
    if [ -S "$UPLOAD_SOCK" ]; then
        DISPLAY="$DISPLAY" KASMVNC_UPLOAD_LOG_LEVEL=DEBUG \
            /usr/bin/kasmvnc-upload-daemon \
            > "$HOME/.vnc/upload-daemon.log" 2>&1 &
    fi
) &

echo "Starting window manager XFCE..."
# Filter known harmless XFCE noise from stderr:
#  - xfdesktop "Failed to get system bus": xfdesktop probes the system
#    DBus on every screen-size change. We only run a session bus inside
#    the container; no system bus is needed for any feature we use.
#  - "Xlib: extension DPMS missing": Xvnc doesn't load the DPMS extension,
#    so xset -dpms (and the resize-triggered DPMS probes) emit this. The
#    underlying screensaver/blank disables (xset s noblank/off) still work.
DISPLAY=:1 /usr/bin/startxfce4 --replace 2> >(grep --line-buffered -vE 'Failed to get system bus|extension "DPMS" missing|^[[:space:]]*$' >&2) &
PID_SUB=$!

# Mark all .desktop launchers as trusted so XFCE 4.18+ doesn't pop the
# "Untrusted application launcher" dialog. Has to run *after*
# startxfce4 — gvfsd-metadata is started by the xfce session bus.
(
    for _ in $(seq 1 30); do
        XFCE_PID=$(pgrep -u "$(id -u)" -f xfce4-session | head -1)
        [ -n "$XFCE_PID" ] && break
        sleep 1
    done
    if [ -n "$XFCE_PID" ]; then
        DBUS_LINE=$(tr '\0' '\n' < "/proc/$XFCE_PID/environ" 2>/dev/null | grep ^DBUS_SESSION_BUS_ADDRESS=)
        [ -n "$DBUS_LINE" ] && export "$DBUS_LINE"
    fi
    for f in "$HOME/Desktop"/*.desktop "$HOME/.config/xfce4/panel/launcher-"*/*.desktop; do
        [ -f "$f" ] || continue
        chmod +x "$f" 2>/dev/null || true
        gio set -t string "$f" metadata::xfce-exe-checksum \
            "$(sha256sum "$f" | awk '{print $1}')" 2>/dev/null || true
        gio set -t string "$f" metadata::trusted true 2>/dev/null || true
    done
) &

### disable screen saver and power management
# Xvnc doesn't load the DPMS extension; suppress the Xlib warning.
# xset s noblank/off still work and disable the actual screen blanker.
xset -dpms 2>/dev/null &
xset s noblank &
xset s off &
# xset q # debug xset settings

## log connect options
echo -e "\n\n------------------ VNC environment started ------------------"
echo -e "\nConnect via https://$VNC_IP:$NO_VNC_PORT/\n"
echo "WEB PID: $PID_SUB"

# tail vncserver logs
tail -f $HOME/.vnc/*$DISPLAY.log &

# Specialized containers that use this as a base image can add a custom startup script
custom_startup_script=/dockerstartup/custom_startup.sh
if [ -f "$custom_startup_script" ]; then
  if [ ! -x "$custom_startup_script" ]; then
    echo "${custom_startup_script}: not executable, exiting"
    exit 1
  fi

  "$custom_startup_script" &
  echo "Executed custom startup script."
fi

# We shut down the container when the XFCE4 window manager exits
wait $PID_SUB

echo "Exiting VNC container"
