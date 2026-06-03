#!/usr/bin/env bash
set -euo pipefail

spec="beads-ui.spec"
sources_dir=".rpmbuild/SOURCES"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --spec)
            spec="$2"
            shift 2
            ;;
        --sources-dir)
            sources_dir="$2"
            shift 2
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            exit 1
            ;;
    esac
done

version="$(awk '$1 == "Version:" { print $2; exit }' "$spec")"
node_version="$(awk '$1 == "%global" && $2 == "node_version" { print $3; exit }' "$spec")"
upstream_repo="${UPSTREAM_REPO:-https://github.com/mantoni/beads-ui.git}"

if [[ -z "$version" || -z "$node_version" ]]; then
    printf 'Could not read Version or node_version from %s\n' "$spec" >&2
    exit 1
fi

mkdir -p "$sources_dir"

workdir="$(mktemp -d)"
cleanup() {
    if [[ -d "$workdir" ]]; then
        chmod -R u+w "$workdir" 2>/dev/null || true
        rm -rf "$workdir"
    fi
}
trap cleanup EXIT

download() {
    local url="$1"
    local dest="$2"
    local tmp="${dest}.tmp"

    if [[ -s "$dest" ]]; then
        return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$tmp" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$tmp" "$url"
    else
        printf 'Neither curl nor wget is available for downloading %s\n' "$url" >&2
        exit 1
    fi

    mv "$tmp" "$dest"
}

ensure_node() {
    local required_major="${node_version%%.*}"

    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        local detected_major
        detected_major="$(node -p "process.versions.node.split('.')[0]")"
        if [[ "$detected_major" -ge "$required_major" ]]; then
            return 0
        fi
    fi

    local node_arch
    case "$(uname -m)" in
        x86_64)
            node_arch="x64"
            ;;
        aarch64|arm64)
            node_arch="arm64"
            ;;
        *)
            printf 'Unsupported source-build architecture for Node: %s\n' "$(uname -m)" >&2
            exit 1
            ;;
    esac

    local node_base="node-v${node_version}-linux-${node_arch}"
    local node_tarball="${workdir}/${node_base}.tar.xz"
    download "https://nodejs.org/dist/v${node_version}/${node_base}.tar.xz" "$node_tarball"
    tar xJf "$node_tarball" -C "$workdir"
    export PATH="${workdir}/${node_base}/bin:${PATH}"
}

ensure_node

source_tarball="${sources_dir}/beads-ui-${version}-vendor.tar.gz"
srcdir="${workdir}/beads-ui-${version}"

git clone --depth 1 --branch "v${version}" "$upstream_repo" "$srcdir" >/dev/null 2>&1

actual_version="$(
    cd "$srcdir"
    node -p "JSON.parse(require('fs').readFileSync('package.json', 'utf8')).version"
)"
if [[ "$actual_version" != "$version" ]]; then
    printf 'Spec version %s does not match upstream package.json %s\n' "$version" "$actual_version" >&2
    exit 1
fi

(
    cd "$srcdir"
    npm ci --no-audit --no-fund
    npm run build
    rm -rf node_modules
    npm ci --omit=dev --ignore-scripts --no-audit --no-fund
    rm -rf node_modules/.cache
    find node_modules -depth -type d -empty -delete
    test -s app/main.bundle.js
    node bin/bdui.js --version | grep -qx "$version"
)

rm -rf "$srcdir/.git"

epoch="${SOURCE_DATE_EPOCH:-$(date -u +%s)}"
rm -f "$source_tarball"
tar --sort=name \
    --mtime="@${epoch}" \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -czf "$source_tarball" \
    -C "$workdir" "beads-ui-${version}"

sha256sum "$source_tarball"
