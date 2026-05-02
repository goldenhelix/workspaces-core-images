# FULLSCREEN and FULLSCREEN_NAME are exported by the calling script
# This script will check against the container OS to do the right thing.
enable_x=0

fullscreen_window(){
    set +e
    if [[ ${FULLSCREEN} == 'true' ]] ; then
        if [[ $- =~ x ]] ;
        then
            set +x
            enable_x=1
        fi
        while true; do
            end=$((SECONDS+60))
            while [ $SECONDS -lt $end ]; do
                windows=$(wmctrl -l)
                if [[ "$windows" =~ "${FULLSCREEN_NAME}" ]];
                then
                    wmctrl -r "${FULLSCREEN_NAME}" -b add,fullscreen
                    break;
                fi
                sleep 1
            done
            sleep 10
        done
        if [[ ${enable_x} -eq 1 ]];
        then
            set -x
        fi
    fi
    set -e
}

fullscreen_window