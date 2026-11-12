#!/usr/bin/env bash
# Stage 20: XFCE desktop + LightDM autologin.
set -euo pipefail
ROOTFS="$1"
. "$(dirname "$0")/../../VERSIONS"

run() {
  for m in proc sys dev dev/pts; do mount --bind /$m "$ROOTFS/$m"; done
  trap 'for m in dev/pts dev sys proc; do umount -l "$ROOTFS/$m" 2>/dev/null || true; done' EXIT
  TARGET_USER="$TARGET_USER" TARGET_PASSWORD="$TARGET_PASSWORD" \
    DEBIAN_FRONTEND=noninteractive chroot "$ROOTFS" /bin/bash -e -c "$1"
}

run "
  apt-get install -y --no-install-recommends \
    xfce4 xfce4-goodies xfce4-battery-plugin xfce4-power-manager xfce4-power-manager-plugins \
    lightdm lightdm-gtk-greeter \
    xserver-xorg-video-fbdev xserver-xorg-input-evdev xserver-xorg-input-libinput \
    mpv pavucontrol thunar-volman gvfs-backends mtp-tools umtp-responder procps

  # Create user
  useradd -m -s /bin/bash -G sudo,video,audio,plugdev,dialout,input,netdev,bluetooth \"\$TARGET_USER\"
  printf '%s:%s\n' \"\$TARGET_USER\" \"\$TARGET_PASSWORD\" | chpasswd
  printf '%s\n' \"\$TARGET_USER ALL=(ALL) NOPASSWD: ALL\" > \"/etc/sudoers.d/90-\$TARGET_USER\"

  # Autologin
  mkdir -p /etc/lightdm/lightdm.conf.d
  cat > /etc/lightdm/lightdm.conf.d/50-autologin.conf <<EOF
[Seat:*]
autologin-user=\$TARGET_USER
autologin-user-timeout=0
user-session=xfce
EOF
"
