#!/usr/bin/env bash
set -Eeuo pipefail

readonly UPSTREAM_REPO="vernette/beszel-agent-openwrt"
readonly FEED_BASE="https://blackf1re.github.io/openwrt-repo/"
readonly ARCHES=("aarch64_cortex-a53" "mipsel_24kc")

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

api_headers=()
if [[ -n "${GH_TOKEN:-}" ]]; then
  api_headers=(-H "Authorization: Bearer ${GH_TOKEN}")
fi

release_json="$(curl -fsSL --retry 4 --retry-all-errors "${api_headers[@]}" \
  -H 'Accept: application/vnd.github+json' \
  "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest")" \
  || fail "cannot retrieve latest upstream release"

tag="$(jq -er '.tag_name | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$release_json")" \
  || fail "upstream release tag is not a stable vMAJOR.MINOR.PATCH version"
version="${tag#v}"
expected_filename="beszel-agent-${version}-r1.apk"

if [[ "${FORCE:-false}" != "true" ]]; then
  current_tag="$(curl -fsSL --retry 2 --retry-all-errors "${FEED_BASE}UPSTREAM_VERSION" 2>/dev/null || true)"
  if [[ "$current_tag" == "$tag" ]]; then
    live_ok=true
    for arch in "${ARCHES[@]}"; do
      for path in \
        "releases/25.12/${arch}/packages.adb" \
        "releases/25.12/${arch}/${expected_filename}"; do
        if ! curl -fsSI --retry 2 --retry-all-errors "${FEED_BASE}${path}" >/dev/null; then
          live_ok=false
          break
        fi
      done
      [[ "$live_ok" == true ]] || break
    done
    if [[ "$live_ok" == true ]]; then
      echo "Upstream $tag is already published and both architecture feeds are reachable."
      {
        echo "changed=false"
        echo "version=$tag"
      } >> "$GITHUB_OUTPUT"
      exit 0
    fi
    echo "Published version marker exists, but one or more feed files are unavailable; rebuilding."
  fi
fi

rm -rf dist
mkdir -p dist

for arch in "${ARCHES[@]}"; do
  asset_name="beszel-agent-${version}-r1_${arch}.apk"
  asset="$(jq -ce --arg name "$asset_name" '.assets[] | select(.name == $name)' <<<"$release_json")" \
    || fail "release $tag has no asset $asset_name"

  download_url="$(jq -er '.browser_download_url | select(startswith("https://github.com/vernette/beszel-agent-openwrt/releases/download/"))' <<<"$asset")" \
    || fail "unexpected download URL for $asset_name"
  digest="$(jq -er '.digest | select(test("^sha256:[0-9a-f]{64}$"))' <<<"$asset")" \
    || fail "GitHub did not provide a SHA-256 digest for $asset_name"
  expected_sha="${digest#sha256:}"

  mkdir -p "dist/$arch"
  output="dist/$arch/$expected_filename"
  echo "Downloading $asset_name"
  curl -fL --retry 4 --retry-all-errors "$download_url" -o "$output"
  printf '%s  %s\n' "$expected_sha" "$output" | sha256sum --check --status \
    || fail "SHA-256 mismatch for $asset_name"
  size="$(wc -c < "$output")"
  (( size > 10000 )) || fail "$asset_name is unexpectedly small ($size bytes)"
  echo "Verified $arch: $size bytes, SHA-256 $expected_sha"
done

printf '%s\n' "$tag" > dist/UPSTREAM_VERSION
{
  echo "changed=true"
  echo "version=$tag"
} >> "$GITHUB_OUTPUT"
