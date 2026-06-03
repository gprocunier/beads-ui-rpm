#!/usr/bin/env bash
set -euo pipefail

repo="${UPSTREAM_REPO:-https://github.com/mantoni/beads-ui.git}"
spec="${SPEC:-beads-ui.spec}"
target_version="${1:-}"
packager_name="${PACKAGER_NAME:-Greg Procunier}"
packager_email="${PACKAGER_EMAIL:-gprocunier@users.noreply.github.com}"

if [[ -z "$target_version" ]]; then
    target_version="$(./scripts/latest-version.sh)"
fi
target_version="${target_version#v}"

if [[ ! "$target_version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]; then
    printf 'Unsupported version format: %s\n' "$target_version" >&2
    exit 1
fi

current_version="$(awk '$1 == "Version:" { print $2; exit }' "$spec")"

tmpdir="$(mktemp -d)"
cleanup() {
    rm -rf "$tmpdir"
}
trap cleanup EXIT

git clone --depth 1 --branch "v${target_version}" "$repo" "$tmpdir/beads-ui-${target_version}" >/dev/null 2>&1
actual_version="$(
    sed -n -E 's/^[[:space:]]*"version":[[:space:]]*"([^"]+)".*/\1/p' \
        "$tmpdir/beads-ui-${target_version}/package.json" \
        | head -n 1
)"

if [[ "$actual_version" != "$target_version" ]]; then
    printf 'Tag v%s package.json reports version %s\n' "$target_version" "$actual_version" >&2
    exit 1
fi

if [[ "$current_version" == "$target_version" ]]; then
    printf 'beads-ui.spec is already at beads-ui %s\n' "$target_version"
    exit 0
fi

sed -i -E \
    -e "s/^Version:[[:space:]]+.*/Version:        ${target_version}/" \
    -e "s/^Release:[[:space:]]+.*/Release:        1%{?dist}/" \
    "$spec"

date_str="$(LC_ALL=C date '+%a %b %d %Y')"
author="$packager_name"
if [[ -n "$packager_email" ]]; then
    author="${author} <${packager_email}>"
fi

entry="* ${date_str} ${author} - ${target_version}-1
- Update to upstream v${target_version}
"

first_changelog_entry="$(awk '/^%changelog$/ { getline; print; exit }' "$spec")"
if [[ "$first_changelog_entry" != *" - ${target_version}-1"* ]]; then
    tmp_spec="$(mktemp)"
    awk -v entry="$entry" '
        /^%changelog$/ && !inserted {
            print
            print entry
            inserted = 1
            next
        }
        { print }
    ' "$spec" > "$tmp_spec"
    mv "$tmp_spec" "$spec"
fi

printf 'Updated %s to beads-ui %s\n' "$spec" "$target_version"
