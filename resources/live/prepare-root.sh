#!/usr/bin/env bash

set -euo pipefail

live_package_manifest="${SOLTROS_LIVE_PACKAGE_MANIFEST:-/usr/share/soltros/live/packages.txt}"
live_variant="${SOLTROS_LIVE_VARIANT:-kde}"
if [[ ! -r "${live_package_manifest}" ]]; then
  echo "Live package manifest is missing: ${live_package_manifest}" >&2
  exit 1
fi
mapfile -t live_packages < <(sed -e '/^[[:space:]]*$/d' -e '/^[[:space:]]*#/d' "${live_package_manifest}" | sort -u)
if (( ${#live_packages[@]} == 0 )); then
  echo 'Live package manifest is empty' >&2
  exit 1
fi

dnf --disablerepo='*' --enablerepo=fedora --enablerepo=updates \
  --enablerepo=fedora-cisco-openh264 \
  install --assumeyes \
  "${live_packages[@]}"

grub_defaults=/etc/default/grub
if [[ -f "${grub_defaults}" ]]; then
  if grep -q '^GRUB_CMDLINE_LINUX=' "${grub_defaults}"; then
    sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="selinux=0"/' "${grub_defaults}"
  else
    printf '%s\n' 'GRUB_CMDLINE_LINUX="selinux=0"' >> "${grub_defaults}"
  fi
else
  install -D -m 0644 /dev/null "${grub_defaults}"
  printf '%s\n' 'GRUB_CMDLINE_LINUX="selinux=0"' > "${grub_defaults}"
fi

efi_grub_source="$(find /usr/lib/efi/grub2 -path '*/EFI/fedora/gcdx64.efi' -type f -print -quit)"
efi_shim_source="/usr/lib/efi/shim/$(rpm -q --qf '%{VERSION}-%{RELEASE}\n' shim-x64)/EFI"
test -n "${efi_grub_source}"
test -f "${efi_shim_source}/fedora/shimx64.efi"
install -d -m 0755 /boot/efi/EFI/fedora /boot/efi/EFI/BOOT
install -m 0700 "${efi_grub_source}" /boot/efi/EFI/fedora/gcdx64.efi
for efi_file in BOOTX64.EFI fbx64.efi; do
  install -m 0700 "${efi_shim_source}/BOOT/${efi_file}" \
    "/boot/efi/EFI/BOOT/${efi_file}"
done
for efi_file in BOOTX64.CSV mmx64.efi shim.efi shimx64.efi; do
  install -m 0700 "${efi_shim_source}/fedora/${efi_file}" \
    "/boot/efi/EFI/fedora/${efi_file}"
done

# Lorax discovers kernels only through versioned files under /boot.
kernel_count=0
while IFS= read -r kernel_version; do
  kernel_source="/usr/lib/modules/${kernel_version}/vmlinuz"
  if [[ ! -s "${kernel_source}" ]]; then
    continue
  fi
  install -m 0644 "${kernel_source}" "/boot/vmlinuz-${kernel_version}"
  ((kernel_count += 1))
done < <(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V)
if (( kernel_count == 0 )); then
  echo 'No bootc kernel is available for the LiveISO boot tree' >&2
  exit 1
fi

if ! id liveuser >/dev/null 2>&1; then
  useradd --create-home --groups wheel --shell /bin/bash liveuser
fi

passwd --delete liveuser >/dev/null
install -d -m 0755 /etc/sudoers.d /etc/polkit-1/rules.d
printf '%s\n' 'liveuser ALL=(root) NOPASSWD: /usr/bin/liveinst' > /etc/sudoers.d/soltros-live-installer
chmod 0440 /etc/sudoers.d/soltros-live-installer

install -D -m 0644 /usr/share/soltros/live/soltros-live-installer.rules \
  /etc/polkit-1/rules.d/49-soltros-live-installer.rules
install -D -m 0644 /usr/share/soltros/live/soltros-installer.desktop \
  /home/liveuser/Desktop/soltros-installer.desktop
chown liveuser:liveuser /home/liveuser/Desktop/soltros-installer.desktop
chmod 0755 /home/liveuser/Desktop/soltros-installer.desktop
chmod 0755 /home/liveuser/Desktop

touch /.liveimg
printf '%s\n' 'soltros-live' > /etc/hostname
rm -f /etc/machine-id
ln -s /dev/null /etc/systemd/system/systemd-firstboot.service
systemctl enable NetworkManager.service
systemctl enable bluetooth.service
case "${live_variant}" in
  kde)
    install -D -m 0644 /usr/share/soltros/live/plasmalogin.conf /etc/plasmalogin.conf
    systemctl enable plasmalogin.service
    ln -sfn /usr/lib/systemd/system/plasmalogin.service \
      /etc/systemd/system/graphical.target.wants/plasmalogin.service
    ;;
  gnome)
    systemctl enable gdm.service
    ln -sfn /usr/lib/systemd/system/gdm.service \
      /etc/systemd/system/graphical.target.wants/gdm.service
    ;;
  niri-dms|niri-noctalia)
    systemctl enable greetd.service
    ln -sfn /usr/lib/systemd/system/greetd.service \
      /etc/systemd/system/graphical.target.wants/greetd.service
    ;;
  *)
    echo "Unsupported LiveISO desktop variant: ${live_variant}" >&2
    exit 1
    ;;
esac

install -D -m 0644 /usr/share/soltros/live/motd /etc/motd
