%global node_version 22.22.2
%global appdir %{_datadir}/%{name}
%global debug_package %{nil}

Name:           beads-ui
Version:        0.12.0
Release:        1%{?dist}
Summary:        Local web UI for Beads issue tracking
License:        MIT
URL:            https://github.com/mantoni/beads-ui
Source0:        %{name}-%{version}-vendor.tar.gz

BuildArch:      noarch

BuildRequires:  /usr/bin/node
BuildRequires:  nodejs(engine) >= 22

Requires:       /usr/bin/node
Requires:       nodejs(engine) >= 22
Recommends:     beads
Provides:       npm(%{name}) = %{version}

%description
Beads UI is a local web interface for the Beads bd CLI. It provides live
issue views, epics, board columns, search, filtering, inline editing, and
multi-workspace switching for local Beads databases.

%prep
%setup -q

%build
test -s app/main.bundle.js
test -d node_modules

%install
install -d %{buildroot}%{appdir}
cp -pr app bin server node_modules package.json %{buildroot}%{appdir}/
find %{buildroot}%{appdir} -type f -name '*.test.js' -delete

install -d %{buildroot}%{_bindir}
cat > %{buildroot}%{_bindir}/bdui <<'EOF'
#!/bin/sh
exec /usr/bin/node /usr/share/beads-ui/bin/bdui.js "$@"
EOF
chmod 0755 %{buildroot}%{_bindir}/bdui

%check
/usr/bin/node %{buildroot}%{appdir}/bin/bdui.js --version | grep -qx '%{version}'

%files
%license LICENSE
%doc README.md CHANGES.md docs/
%{_bindir}/bdui
%dir %{appdir}
%{appdir}/app
%{appdir}/bin
%{appdir}/server
%{appdir}/node_modules
%{appdir}/package.json

%changelog
* Wed Jun 03 2026 Greg Procunier <gprocunier@users.noreply.github.com> - 0.12.0-1
- Initial RPM package for upstream v0.12.0
