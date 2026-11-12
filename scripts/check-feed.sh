#!/usr/bin/env bash
set -Eeuo pipefail

dist_dir="${1:-dist}"
out_dir="${2:-out}"
tag="$(cat "$dist_dir/UPSTREAM_VERSION")"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "Invalid upstream version marker: $tag" >&2
  exit 1
}
version="${tag#v}"
expected="beszel-agent-${version}-r1.apk"

case "${OWFEED_CHECK_PINNED_KEY:-true}" in
  true)
    cmp -s keys/blackf1re-openwrt.pem "$out_dir/blackf1re-openwrt.pem" || {
      echo "Published public key does not match keys/blackf1re-openwrt.pem; check OWFEED_SIGN_KEY." >&2
      exit 1
    }
    ;;
  false)
    echo "Skipping pinned-key comparison (temporary test key)."
    ;;
  *)
    echo "OWFEED_CHECK_PINNED_KEY must be true or false." >&2
    exit 1
    ;;
esac

for arch in aarch64_cortex-a53 mipsel_24kc; do
  source_file="$dist_dir/$arch/$expected"
  package_dir="$out_dir/releases/25.12/$arch"
  index_file="$package_dir/packages.adb"

  [[ -s "$source_file" ]] || {
    echo "Missing downloaded package: $source_file" >&2
    exit 1
  }
  [[ -s "$index_file" ]] || {
    echo "Missing APK repository index: $index_file" >&2
    exit 1
  }

  mapfile -t packages < <(find "$package_dir" -maxdepth 1 -type f -name '*.apk' -printf '%f\n' | sort)
  [[ "${#packages[@]}" -eq 1 && "${packages[0]}" == "$expected" ]] || {
    printf 'Unexpected packages for %s: %s\n' "$arch" "${packages[*]:-none}" >&2
    exit 1
  }
  echo "OK: $arch -> $expected"
done

echo "Feed layout and signing key checks passed for $tag."
