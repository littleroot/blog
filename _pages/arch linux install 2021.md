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
# partition	encrypted	fstype	      size	mountpoint	type
1 efi		       no	  vfat	      512M	/efi		ef00
2 boot		    luks1	  vfat	      512M	/boot		8300
3 root		    luks2	  ext4	    46080M	/		8300
4 swap		    luks2	  swap	    16384M	[SWAP]		8200
5 keys		    luks2	  ext4	        8M	/keys		8300
6 suspendroot	       no	  ext4	       64M	/suspendroot	8300
7 tmp		    luks2	  ext4	     4096M	/tmp		8300
8 var		    luks2	  ext4	    30720M	/var		8300
9 home		    luks2	  ext4	 remaining	/home		8300
```

### Boot

Boot uses luks1, because core images created by `grub-install` in grub
2.06 can't unlock a luks2 encrypted device.[^1]

[^1]: https://wiki.archlinux.org/title/GRUB#LUKS2

### Keys

Keys is an encrypted partition that holds encryption
keyfiles for root and swap partitions. The encryption keyfile for the
keys partition itself is embedded in initramfs. From a cold boot or when
resuming from hibernate, to unlock the boot partition you need to enter
the boot partition's encryption password. After the boot partition is
unlocked, the keys partition is automatically unlocked using the
embedded keyfile in initramfs. A custom `keysencrypt` hook, a
replacement intended to address the shortcomings of the `encrypt` hook,
then automatically unlocks root and swap using the keyfiles in the keys
partition (side note: when resuming from hibernate, it should be
sufficient to only unlock swap).

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

Open the encrypted devices, make filesystems on the mapped devices, and
mount or swapon. The options with which you open and mount right now
don't matter (so supply none).

[^2]: This uses [LUKS on a partition](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LUKS_on_a_partition).
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
# pacstrap /mnt base linux linux-firmware git grub efibootmgr
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
`luks,no-read-workqueue,no-write-workqueue,discard`.

Note there is no entry for swap; it is unlocked in initramfs. The keys
partiton is not necessary in everyday usage, so it is omitted. We want
to unlock boot automatically to cater to system updates that require the
boot partition to be present.

```
cryptboot	UUID=<uuid>	/etc/cryptsetup-keys.d/cryptboot.key	<options>
crypttmp	UUID=<uuid>	/etc/cryptsetup-keys.d/crypttmp.key	<options>
cryptvar	UUID=<uuid>	/etc/cryptsetup-keys.d/cryptvar.key	<options>
crypthome	UUID=<uuid>	/etc/cryptsetup-keys.d/crypthome.key	<options>
```

## Edit /etc/fstab

With the mapped devices mounted and the mapped swap device swapped on,
print a workable fstab with `genfstab`. Remove the keys partition's
entry; we don't unlock it and don't want to mount it. Write the
remaining entries for root, boot, swap, suspendroot, tmp, var, and home
in this order to `/etc/fstab`. For reference, the field format is

```
device	dir	type	options		dump	fsck
```

## initramfs

In `/etc/mkinitcpio.conf` configure initramfs to
embed the keys partition keyfile and update the `HOOKS`.

```
FILES=(/root/cryptkeys.key)
HOOKS=(base udev autodetect keyboard keymap consolefont modconf block keysencrypt filesystems fsck)
```

`keysencrypt` is a custom hook; get it using git,
and configure it.

```
git clone --depth=1 https://github.com/littleroot/archutil
TODO
```

Regenerate initramfs image:
```
mkinitcpio --allpresets
```

## Bootloader

### Encrypted boot

Grub has to learn that the encrypted boot partition needs to be
unlocked. Grub can handle luks1 encrypted devices. In
`/etc/default/grub`:
```
GRUB_ENABLE_CRYPTODISK=y
```

### Install new grub bootloader

```
# mkdir /efi
# mount /dev/nvme0n1<n> /efi
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

Re-generate main grub config file. This re-generation accounts for the
boot partition decryption, the kernel parameters, and to activate
microcode updates.
```
# grub-mkconfig -o /boot/grub/grub.cfg
```

## Safe suspend-to-memory

