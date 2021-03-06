---
title: A 2021 arch install that emphasises separate partitions and encryption
layout: page
permalink: /arch-install-2021/
---

## Partitions

The partition sizes in the table are for a 256.0G disk and 16.0G memory.
It closely matches the default disk partitioning sizes used by
openbsd70, except for no separate usr partitions. You can use the same
sizes even if you have a larger disk—the space for root, tmp, and var
for personal use akin to mine should be universally okay, and moreover
note that home gets all remaining space anyway. For suspension to
disk you want the swap partition size >= your hardware's memory.

Note the two non-traditional partitions: keys and suspendroot; there
are notes on them below.

<center>Table 1. Partitions</center>

```
# partition	encrypted	fstype	      size	mountpoint	type	guid
1 efi		       no	 fat12	      128M	/efi		ef00	C12A7328-F81F-11D2-BA4B-00A0C93EC93B
2 boot		    luks1	  ext4	      256M	/boot		8300	auto
3 root		    luks2	  ext4	    46080M	/		8300	auto
4 swap		    luks2	  swap	    16384M	[SWAP]		8200	auto
5 keys		    luks2	  ext4	        8M	/keys		8300	auto
6 suspendroot	       no	  ext4	       64M	/suspendroot	8300	auto
7 tmp		    luks2	  ext4	     4096M	/tmp		8300	auto
8 var		    luks2	  ext4	    30720M	/var		8300	auto
9 home		    luks2	  ext4	 remaining	/home		8300	auto
```

The partition scheme assumes you have a GPT/UEFI computer.

### Boot

Boot uses luks1, because core images created by `grub-install` in grub
2.06 can't unlock a luks2 encrypted device.[^1]

[^1]: https://wiki.archlinux.org/title/GRUB#LUKS2

### Keys

