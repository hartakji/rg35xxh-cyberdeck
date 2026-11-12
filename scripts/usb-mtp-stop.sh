#!/usr/bin/env bash
set -euo pipefail

G=/sys/kernel/config/usb_gadget/rg35xxh
FFS=/dev/ffs-mtp
PID_FILE=/run/umtprd.pid

if [ -r "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE")
    if [[ "$pid" =~ ^[0-9]+$ ]] && [ -e "/proc/$pid/exe" ]; then
        exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)
        if [ "$exe" = /usr/bin/umtprd ]; then
            kill -TERM "$pid" 2>/dev/null || true
            for _ in {1..20}; do
                [ -e "/proc/$pid/exe" ] || break
                sleep 0.1
            done
            if [ -e "/proc/$pid/exe" ]; then
                exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)
                if [ "$exe" = /usr/bin/umtprd ]; then
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            fi
        fi
    fi
    rm -f "$PID_FILE"
fi

if mountpoint -q "$FFS"; then
    umount "$FFS"
fi

if [ -d "$G" ]; then
    bound_udc=$(cat "$G/UDC")
    if [ -n "$bound_udc" ]; then
        printf '\n' > "$G/UDC" 2>/dev/null ||
            echo "[mtp] UDC unbind unavailable; continuing stale-gadget cleanup" >&2
    fi
    rm -f "$G/configs/c.1/ffs.mtp"
    for dir in \
        "$G/functions/ffs.mtp" \
        "$G/configs/c.1/strings/0x409" \
        "$G/configs/c.1" \
        "$G/strings/0x409" \
        "$G"; do
        if [ -d "$dir" ]; then
            rmdir "$dir" || {
                echo "[mtp] could not remove configfs directory: $dir" >&2
                exit 1
            }
        fi
    done
fi

echo "[mtp] stopped"
