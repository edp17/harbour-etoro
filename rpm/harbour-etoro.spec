Name:       harbour-etoro
Summary:    eToro client for Sailfish OS
Version:    0.5.0
Release:    1
Group:      Applications/Finance
License:    MIT
URL:        https://github.com/edp17/harbour-etoro
Source0:    %{name}-%{version}.tar.bz2
BuildRequires:  cmake
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Network)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(sailfishapp)
BuildRequires:  pkgconfig(sailfishsecrets)
Requires:       sailfishsilica-qt5

%description
A read-only Sailfish OS client for viewing eToro portfolio, positions, watchlists, live quotes and trade history.

%prep
%autosetup

%build
%cmake \
    -DCMAKE_BUILD_TYPE=Release
%cmake_build

%install
%cmake_install

%files
%license
%doc
/usr/bin/harbour-etoro
/usr/share/applications/harbour-etoro.desktop
/usr/share/icons/hicolor/172x172/apps/harbour-etoro.png
/usr/share/harbour-etoro

%changelog
- Initial build (View only mode)