TODO: suspendroot













---







The install uses a busybox-based initramfs.



[2]: https://security.stackexchange.com/questions/40208/recommended-options-for-luks-cryptsetup

## TODO

### /usr as a separate partition

https://wiki.archlinux.org/title/Mkinitcpio#/usr_as_a_separate_partition

If you keep /usr as a separate partition, you must adhere to the following requirements:
Add the fsck hook, mark /usr with a passno of 2 in /etc/fstab to run the check on the partition at startup. While recommended for everyone, it is mandatory if you want your /usr partition to be fsck'ed at boot-up. Without this hook, /usr will never be fsck'd.
If not using the systemd hook, add the usr hook. This will mount the /usr partition after root is mounted.

run_latehook: Functions of this name are run after the root device has been mounted. This should be used, sparingly, for further setup of the root device, or for mounting other file systems, such as /usr.

### cryptsetup params

cryptsetup --type luks2 --cipher aes-xts-plain64 --hash sha256 --iter-time 2000 --key-size 256 --pbkdf argon2id --use-urandom --verify-passphrase luksFormat device

### Enable microcode

See grub section.

https://wiki.archlinux.org/title/Microcode

### TRIM

enable TRIM when luks decryption open options is involved
https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)

against trim: https://unix.stackexchange.com/a/532615/151000
use `fstrim` periodically instead

### options for crypttab

luks option in 4th column?

### suspend

remove keys;
resume should be possible using swap;
hard to do when using root partition currently before suspend
luksResume, luksSuspend
https://waaaaargh.github.io/gnu&linux/2013/08/06/lukssuspend-with-encrypted-root-on-archlinux/

also need work on combining suspend to memory instructions
with suspend to disk.

### encrypted swap cannot be resumed from suspend

only only device can be uncloked by encrypt hook (the root device)
so need mkinitcpio manual work
https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption#mkinitcpio_hook
and do not automount for swap parition (attr 63)

### Encrypted /boot

https://wiki.archlinux.org/title/GRUB#Encrypted_/boot
https://wiki.archlinux.org/title/Dm-crypt/Device_encryption#With_a_keyfile_embedded_in_the_initramfs

### Use a separate "keys" partition

technique, see hook: https://github.com/ajs124/decrypt-initcpio
original encrypt hook: https://github.com/archlinux/svntogit-packages/tree/packages/cryptsetup/trunk

### Disable workqueue for increased solid state drive (SSD) performance

Solid state drive users should be aware that, by default, discarding internal read and write workqueue commands are not enabled by the device-mapper, i.e. block-devices are mounted without the no_read_workqueue and no_write_workqueue option unless you override the default.

The no_read_workqueue and no_write_workqueue flags were introduced by internal Cloudflare research Speeding up Linux disk encryption made while investigating overall encryption performance. One of the conclusions is that internal dm-crypt read and write queues decrease performance for SSD drives. While queuing disk operations makes sense for spinning drives, bypassing the queue and writing data synchronously doubled the throughput and cut the SSD drives' IO await operations latency in half. The patches were upstreamed and are available since linux 5.9 and up [5].

To disable workqueue for LUKS devices unlocked via crypttab use one or more of the desired no-read-workqueue or no-write-workqueue options. E.g.:
```
/etc/crypttab
luks-123abcdef-etc UUID=123abcdef-etc none no-read-workqueue
```
To disable both read and write workqueue add both flags:
```
/etc/crypttab
luks-123abcdef-etc UUID=123abcdef-etc none no-read-workqueue,no-write-workqueue
```
With LUKS2 you can set --perf-no_read_workqueue and --perf-no_write_workqueue as default flags for a device by opening it once with the option --persistent. For example:
```
# cryptsetup --perf-no_read_workqueue --perf-no_write_workqueue --persistent open /dev/sdaX root
```
When the device is already opened, the open action will raise an error. You can use the refresh option in these cases, e.g.:
```
# cryptsetup --perf-no_read_workqueue --perf-no_write_workqueue --persistent refresh root
```

### attribute 63 (do not automount)

For swap necessary? (ref: https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption#mkinitcpio_hook)
