# OpenWrt Extra Packages

A community-maintained APK feed for useful third-party packages that are not available in the official OpenWrt repositories, or are maintained and distributed separately from them.

<details>
<summary><strong>Available packages</strong></summary>

| Package | Architecture | Source |
|---|---|---|
| `beszel-agent` | `aarch64_cortex-a53`, `mipsel_24kc` | [vernette/beszel-agent-openwrt](https://github.com/vernette/beszel-agent-openwrt) |

</details>

## Add the feed

Requires **OpenWrt 25.12 or later** (APK package manager).

Run as `root`:

```sh
wget -O /tmp/blackf1re-openwrt-subscribe.sh https://blackf1re.github.io/openwrt-repo/subscribe.sh &&
test -s /tmp/blackf1re-openwrt-subscribe.sh &&
sh /tmp/blackf1re-openwrt-subscribe.sh
```

This installs the feed's public signing key, registers the repository and refreshes the package indexes.

## Install and update packages

Install packages by name, as you would from an official repository:

```sh
apk add <package>
```

For example, to install **Beszel Agent**:

```sh
apk add beszel-agent
```

Update an installed package through the feed:

```sh
apk update
apk upgrade beszel-agent
```

Use the package name rather than installing a local `.apk` file. This keeps the package managed by APK and eligible for normal repository updates.

## Compatibility

This feed uses the OpenWrt APK repository format and is intended for OpenWrt **25.12+**. A package is available only on the architectures listed for it above.
