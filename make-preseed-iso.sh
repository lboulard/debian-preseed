#!/bin/bash

set -euo pipefail

workdir="${workdir:-.workdir}"
isofiles="${workdir}/CD1"

RED=""
GREEN=""
RESET=""
if [ -n "${TERM:-}" ] && [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  RED="$(tput setaf 1)$(tput bold)"
  GREEN="$(tput setaf 2)$(tput bold)"
  RESET="$(tput sgr0)"
fi

function progress() {
  printf "%s -> %s%s\n" "$GREEN" "$1" "$RESET"
}

function extract_iso() {
  progress "Extracting iso: $1..."
  [ -e "$isofiles" ] && { chmod +w -R "$isofiles" && rm -fr "$isofiles"; }
  mkdir "$isofiles"
  xorriso -osirrox on -indev "$1" -extract / "$isofiles"
}

function copy_preseed_dir() {
  (
    cd "$1"
    find . -name \* -a ! \( -name \*~ -o -name \*.bak -o -name \*.orig \) -print0
  ) | cpio -v -p -L -0 -D "$1" "$2"
}

function copy_preseed() {
  if [ -d "$1" ]; then
    copy_preseed_dir "$1" "$2"
  else
    install "$1" "$2/preseed.cfg"
  fi
}

function add_preseed_to_initrd() {
  progress "Adding '$1' to initrd..."

  install -d "$workdir/preseed"
  copy_preseed "$1" "$workdir/preseed"

  chmod +w -R "$isofiles/install.amd/"
  gunzip "$isofiles/install.amd/initrd.gz"
  (
    # option -D of cpio is broken with -F
    p="$(readlink -f "$isofiles")"
    cd "$workdir/preseed"
    find . -print0 | cpio -v -H newc -o -0 -L -A -F "$p/install.amd/initrd"
  )
  echo gzip -6 "$isofiles/install.amd/initrd"
  gzip -6 "$isofiles/install.amd/initrd"
  chmod -w -R "$isofiles/install.amd/"
}

function make_auto_the_default_isolinux_boot_option() {
  progress "Setting 'auto' as default ISOLINUX boot entry..."

  # shellcheck disable=SC2016
  sed -e 's/timeout 0/timeout 3/g' -e '$adefault auto' \
    "$isofiles/isolinux/isolinux.cfg" >"$workdir/isolinux.cfg"

  chmod +w "$isofiles/isolinux/isolinux.cfg"
  cat "$workdir/isolinux.cfg" >"$isofiles/isolinux/isolinux.cfg"
  chmod -w "$isofiles/isolinux/isolinux.cfg"
}

function make_auto_the_default_grub_boot_option() {
  progress "Setting 'auto' as default GRUB boot entry..."

  # The index for the grub menus is zero-based for the
  # Root menu, but 1-based for the rest, so 2>5 is the
  # second menu (advanced options) => fifth option (auto)

  chmod +w "$isofiles/boot/grub/grub.cfg"
  {
    echo 'set default="2>5"'
    echo "set timeout=3"
  } >>"$isofiles/boot/grub/grub.cfg"
  chmod -w "$isofiles/boot/grub/grub.cfg"
}

function update_md5_checksum() {
  progress "Recalculating MD5 checksum for ISO verification..."
  rm -f "$isofiles/md5sum.txt"
  chmod +w "$isofiles/.disk"
  rm -f "$isofiles/.disk/mkisofs"
  (
    set -euo pipefail
    cd "$isofiles"
    find . \( -type d -name isolinux -prune \) -o -type f -print0 |
      xargs -0 md5sum
  ) | sort -k2 >"$workdir/md5sum.txt"
  install -m "444" "$workdir/md5sum.txt" "$isofiles/md5sum.txt"
  rm "$workdir/md5sum.txt"
}

function mkisofs_command() {
  local volid
  volid="$(dd if="$orig_iso" bs=32 count=1 skip=32808 iflag=skip_bytes status=none | xargs)"
  echo xorriso -as mkisofs \
    -r \
    -checksum_algorithm_iso sha256,sha512 \
    -V \'"$volid"\' \
    -o \'"$new_iso"\' \
    -J -joliet-long \
    -isohybrid-mbr \'"$workdir/mbr_template.bin"\' \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -boot-load-size 4 -boot-info-table \
    -no-emul-boot -eltorito-alt-boot \
    -e boot/grub/efi.img -no-emul-boot \
    -isohybrid-gpt-basdat \
    -isohybrid-apm-hfsplus \
    \'"$isofiles"\'
}

function generate_new_iso() {
  local orig_iso="$1"
  local new_iso="$2"

  progress "Generating new iso: $new_iso..."
  progress " -- ignore the warning about a 'file system loop' below"
  progress " -- ignore warnings about symlinks for Joliet, they are created for RockRidge"

  [ -e "$new_iso" ] && rm -f "$new_iso"
  dd if="$orig_iso" bs=432 count=1 of="$workdir/mbr_template.bin" status=none
  chmod +w "$isofiles/isolinux/isolinux.bin"
  mkisofs_command >"$isofiles/.disk/mkisofs"
  chmod -w "$isofiles/.disk/mkisofs" "$isofiles/.disk"
  mkisofs_command | sh -x
}

function cleanup() {
  progress "cleanup ..."
  chmod +w "$workdir" -R
  rm -rf "$workdir"
}

function usage() {
  if [ "${1-0}" -ne 0 ]; then
    exec >&2
  fi
  printf "Usage: %s [-p preseed.cfg|preseed/] [-o preseed-debian-image.iso] [-f] path/to/debian-image.iso\n" "$(basename "$0")"
  printf "\n"
  printf "  -p preseed.cfg|preseed_dir\n"
  printf "      Use this file as preseed.cfg, or a directory with preseed.cfg inside\n"
  printf "  -o preseed-debian-image.iso\n"
  printf "      Save ISO to this name, default is to prefix ISO source name with \"preseed-\"\n"
  printf "  -f\n"
  printf "      Force overwriting output file. Default is to fail if output file exists.\n"
  if [ "${1:-0}" -ge "0" ]; then
    exit "${1:-0}"
  fi
}

function check_program_installed() {
  command -v "$1" 2>/dev/null >&2 && return 0
  if [ -t 2 ]; then
    printf >&2 "%s%s: command not found, please install package %s%s\n" \
      "$RED" "$1" "${2:$1}" "$RESET"
  else
    printf >&2 "%s: command not found, please install package %s\n" \
      "$1" "${2:$1}"
  fi
  return 1
}

function check_requirements() {
  local ok=0
  check_program_installed dd coreutils || ok=1
  check_program_installed gzip || ok=1
  check_program_installed cpio || ok=1
  check_program_installed xorriso || ok=1
  return $ok
}

function ensure_file_presence() {
  if [ ! -e "$1" ]; then
    die "$1: file not found"
  fi
}

function die() {
  if [ -t 2 ]; then
    printf >&2 "%s%s%s\n" "$RED" "$1" "$RESET"
  else
    printf >&2 "%s\n" "$1"
  fi
  exit 1
}

if ! check_requirements; then
  die "** ERROR: missing installed programs, cannot continue"
fi

while getopts "fho:p:" arg; do
  case $arg in
  h) usage ;;
  f) force="yes" ;;
  o) new_iso="${OPTARG}" ;;
  p) preseed_cfg="${OPTARG}" ;;
  *) usage 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ -z "${1-}" ]; then
  usage -1
  die "** ERROR: Debian ISO installation disk argument missing"
fi

orig_iso="$1"
preseed_cfg="${preseed_cfg:-preseed.cfg}"
new_iso="${new_iso:-preseed-$(basename "$orig_iso")}"
force="${force:-}"

progress "source: $orig_iso"
progress "dest  : $new_iso"

ensure_file_presence "$orig_iso"
if [ -d "$preseed_cfg" ]; then
  ensure_file_presence "$preseed_cfg/preseed.cfg"
else
  ensure_file_presence "$preseed_cfg"
fi
if [ "$force" != "yes" ] && [ -e "$new_iso" ]; then
  die "${new_iso}: already exist, use -f to silently overwrite"
fi

install -m 0755 -d "$workdir"

extract_iso "$orig_iso"
add_preseed_to_initrd "$preseed_cfg"
make_auto_the_default_isolinux_boot_option
make_auto_the_default_grub_boot_option
update_md5_checksum
generate_new_iso "$orig_iso" "$new_iso"
cleanup

progress "${new_iso}: DONE"
