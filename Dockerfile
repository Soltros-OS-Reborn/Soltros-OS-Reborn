ARG BASE_REF
ARG FEDORA_VERSION
ARG DESKTOP_VARIANT=kde
ARG KERNEL_PACKAGE=kernel-cachyos

FROM ${BASE_REF} AS third-party-tools
ARG DESKTOP_VARIANT
RUN dnf5 -y install aria2 gcc git gtk-update-icon-cache make minisign unzip
COPY build_files/third-party-tools.sh /usr/local/bin/third-party-tools.sh
COPY release/sources.lock.json /usr/local/share/soltros/sources.lock.json
RUN chmod 0755 /usr/local/bin/third-party-tools.sh && \
    DESKTOP_VARIANT=${DESKTOP_VARIANT} /usr/local/bin/third-party-tools.sh /out /usr/local/share/soltros/sources.lock.json && \
    dnf5 clean all

# Stage 1: context for scripts (not included in final image)
FROM ${BASE_REF} AS ctx
COPY build_files/ /ctx/
COPY desktop_files/ /ctx/desktop-files/
COPY resources/soltros-gdm.png /ctx/desktop-files/gnome/usr/share/pixmaps/fedora-gdm-logo.png
COPY variants/desktop-variants.json /ctx/desktop-variants.json
COPY release/release.json /ctx/release.json
COPY release/sources.lock.json /ctx/sources.lock.json
COPY resources/policy.json /ctx/policy.json
COPY release/generated/registries.yaml /ctx/registries.yaml
COPY soltros.pub /ctx/soltros.pub

# Change perms
RUN chmod +x \
    /ctx/build.sh \
    /ctx/signing.sh \
    /ctx/overrides.sh \
    /ctx/cleanup.sh \
    /ctx/kernel.sh \
    /ctx/install-user-defaults.sh \
    /ctx/desktop-packages.sh \
    /ctx/apply-desktop-files.sh \
    /ctx/desktops/kde.sh \
    /ctx/desktops/gnome.sh \
    /ctx/desktops/niri-common.sh \
    /ctx/desktops/niri-dms.sh \
    /ctx/desktops/niri-noctalia.sh \
    /ctx/build-initramfs.sh \
    /ctx/nix-package-manager.sh \
    /ctx/desktop-defaults.sh \
    /ctx/repair-rpmdb.sh

FROM ${BASE_REF} AS soltros-common

ARG BASE_REF
ARG FEDORA_VERSION
ARG KERNEL_PACKAGE

# EXPLICIT DISTRO LABELS FOR BOOTC-IMAGE-BUILDER
# These override any conflicting labels and force correct distro detection
LABEL ostree.linux="fedora" \
    org.opencontainers.image.version="${FEDORA_VERSION}" \
    distro.name="fedora" \
    distro.version="${FEDORA_VERSION}"

# Your custom branding (these won't interfere)
LABEL org.opencontainers.image.title="SoltrOS Desktop" \
    org.opencontainers.image.description="Gaming-ready Fedora ${FEDORA_VERSION} bootc image with MacBook support" \
    org.opencontainers.image.vendor="SoltrOS Reborn"

# Copy static system configuration and branding
COPY system_files/etc /etc
COPY system_files/usr /usr
COPY --from=third-party-tools /out/usr /usr
COPY repo_files/*.repo /etc/yum.repos.d/
COPY repo_files/flatpaks /usr/share/soltros/flatpaks
COPY variants/desktop-variants.json /usr/share/soltros/desktop-variants.json
COPY release/release.json /usr/share/soltros/release.json
COPY release/sources.lock.json /usr/share/soltros/sources.lock.json
COPY soltros.pub /usr/share/pki/containers/soltros.pub
COPY resources/soltros-watermark.png /usr/share/plymouth/themes/spinner/watermark.png

# Create necessary directories for shell configurations
RUN mkdir -p /etc/profile.d /etc/fish/conf.d

# Ensure Distrobox is installed
RUN dnf5 install -y distrobox jq

# Install dnf5 plugins and setup CachyOS kernel repo
RUN dnf5 -y install dnf5-plugins
RUN dnf5 -y config-manager setopt "*cachyos*".priority=1

# Get rid of Plymouth
RUN dnf5 remove plymouth* -y && \
    systemctl disable plymouth-start.service plymouth-read-write.service plymouth-quit.service plymouth-quit-wait.service plymouth-reboot.service plymouth-kexec.service plymouth-halt.service plymouth-poweroff.service 2>/dev/null || true && \
    rm -rf /usr/share/plymouth /usr/lib/plymouth /etc/plymouth && \
    rm -f /usr/lib/systemd/system/plymouth* /usr/lib/systemd/system/*/plymouth* && \
    rm -f /usr/bin/plymouth /usr/sbin/plymouthd && \
    sed -i 's/rhgb quiet//' /etc/default/grub 2>/dev/null || true && \
    sed -i 's/splash//' /etc/default/grub 2>/dev/null || true && \
    sed -i '/plymouth/d' /etc/dracut.conf.d/* 2>/dev/null || true && \
    echo 'omit_dracutmodules+=" plymouth "' > /etc/dracut.conf.d/99-disable-plymouth.conf && \
    grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true && \
    dracut -f 2>/dev/null || true && \
    dnf5 autoremove -y && \
    dnf5 clean all

# Mount and run build script from ctx stage
ENV KERNEL_PACKAGE=${KERNEL_PACKAGE}
RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    BASE_IMAGE=$BASE_REF BUILD_PHASE=common bash /ctx/build.sh

FROM soltros-common AS soltros

ARG BASE_REF
ARG DESKTOP_VARIANT

LABEL org.soltros.desktop="${DESKTOP_VARIANT}"

RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    BASE_IMAGE=$BASE_REF DESKTOP_VARIANT=$DESKTOP_VARIANT BUILD_PHASE=desktop bash /ctx/build.sh

RUN --mount=type=bind,from=ctx,source=/ctx,target=/ctx \
    /ctx/repair-rpmdb.sh && \
    bootc container lint && \
    ostree container commit && \
    rpm --verifydb