Keys is an encrypted partition that holds encryption keyfiles for root
and swap partitions. The encryption keyfile for the keys partition
itself is embedded in initramfs. From a cold boot or when resuming from
hibernate, to unlock the boot partition you need to enter the boot
partition's encryption password. After the boot partition is unlocked,
the keys partition is automatically unlocked using the embedded keyfile
in initramfs. A custom `keysencrypt` hook, a replacement intended to
address the shortcomings of the `encrypt` hook, then automatically
unlocks root and swap using the keyfiles in the keys partition (side
note: when resuming from hibernate, it should be sufficient to only
unlock swap, and it's also unclear to me right now whether `cryptsetup
luksOpen <root>` twice is safe).

The keys partition is closed and unmounted before entering the real
root and stays unmounted—this is vital so that it can be safely mounted
the next time if resuming from hibernate. _Technically_ it is
sufficient if the keys partition is not mounted when hibernation starts,
but it's hygienic for the keys partition to stay unmounted anyway.

### Suspendroot

Suspendroot is a unencrypted partition dedicated to securely suspend to
memory. Before suspending to memory, encrypted partitions must be locked
and encryption keys in memory must be wiped. The `cryptsetup
luksSuspend` command can handle this. But you shouldn't `cryptsetup
luksSuspend` the root partition which contains the `cryptsetup` binary;
if you do you can't call `cryptsetup luksResume` to unlock it when
waking up. So to suspend to memory we copy essential binaries (i.e.
`cryptsetup`) to the suspendroot parition, `chroot` to the partition,
and `luksSuspend` the root partition device from there.

### Create partitions

Use `gdisk` and verify with `lsblk`.

### Prepare partitions[^2]

Create the efi partition if it does not exist.

For boot, encrypt using luks1:

```
cryptsetup luksFormat --type luks1 /dev/nvme0n1p<N>
```

`luksFormat` by default uses luks2 and parameters that
security.stackexchange.com[^3] agrees with, so for root, swap, keys,
tmp, var, and home, for example:

```
cryptsetup luksFormat /dev/nvme0n1p<N>
```

For boot, root, swap, tmp, var, and home add a keyfile in addition to
the password. For example:

```
dd bs=512 count=4 iflag=fullblock if=/dev/random of=cryptroot.key
cryptsetup luksAddKey /dev/nvme0n1p<N> cryptroot.key
```

For the keys partition too:

```
dd bs=512 count=4 iflag=fullblock if=/dev/random of=cryptkeys.key
cryptsetup luksAddKey /dev/nvme0n1p<N> cryptkeys.key
```

Open the encrypted devices, make filesystems, and mount or swapon all
partitions 1–n. The options with which you open and mount right now
don't really matter, you can edit `/etc/{crypttab,fstab}` later.

[^2]: This uses [LUKS on a partition](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LUKS_on_a_partition)
[^3]: https://security.stackexchange.com/questions/40208

## Keyfiles

Make all encryption keyfiles accessible only to root (`chmod 000`).
Prefix the paths below with the mount root, e.g. `/mnt`.

For root and swap, save the keyfiles to the keys partition at:
```
/cryptroot.key
/cryptswap.key
```

For boot, tmp, var, and home, save the keyfiles to the
root partition at:
```
/etc/cryptsetup-keys.d/cryptboot.key
/etc/cryptsetup-keys.d/crypttmp.key
/etc/cryptsetup-keys.d/cryptvar.key
/etc/cryptsetup-keys.d/crypthome.key
```

For the keys partition, save the keyfile to the root partition
at:
```
/root/cryptkeys.key
```

## Install

### Install essential packages

Include a text editor (e.g. `vim`). `git` is used
to download the `keysencrypt` hook. Include `intel-ucode`, `amd-ucode`,
or nothing, depending on your processor for microcode updates.

```
# pacstrap /mnt base linux linux-firmware git grub efibootmgr \
	sof-firmware man-db man-pages
```

### Change to new system

```
# arch-chroot /mnt
```

### Name

Write the hostname to `/etc/hostname`.

### Configure

Set root password.

```
# passwd
```

Uncomment `en_US.UTF-8` and `UTF-8` in `/etc/locale.gen`. Then:

```
# locale-gen
# echo 'LANG=en_US.UTF-8' > /etc/locale.conf
```

## Edit /etc/crypttab

Use `lsblk -f` to find the UUIDs (these are the UUIDs of the encrypted
partitions, not the mapped ones). The options are:
`luks,no-read-workqueue,no-write-workqueue`.

Note there is no entry for swap as it is unlocked in initramfs. There is
no entry for `root`, it should already be unlocked by the point
`/etc/crypttab` is used. The keys partiton is not necessary in everyday
usage, so it is omitted. We want to unlock boot automatically to cater
to system updates that require the boot partition to be present.

```
cryptboot	UUID=<uuid>	/etc/cryptsetup-keys.d/cryptboot.key	<options>
crypttmp	UUID=<uuid>	/etc/cryptsetup-keys.d/crypttmp.key	<options>
cryptvar	UUID=<uuid>	/etc/cryptsetup-keys.d/cryptvar.key	<options>
crypthome	UUID=<uuid>	/etc/cryptsetup-keys.d/crypthome.key	<options>
```

## Edit /etc/fstab

With the mapped devices mounted and the mapped swap device swapped on,
print a workable fstab with `genfstab -U`. Write only the
entries for root, boot, swap, suspendroot, tmp, var, and home in this
order to `/etc/fstab`. For reference, the format is

```
device	dir	type	options		dump	fsck
```

## initramfs

The install uses a busybox-based initramfs. Configure the initramfs cpio
archive in `/etc/mkinitcpio.conf`: embed keys partition keyfile, and
update `HOOKS`.

```
FILES=(/root/cryptkeys.key)
HOOKS=(base udev autodetect keyboard keymap consolefont modconf block keysencrypt filesystems fsck)
```

`keysencrypt` is a custom hook; install and configure it.

```
# git clone --depth=1 https://github.com/littleroot/archutil
# cd archutil
... Follow README ...
```

Regenerate initramfs image:
```
mkinitcpio --allpresets
chmod 000 /boot/initramfs-linux*
```

## Bootloader

### Encrypted boot

Grub has to learn that the encrypted boot partition needs to be
unlocked. In `/etc/default/grub`:
```
GRUB_ENABLE_CRYPTODISK=y
```

### Install new grub bootloader

Install new grub `core.img` to the efi partition. Change `--target`
according to the processor.

```
# grub-install --target=x86_64-efi \
	--efi-directory=/efi \
	--boot-directory=/boot \
	--bootloader-id=GRUB
```

### Kernel parameters

In `/etc/default/grub`:

```
root=/dev/mapper/cryptroot
swap=/dev/mapper/cryptswap
```

### Generate grub config

Re-generate main grub config file. This re-generation accounts for
boot decryption, the kernel parameters, and to activate
microcode updates.
```
# grub-mkconfig -o /boot/grub/grub.cfg
```

## Safe suspend-to-memory

This can be done after a full install, after installing a desktop
environment and/or a window manager.

TODO(ns): suspendroot
