#!/usr/bin/bash

set -euo pipefail

export_file="$(mktemp)"
rebuilt_dir="$(mktemp -d /usr/share/soltros-rpmdb-XXXXXX)"

cleanup() {
    rm -f "${export_file}"
    rm -rf "${rebuilt_dir}"
}

trap cleanup EXIT

rpmdb --exportdb > "${export_file}"
rpmdb --dbpath "${rebuilt_dir}" --initdb
rpmdb --dbpath "${rebuilt_dir}" --importdb < "${export_file}"
rpmdb --dbpath "${rebuilt_dir}" --verifydb

for required_provider in \
    'filesystem(unmerged-sbin-symlinks)' \
    'libuuid.so.1()(64bit)' \
    'group(tss)'; do
    rpm --dbpath "${rebuilt_dir}" -q --whatprovides "${required_provider}"
done

find /usr/share/rpm -maxdepth 1 -type f \
    \( -name '.rpm.lock' -o -name 'rpmdb.sqlite*' \) -delete
cp -a "${rebuilt_dir}"/. /usr/share/rpm/

rpmdb --verifydb
for required_provider in \
    'filesystem(unmerged-sbin-symlinks)' \
    'libuuid.so.1()(64bit)' \
    'group(tss)'; do
    rpm -q --whatprovides "${required_provider}"
done
