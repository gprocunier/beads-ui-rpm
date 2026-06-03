# Beads UI RPM Packaging

This repository builds source RPMs for the Beads UI COPR package:

https://copr.fedorainfracloud.org/coprs/greg-at-redhat/beads-ui/

Upstream source:

https://github.com/mantoni/beads-ui

## Build Locally

```bash
make local-rpm
```

The local binary RPM is written under `.rpmbuild/RPMS/noarch/`.

## Build An SRPM

```bash
make srpm
```

The SRPM is written under `.rpmbuild/SRPMS/`.

## Update To The Latest Upstream Release

```bash
./scripts/update-version.sh
make srpm
```

To pin a specific upstream tag:

```bash
./scripts/update-version.sh 0.12.0
make srpm
```

The source-prep step downloads the upstream release tag, installs the package
with npm, builds the browser bundle, reinstalls production-only dependencies,
and archives the resulting Node tree into the SRPM. The COPR binary RPM build
therefore does not need network access.

## COPR SCM Setup

Configure the COPR package to build from this repository:

```bash
copr edit-package-scm greg-at-redhat/beads-ui \
  --name beads-ui \
  --clone-url https://github.com/gprocunier/beads-ui-rpm.git \
  --commit main \
  --method make_srpm \
  --spec beads-ui.spec \
  --webhook-rebuild on
```

Trigger a build from the configured package source:

```bash
copr build-package greg-at-redhat/beads-ui --name beads-ui
```

The GitHub workflow checks for newer upstream tags and commits a spec bump when
one appears. With COPR webhook rebuild enabled, that push can trigger a new COPR
build automatically.
