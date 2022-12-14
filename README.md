
## Generate Debian 11 ISO images with `preseed.cfg`

Based on <https://github.com/JaeGerW2016/debian_11-bullseye-preseed>.
Modified to accept configurations, embed multiple files, minor bug fixes and
colored progress.

### Requirements

Tools `cpio`, `gzip` and `xorriso` are required by `make-preseed-iso.sh` script.

```sh
sudo apt install gzip cpio xorriso
```

### Command line usage

```text
Usage: make-preseed-iso.sh [-p preseed.cfg|preseed/] [-o preseed-debian-image.iso] [-f] path/to/debian-image.iso

  -p preseed.cfg|preseed_dir
      Use this file as preseed.cfg, or a directory with preseed.cfg inside
  -o preseed-debian-image.iso
      Save ISO to this name, default is to prefix ISO source name with "preseed-"
  -f
      Force overwriting output file. Default is to fail if output file exists.
```


### Hasty usage

Quick instructions to create network installer ISO images with preseed files.

```sh
# Network intaller for Debian 11.4.0
wget https://cdimage.debian.org/cdimage/unofficial/non-free/images-including-firmware/11.4.0+nonfree/amd64/iso-cd/SHA256SUMS
wget https://cdimage.debian.org/cdimage/unofficial/non-free/images-including-firmware/11.4.0+nonfree/amd64/iso-cd/SHA256SUMS.sign
wget https://cdimage.debian.org/cdimage/unofficial/non-free/images-including-firmware/11.4.0+nonfree/amd64/iso-cd/firmware-11.4.0-amd64-netinst.iso
sha256sum -c SHA256SUMS

# Update installer ISO images with preseed files
./make-preseed-iso.sh -p vmware -o vm-netinst-11.4.0-amd64-netinst.iso firmware-11.4.0-amd64-netinst.iso
./make-preseed-iso.sh -p headless -o headless-netinst-11.4.0-amd64-netinst.iso firmware-11.4.0-amd64-netinst.iso
```


### Pre-seed examples

All `preseed.cfg` options: <https://preseed.debian.net/debian-preseed/>.

Examples for VMware, headless and desktop machines are included. VMware example
should work in any other virtualisation environment like libvirt, Vagrant or
Hyper-V.

Those examples install minimal packages and default SSH access as root for
further configuration. Authorized SSH keys are volatile and only used until
persistent SSH public keys are installed.

- VMware machine
    - GPT partition table and no LVM
    - BIOS or EFI
    - XFS root `/` partition
    - Swap size is twice RAM size (limited to 16GB)
    - Display IP address on console
    - Keyboard with Right Alt as Compose key
    - Keyboard with Caps Lock as Control Key
    - Linux Kernel image from bullseyes backports (Linux 5.18)
    - Frame buffer console in 1024x768 resolution and Terminus font 8x14
    - `lm-sensors` for system information
    - `ifupdown` for network configuration

- Headless machine
    - GTP partition table with LVM
    - Expect EFI but shall work on BIOS boot
    - EXT2 `/boot` partition
    - XFS root `/` partition
    - Swap partition size as 125% of RAM size, capped to 16GB
    - Display IP address on console
    - Keyboard with Right Alt as Compose key
    - Keyboard with Caps Lock as Control Key
    - Linux Kernel image from bullseyes backports (Linux 5.18)
    - Frame buffer console in 1024x768 resolution and Terminus font 8x14
    - `lm-sensors` for system information
    - `Network Manager` for network configuration
    - No sleep when lid close.

- Desktop machine
    - GPT partition table and no LVM
    - Expect EFI but shall work on BIOS boot
    - EXT2 `/boot` partition
    - XFS root `/` partition
    - Swap partition size as 125% of RAM size, capped to 16GB
    - Display IP address on console
    - Keyboard with Right Alt as Compose key
    - Keyboard with Caps Lock as Control Key
    - Linux Kernel image from bullseyes backports (Linux 5.18)
    - Frame buffer console in 1024x768 resolution and Terminus font 8x14
    - `lm-sensors` for system information
    - `Network Manager` for network configuration
    - No sleep when lid close.
    - Install default desktop of Debian 11 (Gnome 3.38)

OpenSSH server running and root login accessible by SSH authorized key.

A default user account `lboulard` is created with hard-coded password.
Change `passwd/make-user` to `false` in `preseed.cfg` to remove user creation.
Use `mkpassword` from `whois` package to change encrypted password in
`preseed.cfg`.

```sh
  mkpassword -m sha-256 [password]
```
