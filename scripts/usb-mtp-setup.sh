#!/usr/bin/env bash
set -euo pipefail

G=/sys/kernel/config/usb_gadget/rg35xxh
FFS=/dev/ffs-mtp

fail() {
    echo "[mtp] $*" >&2
    exit 1
}

[ "$(id -u)" = 0 ] || fail "must run as root"
[ -x /usr/bin/umtprd ] || fail "umtp-responder is not installed"

mkdir -p /sys/kernel/config
if ! mountpoint -q /sys/kernel/config; then
    mount -t configfs configfs /sys/kernel/config
fi
grep -q ' /sys/kernel/config configfs ' /proc/mounts || fail "configfs is not mounted"

modprobe libcomposite
modprobe usb_f_fs

UDC=
for entry in /sys/class/udc/*; do
    if [ -e "$entry" ]; then
        UDC=${entry##*/}
        break
    fi
done
[ -n "$UDC" ] || fail "no USB device controller found; use the left USB-C OTG port"

if [ -d "$G" ] || mountpoint -q "$FFS"; then
    /usr/local/bin/usb-mtp-stop || fail "could not remove stale MTP gadget"
fi

cleanup_failed_setup() {
    status=$?
    if [ "$status" -ne 0 ]; then
        /usr/local/bin/usb-mtp-stop >/dev/null 2>&1 || true
    fi
}
trap cleanup_failed_setup EXIT

mkdir -p "$G"
echo 0x1d6b > "$G/idVendor"
echo 0x0100 > "$G/idProduct"
echo 0x0100 > "$G/bcdDevice"
echo 0x0200 > "$G/bcdUSB"

mkdir -p "$G/strings/0x409"
echo "rg35xxh-mtp" > "$G/strings/0x409/serialnumber"
echo "Anbernic" > "$G/strings/0x409/manufacturer"
echo "RG35XXH" > "$G/strings/0x409/product"

mkdir -p "$G/configs/c.1/strings/0x409"
echo "MTP" > "$G/configs/c.1/strings/0x409/configuration"
echo 250 > "$G/configs/c.1/MaxPower"
mkdir -p "$G/functions/ffs.mtp"

mkdir -p "$FFS"
mount -t functionfs mtp "$FFS"
/usr/bin/umtprd -conf /etc/umtprd/umtprd.conf > /var/log/umtprd.log 2>&1 &
echo $! > /run/umtprd.pid
for _ in {1..10}; do
    [ -e "$FFS/ep1" ] && break
    sleep 0.5
done
[ -e "$FFS/ep1" ] || fail "uMTP-Responder did not create FunctionFS endpoints"

ln -s "$G/functions/ffs.mtp" "$G/configs/c.1/ffs.mtp"
printf '%s\n' "$UDC" > "$G/UDC"
trap - EXIT
echo "[mtp] gadget bound to $UDC"
