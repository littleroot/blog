---
title: A 2021 arch install that emphasises separate partitions and encryption
layout: page
permalink: /arch-install-2021/
---

The partition sizes in the table are for a 256.0G disk and 16.0G memory.
It closely matches the default disk partitioning sizes used by
openbsd70, except for no separate usr partitions. You can use the same
sizes even if you have a larger disk—the space for root, tmp, and var
for personal use akin to mine should be universally okay, and moreover
note that home gets all remaining space anyway. For safe suspension to
disk you want the swap partition size >= your hardware's memory.

<center>Table 1. Partitions</center>

```
# partition	encrypted	fstype	      size	mountpoint	type	extra attr
1 boot		    luks1	  vfat	      512M	/boot		ef00
2 root		    luks2	  ext4	    46080M	/		8300
3 swap		    luks2	  swap	    16384M	[SWAP]		8200	63 (do not automount)
4 keys		    luks2	  ext4	        8M	/keys		8300
5 suspendroot	       no	  ext4	       64M	/suspendroot	8300
5 tmp		    luks2	  ext4	     4096M	/tmp		8300
6 var		    luks2	  ext4	    30720M	/var		8300
8 home		    luks2	  ext4	 remaining	/home		8300
```

The keys partition is an encrypted partition that holds encryption
keyfiles for the root, swap, tmp, var, and home partitions. The
encryption keyfile for the keys partition itself is embedded in
initramfs. From a cold boot or when resuming from hibernate, to unlock
the boot partition you need to enter the password for the boot
partition. After the boot partition is unlocked the keys partition is
automatically unlocked using the embedded keyfile in initramfs. A custom
`keysencrypt` hook, intended to address the shortcomings of the
`encrypt` hook, automatically unlocks root and swap using the keyfiles
held in the keys partition (when resuming from hibernate, it's
sufficient to only unlock swap).

The suspendroot partition is a dedicated partition to securely suspend
to memory. Before suspending to memory, partitions must be locked and
encryption keys in memory must be wiped. The `cryptsetup luksSuspend`
command can handle this. But you shouldn't `cryptsetup luksSuspend` the
root partition device that contains the `cryptsetup` binary; if you do
you can't call `cryptsetup luksResume` to unlock the device when waking
up. So to suspend to memory we copy essential files and binaries to the
suspendroot parition, `chroot` to it, and `luksSuspend` the root
partition device from there.

The install uses a busybox-based initramfs.

The grub bootloader. The install will set up a busybox initramdisk
(not a systemd initramdisk), and its `encrypt` hook will handle disk
decryption. Note that init will still use systemd though. You will have
to enter exactly one disk decryption password during a cold boot, and
exactly one disk decryption password when waking from suspension to
disk, aka hiberation. Suspend-to-disk will be configured to work.

The naming schemes will be pleasing, for example:
`/dev/mapper/cryptswap` not `/dev/mapper/cryptSwapPartition`.

## Partition disk

Boot into the install medium on a separate USB or separate hard disk.

Use `gdisk` to partition the main disk. Use `lsblk -f` to verify.

Vitally set attribute 63 (do not automount) on the swap partition.

<center>Table 2. gdisk partioning values</center>
```
# partition	first-sector	last-sector	type	extra attrs
1 boot		     default	   +<size>M	ef00
2 root		     default	   +<size>M	8300
3 swap		     default	   +<size>M	8200	63
4 tmp		     default	   +<size>M	8300
5 var		     default	   +<size>M	8300
6 home		     default	    default	8300

see previous table for the <size> values of '+<size>M'
```

The commands below assume your main disk is an NVMe disk named
`/dev/nvme0n1`.

## Encrypt and mount partitions

### Boot

This is partition #1. Recall that this won't be encrypted, so we
only have to create its filesystem and mount it.

```
# mkfs.fat -F32 /dev/nvme0n1p1
# mkdir -p /mnt/boot
# mount /dev/nvme0n1p1 /mnt/boot
```

### Swap

<a
href="https://security.stackexchange.com/questions/40208/">security.stackexchange</a>'s
recommendation matches the current default behavior of `cryptsetup
luksFormat` so we just use the default without additional options.

```
# cryptsetup luksFormat /dev/nvme0n1p3
... enter an encryption password ...
# cryptsetup open /dev/nvme0n1p3 cryptswap
# mkswap /dev/mapper/cryptswap
# swapon /dev/mapper/cryptswap
```

### Others

