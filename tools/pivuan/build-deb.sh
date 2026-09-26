#!/bin/bash
#
# Build the pivuan-config .deb: armbian-config from this fork, packaged for
# Pivuan (Devuan, sysvinit). Same file layout as the upstream package
# (debian.conf), but:
#   - the command is /usr/bin/pivuan-config
#   - no dependency on systemd
#   - no Armbian apt source (/etc/apt/sources.list.d/armbian-config.sources)
#
# Usage: tools/pivuan/build-deb.sh [output-dir]      (default: ./output)
# Needs: bash, jq, python3, python3-yaml, dpkg-deb, tar.
# Install the result on the Pi with: apt install ./pivuan-config_*.deb
#
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out="$(mkdir -p "${1:-${src}/output}" && cd "${1:-${src}/output}" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# config-assemble.sh writes lib/ and docs/ into the tree it runs in; use a copy.
mkdir -p "${work}/src"
tar -C "${src}" --exclude=./.git --exclude=./output --exclude=__pycache__ -cf - . | tar -C "${work}/src" -xf -
(cd "${work}/src" && tools/config-assemble.sh -p > "${work}/assemble.log" 2>&1) || {
	cat "${work}/assemble.log" >&2
	exit 1
}

pkg="${work}/pkg"
mkdir -p "${pkg}/DEBIAN" "${pkg}/usr/bin" "${pkg}/usr/lib" "${pkg}/usr/share/armbian-config"
cp -a "${work}/src/lib/." "${pkg}/usr/lib/"
cp -a "${work}/src/share/." "${pkg}/usr/share/"
cp -a "${work}/src/tools/modules/desktops" "${pkg}/usr/share/armbian-config/"
cp -a "${work}/src/tools/modules/system/runner-cleanup" "${pkg}/usr/share/armbian-config/"
install -m 0755 "${work}/src/bin/armbian-config" "${pkg}/usr/bin/pivuan-config"

# Version: date of the last commit plus its hash when built from git, else today.
version="$(date -u +%Y.%m.%d)"
if git -C "${src}" rev-parse --git-dir > /dev/null 2>&1; then
	version="$(git -C "${src}" log -1 --format=%cd --date=format:%Y.%m.%d.%H%M)+g$(git -C "${src}" rev-parse --short HEAD)"
fi

cat > "${pkg}/DEBIAN/control" << EOF
Package: pivuan-config
Version: ${version}
Architecture: all
Maintainer: Pivuan <https://github.com/rations/pivuan>
Section: admin
Priority: optional
Depends: bash, jq, curl, whiptail, sudo, procps, sysvinit-utils, init-system-helpers, lsb-release, iproute2, debconf, libtext-iconv-perl, gpg, xz-utils, pv, python3-yaml, expect-dev, rsync, parted, dosfstools, e2fsprogs, btrfs-progs, f2fs-tools, ntfs-3g
Conflicts: armbian-config
Replaces: armbian-config
Homepage: https://github.com/rations/configng
Description: Pivuan configuration utility
 armbian-config (configng) adapted for Pivuan: Devuan with sysvinit on the
 Raspberry Pi. Run it as pivuan-config.
EOF

find "${pkg}" -type d -exec chmod 0755 {} +
dpkg-deb --root-owner-group --build "${pkg}" "${out}/pivuan-config_${version}_all.deb" > /dev/null
echo "${out}/pivuan-config_${version}_all.deb"
