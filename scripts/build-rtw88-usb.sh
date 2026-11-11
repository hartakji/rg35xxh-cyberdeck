#!/usr/bin/env bash
# Build rtw88_8822bu (RTL8812BU/8822BU USB) into the kernel Image.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/VERSIONS"
WORK="${RG_WORK:-$ROOT/work}"
B="/work/build.ROCKNIX-${DEVICE}.${ARCH}"

docker run --rm \
  -v "$WORK/rocknix:/work" \
  --user root -w /work rocknix-builder bash -c "
    chown -R docker:docker /work
    su docker -c '
      export PATH=$B/toolchain/bin:\$PATH
      export ARCH=arm64 CROSS_COMPILE=aarch64-rocknix-linux-gnu-
      cd $B/build/${KERNEL_NAME}
      scripts/config --file .config -e RTW88_8822BU
      make olddefconfig
      grep -E \"CONFIG_RTW88_(USB|8822B|8822BU)=\" .config
      make -j\$(nproc) Image
    '
  "
