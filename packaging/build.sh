#!/bin/bash
# 构建发行版二进制包：packaging/build.sh <deb|rpm|arch> <发行版标签> <版本>
# 产物放在 dist/。
set -euo pipefail

kind=$1 label=$2 version=$3
pkg=qq-crfix
root=$(cd "$(dirname "$0")/.." && pwd)
dist=$root/dist
mkdir -p "$dist"
cd "$root"

case "$kind" in
deb)
    arch=$(dpkg --print-architecture)
    stage=$(mktemp -d)
    make clean >/dev/null
    make VERSION="$version"
    make install DESTDIR="$stage" PREFIX=/usr VERSION="$version"
    mkdir -p "$stage/DEBIAN"
    cat > "$stage/DEBIAN/control" <<CTRL
Package: $pkg
Version: $version-1~$label
Architecture: $arch
Maintainer: Remik1r3n <remik1r3n@users.noreply.github.com>
Depends: libc6 (>= 2.34), libglib2.0-0t64 | libglib2.0-0, libx11-6, libwayland-client0
Recommends: linuxqq, xdg-desktop-portal
Conflicts: linuxqq-wayland-fix
Section: net
Priority: optional
Homepage: https://github.com/Remik1r3n/LinuxQQ-CrFix
Description: Linux QQ ChromeOS Fix - run Linux QQ comfortably on Crostini
 Starts QQ with native Wayland and ChromeOS IME (text-input-v1) support,
 and never selects an ANGLE/Vulkan backend (Crostini's virtual GPU makes
 QQ render garbage with Vulkan). Also ships the upstream Wayland fixes
 for screen sharing, clipboard, screenshot and shared-device audio.
 Open "QQ (CrFix)" from the application menu.
CTRL
    dpkg-deb --root-owner-group --build "$stage" "$dist/${pkg}_${version}-1~${label}_${arch}.deb"
    ;;
rpm)
    top=$(mktemp -d)
    mkdir -p "$top"/{SOURCES,SPECS,BUILD,RPMS,SRPMS}
    tar --exclude=./.git --exclude=./dist --transform "s,^\.,$pkg-$version," \
        -czf "$top/SOURCES/$pkg-$version.tar.gz" .
    rpmbuild -bb --define "_topdir $top" --define "_ver $version" \
        packaging/rpm/$pkg.spec
    find "$top/RPMS" -name '*.rpm' ! -name '*-debuginfo-*' ! -name '*-debugsource-*' -exec cp {} "$dist/" \;
    ;;
arch)
    chown -R builder: "$root"
    su builder -c "cd '$root/packaging/arch' && CRFIX_VERSION='$version' makepkg -f -d --noconfirm"
    find packaging/arch -maxdepth 1 -name '*.pkg.tar.zst' ! -name '*-debug-*' -exec cp {} "$dist/" \;
    ;;
*)
    echo "unknown kind: $kind" >&2; exit 1 ;;
esac

ls -l "$dist"
