
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
./make-preseed-iso.sh -p laptop -o laptop-netinst-11.4.0-amd64-netinst.iso firmware-11.4.0-amd64-netinst.iso
```


### Pre-seed examples

All `preseed.cfg` options: <https://preseed.debian.net/debian-preseed/>.

Examples for VMware and headless laptop are included. VMware example should
work in any other virtualisation environment like libvirt, Vagrant or Hyper-V.

Those examples install minimal packages and default SSH access as root for
further configuration. Authorized SSH keys are volatile and only used until
persistent SSH public keys are installed.

- VMware
    - GPT partition table and no LVM
    - XFS root `/` partition
    - Swap size is twice RAM size (limited to 16GB)
    - BIOS or EFI
    - Display IP address on console
    - `ifupdown` for network configuration

- laptop
    - GTP partition table with LVM
    - Expect EFI but shall work on BIOS boot
    - EXT4 `/boot` partition
    - XFS root `/` partition
    - Reserve less swap than VMware preseed (125% of RAM size)
    - Display IP address on console
    - No sleep when lid close.
    - `Network Manager` for network configuration

OpenSSH server running and root login accessible by SSH authorized key.

A default user account `lboulard` is created with hard-coded password.
Change `passwd/make-user` to `false` in `preseed.cfg` to remove user creation.
Use `mkpassword` from `whois` package to change encrypted password in
`preseed.cfg`.

```sh
  mkpassword -m sha-256 [password]
```
