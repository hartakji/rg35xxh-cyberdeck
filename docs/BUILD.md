# Build internals

## Pipeline

```
build.sh all
├── fetch    git clone ROCKNIX @VERSIONS.ROCKNIX_COMMIT
├── docker   build rocknix-builder image (Ubuntu jammy + gcc 15.2 cross toolchain)
├── kernel   ROCKNIX scripts/build linux + u-boot
│             then re-runs make with INITRAMFS_SOURCE="" + MMC builtin + HIDRAW/UHID
├── dtb_patch  python scripts/patch-h700-dtb-regulators.py → AXP717 regulator-always-on
├── rootfs   debootstrap minbase → install XFCE/handheld/network stages → overlay
└── image    pack GPT + u-boot SPL @ 8KB + FAT boot + ext4 rootfs → .img + .bmap + .img.xz
```

## Iterating fast

| Change | Re-run |
|---|---|
| Tweak overlay file (script, systemd unit) | `RG_FORCE_ROOTFS=1 ./build.sh rootfs && sudo ./build.sh image` |
| Change a rootfs stage | same as above |
| Bump a kernel patch | `RG_FORCE_KERNEL=1 ./build.sh kernel`, then `sudo ./build.sh image` |
| Enable USB mass-storage gadget kernel support | `RG_FORCE_KERNEL=1 ./build.sh kernel`, then rebuild rootfs and image |
| Just repack image | `sudo ./build.sh image` |

For the USB gadget kernel change, run the rootfs and image stages separately after `kernel`:
```bash
RG_FORCE_ROOTFS=1 ./build.sh rootfs
sudo ./build.sh image
```

Mount the resulting `.img` on a loop device to inspect without flashing:
```bash
LOOP=$(sudo losetup -fP --show dist/rg35xxh-cyberdeck-*.img)
sudo mount ${LOOP}p2 /mnt
# poke around
sudo umount /mnt && sudo losetup -d $LOOP
```

## Why a custom kernel rebuild?

ROCKNIX ships `linux-7.0.2` with `CONFIG_INITRAMFS_SOURCE` pointing at its recovery initramfs. That cpio gets **embedded into the `Image` binary**, so any "use ROCKNIX kernel + my own rootfs" hybrid drops you into a busybox `/ #` shell instead of running Debian's `/sbin/init`. We re-run `make Image` with the source emptied. The same kernel configuration enables built-in MMC support, HIDRAW/UHID for BLE keyboards, configfs mass-storage support, and FunctionFS for MTP.

See `docs/PITFALLS.md` for the full backstory.

## CI

`.github/workflows/build.yml` runs the whole thing on `ubuntu-24.04`. Kernel build cache is keyed on `VERSIONS` so incremental runs are fast. Tagged pushes (`v*`) upload to a GitHub release.
