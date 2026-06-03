#!/usr/bin/env bash
set -euo pipefail

package="${NPM_PACKAGE:-beads-ui}"
repo="${UPSTREAM_REPO:-https://github.com/mantoni/beads-ui.git}"

if command -v npm >/dev/null 2>&1; then
    if version="$(npm view "$package" version 2>/dev/null)"; then
        printf '%s\n' "$version"
        exit 0
    fi
fi

git ls-remote --tags "$repo" 'refs/tags/v*' \
    | sed -E 's#^.*refs/tags/v([0-9]+[.][0-9]+[.][0-9]+)$#\1#' \
    | sed '/[^0-9.]/d' \
    | sort -V \
    | tail -n 1