The root partition (partition #2)
```
# cryptsetup luksFormat /dev/nvme0n1p2
... enter an encryption password ...
# cryptsetup open /dev/nvme0n1p2 cryptroot
# mkfs.ext4 /dev/mapper/cryptroot
# mkdir -p /mnt
# mount /dev/mapper/cryptroot /mnt
```
The tmp partition (partition #4)
```
# cryptsetup luksFormat /dev/nvme0n1p4
... enter an encryption password ...
# cryptsetup open /dev/nvme0n1p4 crypttmp
# mkfs.ext4 /dev/mapper/crypttmp
# mkdir -p /mnt/tmp
# mount /dev/mapper/crypttmp /mnt/tmp
```
The var partition (partition #5)
```
# cryptsetup luksFormat /dev/nvme0n1p5
... enter an encryption password ...
# cryptsetup open /dev/nvme0n1p5 cryptvar
# mkfs.ext4 /dev/mapper/cryptvar
# mkdir -p /mnt/var
# mount /dev/mapper/cryptvar /mnt/var
```
The home partition (partition #6)
```
# cryptsetup luksFormat /dev/nvme0n1p6
... enter an encryption password ...
# cryptsetup open /dev/nvme0n1p6 crypthome
# mkfs.ext4 /dev/mapper/crypthome
# mkdir -p /mnt/home
# mount /dev/mapper/crypthome /mnt/home
```

Bask in `lsblk -f`'s output.

## Install packages

```
# pacstrap /mnt base linux linux-firmware
```

Additionally include a text editor package (e.g. `vim`) in this list,
so that you can edit some files below.

## Generate fstab

This looks at the current `/mnt` and enabled swap to generate
fstab.

```
# genfstab -t UUID /mnt >> /mnt/etc/fstab
```

## Switch to the new system

```
# arch-chroot /mnt
```

### Name the system

Write the hostname to `/etc/hostname`.

### Set the root password

```
# passwd
```

## Configure `mkinitcpio`

Edit `/etc/mkinitcpio.conf`. We will use a busybox initramdisk. The
`HOOKS` line should by default be configured for this (notice `udev`).
Save a commented-out copy of this line before making an edit.

Add `keyboard`, `keymap`, and `encrypt` hooks to `HOOKS`.

Generate a new initramfs image.
```
# mkinitcpio -P		(equivalently: mkinitcpio --allpresets)
```

## Configure `grub` (bootloader)

### Kernel parameters

Set `root` and `resume` kernel parameters. The `resume` parameter
determines the device used while resuming from disk suspension.

Also set the encryption-related `cryptdevice` parameter. The
`<uuid-for-nvme0n1p2>` value is the UUID for `/dev/nvme0n1p2` (use
`lsblk -f` to find this).

```
root=/dev/mapper/cryptroot
resume=/dev/mapper/cryptswap
cryptdevice=<uuid-for-nvme0n1p2>:cryptroot
```

Generate the main boot configuration file.

```
# grub-mkconfig -o /boot/grub/grub.cfg
```

### Microcode updates

This section only applies for AMD and Intel processors.

TODO(ns): Incomplete.

## Automate partition decryption

*Goal:* After the root partition is decrypted during a cold boot by
manually providing the root partition decryption password, systemd
during init should read keyfiles stored in the root partition to decrypt
other partitions (#4, #5, #6, to be particular) without manually
requiring each of their passwords.

The steps follow.

### Save passwords of the other partitions to keyfiles

For non-root, non-swap encrypted partitions, that is, #4, #5, and #6,
save their passwords to keyfiles on the encrypted root partition under
`/etc/`.

```
# mkdir -p /etc/cryptsetup-keys.d
```

For the tmp partition (partition #4)
```
# printf '<encryption password>' >> /etc/cryptsetup-keys.d/crypttmp.key
```
For the var partition (partition #5)
```
# printf '<encryption password>' >> /etc/cryptsetup-keys.d/cryptvar.key
```
For the home partition (partition #6)
```
# printf '<encryption password>' >> /etc/cryptsetup-keys.d/crypthome.key
```

### crypttab

The file `/etc/crypttab` needs to contain configuration about how to
decrypt partitions. `/etc/crypttab` is read before `/etc/fstab` and is
used by the system to produce the decrypted partitions that `fstab` can
eventually use.

Update the file with a line each for partitions #4, #5, and #6.

```
crypttmp	UUID=<uuid-for-nvme0n1p4>	/etc/cryptsetup-keys.d/crypttmp.key
cryptvar	UUID=<uuid-for-nvme0n1p5>	/etc/cryptsetup-keys.d/cryptvar.key
crypthome	UUID=<uuid-for-nvme0n1p6>	/etc/cryptsetup-keys.d/crypthome.key
```

Use `lsblk -f` to find the values for `<uuid-for-nvme0n1p4>`,
`<uuid-for-nvme0n1p5>`, and `<uuid-for-nvme0n1p6>`. Don't miss the
"`UUID=`" prefix before each actual UUID value.

## Swap

```
```

### Encryption support

## Suspend to disk

[1]: https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system#LUKS_on_a_partition
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

/etc/crypttab
luks-123abcdef-etc UUID=123abcdef-etc none no-read-workqueue
To disable both read and write workqueue add both flags:

/etc/crypttab
luks-123abcdef-etc UUID=123abcdef-etc none no-read-workqueue,no-write-workqueue
With LUKS2 you can set --perf-no_read_workqueue and --perf-no_write_workqueue as default flags for a device by opening it once with the option --persistent. For example:

# cryptsetup --perf-no_read_workqueue --perf-no_write_workqueue --persistent open /dev/sdaX root
When the device is already opened, the open action will raise an error. You can use the refresh option in these cases, e.g.:

# cryptsetup --perf-no_read_workqueue --perf-no_write_workqueue --persistent refresh root
