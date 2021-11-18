---
title: File encryption
layout: page
permalink: /securing-data-mac/
---

Consider the usual workflow for working with a sensitive, encrypted
document.

  * You have the encrypted document saved on the hard disk.
  * To edit the document, you first unencrypt it and save the resulting
    unencrypted document to the hard disk.
  * You make changes to the unencrypted document.
  * When you're done, you re-encrypt it, save the
    resulting encrypted document to the hard disk (usually replacing
    the old encrypted document), and delete
    the unencrypted document.

It is crucial to delete the unecrypted
document from the hard disk after you're done working on it. Otherwise
the bits of data of the sensitive, unencrypted document will still be
present in the disk.

Modern file systems make it really difficult to
completely delete a file. Recent Mac computers either
use the HFS+ file system or the APFS file system. HFS+ is a journaling
file system, and journaling file systems can keep a copy of a file
elsewhere even after it is deleted. In a similar vein, macOS
uses the snapshotting capability of HFS+ and APFS, and snapshots can
contain a copy of a deleted file.

Tools such as `shred` that are often used to securely delete files by
overwriting the data bits on the hard disk are ineffective in modern
file systems.



## Encryption

The solution to e

How do you store sensitive information securely on a computer? The first
thing to consider is to just *not* store sensitive information on a
computer in the first place. There is literally no combination of tools
or best practices that will ensure that your information can't be read by
others. So never storing the information is the safest, infallible option.

Still, if you must store sensitive information on a computer:
store it encrypted. This article explains how to do this correctly
on a Mac.

## What does encryption do?

In essence, encryption makes your sensitive data undecipherable to
anyone who doesn't have the decryption password. As a concrete example,
here's a file containing sensitive information:

```
locker code ae303KUOUYzJ0HUUI6dsPSwn686
```

Its encrypted representation will look like:

```
Salted__‡0ãP÷ “¸Ê9Á0²w¬É¾s]a=1¶4¡Ö0~>µ%ÀAùpTúz5¥/)6k‡Õæ«:láŒ
```

With the correct decryption password, you can convert the encrypted
representation back to the original representation in <100
milliseconds. Without the decryption password, it should take a few hundred
years; it's practically impossible to retrieve the original
representation without the decryption password.

The first thing to do is enable FireVault, a built-in disk encryption
program. You can do this in the "Security & Privacy" pane in System
Preferences. If you have already written sensitive information to disk
in the past with FireVault disabled, you should seriously consider
securely erasing your hard disk (using e.g. the Disk Utility app) and
start over with a fresh installation of macOS.

Your data will be transparently converted between its original and
encrypted forms when you read and write files.

Do not associate your iCloud account as a recovery option with
FireVault. Do not store your FireVault recovery key or your login
password unencrypted on any computer.

The goal of this article is to give you the confidence and understanding
to do this correctly. Your data will still be vulnerable in certain
situations (see section [**Still vulnerable**](#still-vulnerable)).

Before we begin, this article is highly specific to Mac.

Mac Mac file systems such as HFS+ and APFS are journaling file systems;
they may store past "snapshots" of the file system, which can contain
data from the past that you otherwise think has been deleted or
ovewritten.

The key takeaway is that if you must write sensitive data to disk always
write it encrypted. A hassle-free way to write encrypted data is to use
full-disk encryption with FireVault, which is the topic of the next
section.

## Encrypt disk with FireVault

Your Mac has a built-in tool called FireVault, which provides disk-level
encryption.

### Understanding FireVault

There are three important things to know about how FireVault works.

  1. When a FireVault-enabled Mac writes data to disk, the data
     is written encrypted. As an example, your sensitive file:

     ```
     username: ns@example.org
     birthday: 1987-01-09
     ```
     will be written to disk as:
     ```
     Salted__ÁœS‚¢;¿VîŽQ¹ƒ
     #Ù¸Ò$Sod‘ÈcÜÔ™Ë³\t¢ß^àÎ0b³Ë^Ó»ž+
     ```

  1. No one will be able to decipher the encrypted data without an
     adminstrator login password or the recovery key. Anyone with
     the password or key will be able to easily decipher the data.

  1. When someone log in to your Mac after entering a valid
     administrator password, either after a restart or from the lock
     screen, macOS retrieves the FireVault encryption/decryption key.
     When you read or write a file, Mac uses
     this key to transparently convert between the original and
     encrypted representations.

     This key is stored in random-access memory, or RAM, for later use.
     This is important to note because this can be an attack
     vector (see section [*Still vulnerable*](#still-vulnerable), item 4).

### Enabling FireVault

You may have enabled FireVault already when you set up your Mac. If you
do not have FireVault enabled, you can enable it in the "Security &
Privacy" pane in System Preferences. Do not associate your iCloud
account as a recovery option; this adds a way through which your
FireVault keys can be compromised.

If you have already written sensitive information to disk without
encryption, you should seriously consider securely erasing your hard
disk and starting over, because data bits once written may continue to
stick around indefinitely on the SSD otherwise.

Do not store the FireVault recovery key on any computer.
Print the key, and keep it in a safe or in the home of someone you trust.

## Still vulnerable

Despite these steps, your data will still be vulnerable to the following.

  1. You are coerced, either "lawfully" by an unscrupulous government or
     forcefully by criminals, to provide the password that decrypts your
     files. See [xkcd.com/538](http://xkcd.com/538/).

  2. You unintentionally install a malicious program that e.g. reads
     your computer's hard disk and memory, or records your keystrokes.
     The malicious program will be able to read your most sensitive,
     individually-encrypted files (files encrypted atop of FireVault's
     disk level encryption) when you temporarily decrypt these files or
     by using a decryption password it has recorded. If your machine is
     connected to the Internet, the program can transfer this
     information to an adversary.

  3. Your computer is seized when you are logged in and have a
     sensitive file in decrypted state on your computer.

  4. You are the target of a [cold boot
     attack](https://en.wikipedia.org/wiki/Cold_boot_attack). For the
     attack to succeed, your adversary must have physical access to your
     Mac when you are logged in. The attack involves hard-resetting your
     computer and dumping the contents of RAM as it existed prior to the
     hard reset. The window of opportunity to complete this procedure is
     usually around 5 minutes after the hard reset, but can be longer if
     the RAM can be cooled to below-freezing temperatures. The RAM dump
     will contain the FireVault encryption/decryption keys of your hard
     disk and may contain the deciphered contents of sensitive files
     you've recently opened.

Item 1 can be be mitigated by having a bodyguard, tighter security
around your physical location, and powerful friends. This may not be
practical for most people, though.

Items 2 & 3 can be mitigated by being careful. Have sensitive files open
for as short a duration as possible; encrypt them immediately after use.
On the computer storing sensitive files, don't install programs you have
not vetted, and don't connect to the Internet.

I don't believe a mitigation exists for item 4, besides making the
computer physically inaccessible to an adversary. I couldn't find memory
that is safe from cold boot attacks.

## Summary

So in conclusion for the most sensitive files you want to secure:

  * Consider not storing the information on a computer in the first
    place.

  * Turn on FireVault. If you have already saved sensitive files on the
    disk before turning on FireVault, erase the entire hard disk and
    start over.

    <!--TODO:  mention Ciphertext -->
  * Encrypt the sensitive files individually, in addition to
    FireVault's disk-level encryption. This reduces the surface area for
    attacks.

  * You may still be vulnerable to attacks. But these steps may provide
    a degree of confidence that you find sufficient.
