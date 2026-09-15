Name:       harbour-etoro
Summary:    eToro trading client for Sailfish OS
Version:    0.7.1
Release:    1
Group:      Applications/Finance
License:    GPL-3.0-or-later
URL:        https://github.com/edp17/harbour-etoro
Source0:    %{name}-%{version}.tar.bz2
BuildRequires:  cmake
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Network)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  qt5-qttools-linguist
BuildRequires:  pkgconfig(sailfishapp)
BuildRequires:  pkgconfig(sailfishsecrets)
Requires:       sailfishsilica-qt5

%description
A Sailfish OS client for viewing eToro portfolios, positions, watchlists, live quotes and trade history, with optional trading support.

%prep
%autosetup

%build
%cmake \
    -DCMAKE_BUILD_TYPE=Release
%cmake_build

%install
%cmake_install

%files
/usr/bin/harbour-etoro
/usr/share/applications/harbour-etoro.desktop
/usr/share/icons/hicolor/172x172/apps/harbour-etoro.png
/usr/share/harbour-etoro

%changelog
* Sat Sep 12 2026 edp17 - 0.7.1-1
- Verify market restrictions consistently on asset detail and order pages
- Fix and persist Portfolio sorting direction and numeric sort modes

* Thu Sep 10 2026 edp17 - 0.7.0-1
- Add order-status tracking and historical price charts
- Separate success notifications and refactor shared controllers and QML helpers

* Wed Sep 09 2026 edp17 - 0.6.0-2
- Trading-enabled beta
