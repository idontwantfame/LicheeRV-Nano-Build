# Issue #763 — `/data` partition MBR type 0x83 (Linux) instead of 0x07 (exFAT)

**Upstream issue:** sipeed/NanoKVM#763  
**Applied to:** `buildroot/board/cvitek/SG200X/overlay/etc/init.d/S01fs`

## Root cause

`S01fs` creates `/dev/mmcblk0p3` via:

```sh
parted -s /dev/mmcblk0 "mkpart primary $P2_END 100%"
```

`mkpart primary` with no filesystem-type hint on an MBR (msdos) disklabel defaults to
type `0x83` (Linux). The script immediately formats the partition as exFAT, but the MBR
type byte remains `0x83`.

The MBR partition type is advisory metadata used by the OS to decide how to interpret the
partition without reading the filesystem signature. With type `0x83`, macOS, Windows, and
some Linux tools will misidentify the partition as a Linux filesystem, refuse automatic
mounting, or present confusing error messages.

Observed fdisk output:
```
/dev/mmcblk0p3  ...  83 Linux     ← wrong; filesystem is exFAT
```

## Fix

After `parted mkpart`, pipe `t\n3\n7\nw\n` into `fdisk` to explicitly set the partition
type to `0x07` (exFAT). parted 3.6 has no `exfat` type name in `dos.c` — using `ntfs`
would also produce `0x07` but is semantically wrong. `mkfs.exfat` still runs immediately
after and produces a valid exFAT volume.
