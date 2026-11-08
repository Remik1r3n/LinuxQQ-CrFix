%global srcname qq-crfix

Name:           qq-crfix
Version:        %{_ver}
Release:        1%{?dist}
Summary:        Linux QQ ChromeOS Fix - run Linux QQ comfortably on ChromeOS Crostini
License:        MIT
URL:            https://github.com/Remik1r3n/LinuxQQ-CrFix
Source0:        %{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  pkgconfig(gio-unix-2.0)
BuildRequires:  pkgconfig(libpulse)
BuildRequires:  pkgconfig(libpipewire-0.3)
BuildRequires:  pkgconfig(x11)
BuildRequires:  pkgconfig(wayland-client)
BuildRequires:  wayland-devel
Requires:       glib2
Recommends:     linuxqq
Recommends:     xdg-desktop-portal
Conflicts:      linuxqq-wayland-fix

%description
Starts QQ with native Wayland and ChromeOS IME (text-input-v1) support,
and never selects an ANGLE/Vulkan backend: Crostini's virtual GPU makes
QQ render garbage with Vulkan. Also ships the upstream Wayland fixes for
screen sharing, clipboard, screenshot and shared-device audio.
Open "QQ (CrFix)" from the application menu.

%prep
%autosetup

%build
%make_build PREFIX=%{_prefix} LIBEXECDIR=%{_libdir}/%{srcname} VERSION=%{version} \
    CFLAGS="%{optflags}" LDFLAGS="%{build_ldflags}"

%install
%make_install PREFIX=%{_prefix} LIBEXECDIR=%{_libdir}/%{srcname} VERSION=%{version}

%files
%license %{_datadir}/licenses/%{srcname}/LICENSE
%doc %{_docdir}/%{srcname}/README.md
%doc %{_docdir}/%{srcname}/docs
%{_bindir}/qq-crfix
%{_libdir}/%{srcname}/
%{_datadir}/applications/qq-crfix.desktop

%changelog
* Sun Nov 08 2026 Remik1r3n <remik1r3n@users.noreply.github.com> - %{version}-1
- See https://github.com/Remik1r3n/LinuxQQ-CrFix/releases
