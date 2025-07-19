#!/bin/sh

SAMPLE_RATE=48000
BUFFER_SIZE=1024
VDSP_DEV=/dev/vdsp
DEF_DEV=/dev/dsp
SKIP_OSS_SETUP=0

restore_virtual_oss() {
    echo "[*] Cleaning up old virtual_oss..."
    su -m root -c '
        pkill virtual_oss 2>/dev/null
        killall virtual_oss 2>/dev/null
        service virtual_oss restart '
}

set_default_key() {
    NEW_KEY="$1"
    if grep -q '^#DEFAULT_KEY=' "$SELF_PATH"; then
        echo "[*] Updating default key in script..."
        sed -i "" "s|^#DEFAULT_KEY=.*|DEFAULT_KEY=\"$NEW_KEY\"|" "$SELF_PATH"
    elif grep -q '^DEFAULT_KEY=' "$SELF_PATH"; then
        echo "[*] Updating existing DEFAULT_KEY..."
        sed -i "" "s|^DEFAULT_KEY=.*|DEFAULT_KEY=\"$NEW_KEY\"|" "$SELF_PATH"
    else
        echo "[*] Adding default key to script..."
        sed -i "" "1s|^|DEFAULT_KEY=\"$NEW_KEY\"\n|" "$SELF_PATH"
    fi
    echo "[+] Default key set!"
    exit 0
}

cleanup_virtual_oss() {
    echo "[*] Cleaning up old virtual_oss..."
    su -m root -c '
        pkill virtual_oss 2>/dev/null
        killall virtual_oss 2>/dev/null
        service virtual_oss onestatus >/dev/null 2>&1 && service virtual_oss stop
        lsof /dev/dsp0.0 2>/dev/null | awk "/dsp0.0/ {print \$2}" | sort -u | while read pid; do
            echo "[*] Killing PID $pid using /dev/dsp0.0"
            kill "$pid" 2>/dev/null
        done
    '
    if [ $? -ne 0 ]; then
        echo "[-] Failed to clean up virtual_oss. Trying to restore..."
        restore_virtual_oss
        exit 1
    fi
}

detect_devices() {
    echo "[*] Detecting audio devices..."
    MIC_DEV=$(cat /dev/sndstat | awk '/^pcm.*rec/ {print $1}' | grep -v Virtual | head -n 1)
    SYS_DEV=$(cat /dev/sndstat | awk '/^pcm.*play/ {print $1}' | grep -v Virtual | head -n 1)

    if [ -z "$MIC_DEV" ] || [ -z "$SYS_DEV" ]; then
        echo "[-] Could not detect audio devices"
        exit 1
    fi

    MIC_UNIT=$(echo "$MIC_DEV" | sed 's/pcm\([0-9]*\).*/\1/')
    SYS_UNIT=$(echo "$SYS_DEV" | sed 's/pcm\([0-9]*\).*/\1/')

    MIC_DSP="/dev/dsp${MIC_UNIT}.2"
    SYS_DSP="/dev/dsp${SYS_UNIT}.0"

    echo "[+] MIC: $MIC_DSP"
    echo "[+] SYS: $SYS_DSP"
}

start_virtual_oss() {
    echo "[*] Starting virtual_oss..."
    su -m root -c "
        virtual_oss -Q 0 \
        -C 2 -c 2 -r $SAMPLE_RATE -b 16 -s $BUFFER_SIZE \
        -P '$SYS_DSP' -R '$MIC_DSP' \
        -d vdsp -l dsp &
        sleep 2
    "
    if [ $? -ne 0 ]; then
        echo "[-] Failed to start virtual_oss. Trying to restore..."
        restore_virtual_oss
        exit 1
    fi
}

start_stream() {
    KEY="$1"
    [ -z "$KEY" ] && [ -n "$DEFAULT_KEY" ] && KEY="$DEFAULT_KEY"

    if [ -z "$KEY" ]; then
        echo "Usage: $0 <twitch_stream_key>"
        echo "       $0 --set-default-key <twitch_stream_key>"
        exit 1
    fi
    echo "[*] Starting ffmpeg stream..."
    ffmpeg \
    -f x11grab -framerate 25 -video_size 1920x1080 -i :0.0 \
    -f oss -i "$DEF_DEV" \
    -f oss -i "$VDSP_DEV" \
    -filter_complex "[1:a]aresample=async=1:first_pts=0[a1]; \
                   [2:a]aresample=async=1:first_pts=0,highpass=f=450,lowpass=f=4000,afftdn=nr=64[a2] \
                   [a1][a2]amix=inputs=2:duration=longest[aout]" \
    -map 0:v -map "[aout]" \
    -vcodec libx264 -pix_fmt yuv420p -preset ultrafast -b:v 2500k \
    -vf scale=1280:720 \
    -acodec aac -b:a 128k -ar 44100 \
    -f tee "[f=flv]backup.flv|[f=flv]rtmp://live.twitch.tv/app/$KEY"
}

main() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "Usage:"
        echo "  $0 [OPTIONS] [TWITCH_STREAM_KEY]"
        echo
        echo "Options:"
        echo "  --set-default-key <key>    Embed the given Twitch stream key into the script itself."
        echo "  --skip-oss-setup           Skip cleanup and reinitialization of virtual_oss."
        echo "  --help, -h                 Show this help message."
        echo
        echo "Examples:"
        echo "  $0 --set-default-key abc123def456"
        echo "      Store the stream key into the script for future use."
        echo
        echo "  $0"
        echo "      Start stream using stored key and perform OSS setup."
        echo
        echo "  $0 --skip-oss-setup"
        echo "      Start stream using stored key, skip OSS setup (e.g. already running)."
        echo
        echo "  $0 --skip-oss-setup xyz789zzz000"
        echo "      Start stream using provided key, skip OSS setup."
        echo
        exit 0
    fi
    
    if [ "$1" = "--set-default-key" ]; then
        shift
        set_default_key "$1"
    fi

    for arg in "$@"; do
        if [ "$arg" = "--skip-oss-setup" ]; then
            SKIP_OSS_SETUP=1
        fi
    done

    if [ "$SKIP_OSS_SETUP" -eq 0 ]; then
        cleanup_virtual_oss
        detect_devices
        start_virtual_oss
    fi

    for arg in "$@"; do
        case "$arg" in
            --*) ;;
            *) KEY="$arg" ;;
        esac
    done

    start_stream "$KEY"
}

main "$@"
