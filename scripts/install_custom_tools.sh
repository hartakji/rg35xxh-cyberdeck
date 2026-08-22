#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== 1. Installing Prerequisites ==="
apt-get update
apt-get install -y --no-install-recommends wget gnupg ca-certificates

echo "=== 2. Configuring Kali Linux Repository ==="
wget -q -O - https://archive.kali.org/archive-key.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/kali-archive-keyring.gpg
echo "deb http://http.kali.org/kali kali-rolling main non-free contrib" > /etc/apt/sources.list.d/kali.list

cat << 'EOF' > /etc/apt/preferences.d/kali.pref
Package: *
Pin: release o=Kali
Pin-Priority: 50
EOF

apt-get update

echo "=== 3. Installing Kali Security Tools ==="
apt-get install -y -t kali-rolling --no-install-recommends \
    nmap \
    aircrack-ng \
    wireshark \
    tshark \
    hydra \
    john \
    hashcat \
    recon-ng \
    metasploit-framework

echo "=== 4. Installing DragonOS / SDR Tools ==="
apt-get install -y --no-install-recommends \
    rtl-sdr \
    hackrf \
    gqrx-sdr \
    gnuradio \
    soapysdr-tools \
    inspectrum \
    multimon-ng \
    kalibrate-rtl \
    chirp

echo "=== 5. Cleanup ==="
apt-get clean
rm -rf /var/lib/apt/lists/*
