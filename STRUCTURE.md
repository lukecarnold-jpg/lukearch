# Lukearch Project Structure

This page is a visual map of the repository: what each part is, how the
parts connect, and how a change moves from source to a tested ISO. It
describes the current tree. [`README.md`](README.md) covers build and usage
steps, and [`DEV_HIST.md`](DEV_HIST.md) records changes over time.

**Keeping this page current:**

- The file tree below is generated from tracked files by
  `scripts/update-structure.sh`. Run it after adding, moving, or removing
  files. CI fails if the tree is out of date.
- The diagrams and the key-directories table are edited by hand. Update them
  when a component, flow, or responsibility changes.

## Overview

Two archiso profiles live in this repository. One build script selects a
profile by architecture, and test scripts boot the result.

```mermaid
flowchart LR
    subgraph Profiles
        P64["profile/<br/>x86_64 archiso profile"]
        PA["profile-aarch64/<br/>ARM64 archiso profile"]
    end

    BUILD["scripts/build-iso.sh<br/>ARCH selects profile"]
    MKA["mkarchiso<br/>(archiso)"]
    ISO64["lukearch-*.iso<br/>x86_64"]
    ISOA["lukearch-aarch64*.iso<br/>ARM64"]

    QEMU["scripts/test-iso.sh<br/>QEMU x86_64"]
    VBOX["scripts/test-virtualbox.sh<br/>VirtualBox ARM64"]

    CI["CI: validate-project.yml<br/>syntax, required files,<br/>config checks, doc rule"]

    P64 --> BUILD
    PA --> BUILD
    BUILD --> MKA
    MKA --> ISO64
    MKA --> ISOA
    ISO64 --> QEMU
    ISOA --> VBOX

    P64 -. checked by .-> CI
    PA -. checked by .-> CI
    BUILD -. checked by .-> CI
```

## Repository tree

<!-- tree:start -->
```text
.github/
  workflows/
    validate-project.yml
.gitignore
DEV_HIST.md
LICENSE
README.md
STRUCTURE.md
docs/
  arm-support.md
profile-aarch64/
  airootfs/
    etc/
      hostname
      locale.conf
      locale.gen
      mkinitcpio.conf.d/
        archiso.conf
      nftables.conf
      sddm.conf.d/
        autologin.conf
      sudoers.d/
        lukearch
      systemd/
        zram-generator.conf
      udev/
        rules.d/
          71-lukearch-framebuffer-seat.rules
    root/
      README
      customize_airootfs.sh
    usr/
      local/
        sbin/
          lukearch-set-admin-password
  efiboot/
    loader/
      entries/
        lukearch-aarch64.conf
      loader.conf
  packages.aarch64
  pacman.conf
  profiledef.sh
profile/
  airootfs/
    etc/
      hostname
      locale.conf
      locale.gen
      mkinitcpio.conf.d/
        archiso.conf
      motd
      nftables.conf
      os-release
      sddm.conf.d/
        autologin.conf
      sudoers.d/
        lukearch
      systemd/
        system/
          multi-user.target.wants/
            NetworkManager.service
        zram-generator.conf
    root/
      README
      customize_airootfs.sh
    usr/
      local/
        sbin/
          lukearch-set-admin-password
  efiboot/
    loader/
      entries/
        lukearch-x86_64-copytoram.conf
        lukearch-x86_64.conf
      loader.conf
  packages.x86_64
  pacman.conf
  profiledef.sh
  syslinux/
    syslinux.cfg
scripts/
  build-iso.sh
  test-iso.sh
  test-virtualbox.sh
  update-structure.sh
```
<!-- tree:end -->

## Key directories

| Path | Purpose |
| --- | --- |
| `profile/` | x86_64 archiso profile for Intel and AMD PCs |
| `profile/airootfs/` | Files copied into the x86_64 live root filesystem |
| `profile/efiboot/` and `profile/syslinux/` | UEFI (systemd-boot) and BIOS (syslinux) boot configuration |
| `profile-aarch64/` | ARM64 archiso profile for VirtualBox on Apple silicon |
| `profile-aarch64/airootfs/` | Files copied into the ARM64 live root filesystem |
| `scripts/` | Build, QEMU test, VirtualBox test, and structure generator scripts |
| `docs/` | Supporting documentation (ARM and Apple silicon status) |
| `.github/workflows/` | CI validation |

## Build and test flow

```mermaid
flowchart TD
    A["Edit profile or script"] --> B{"Target?"}
    B -- "x86_64" --> C["ARCH=x86_64<br/>scripts/build-iso.sh"]
    B -- "ARM64" --> D["ARCH=aarch64<br/>on an ARM64 Linux host"]
    C --> E["mkarchiso builds ISO<br/>into out/"]
    D --> E
    E --> F{"Boot test"}
    F -- "x86_64" --> G["scripts/test-iso.sh<br/>QEMU, 4096 MB default"]
    F -- "ARM64" --> H["scripts/test-virtualbox.sh<br/>Apple silicon Mac"]
    G --> I["Record result in DEV_HIST.md"]
    H --> I
    A --> J["Push or open a PR"]
    J --> K["CI checks"]
    K --> L{"README.md and<br/>DEV_HIST.md changed?"}
    L -- "no" --> M["CI fails"]
    L -- "yes" --> N["Checks pass"]
```

## Live image authentication model

Members of the `wheel` group, including the `lukearch` desktop account, use
sudo. Sudo asks for a separate administrator (root) password. The login
password does not authorize sudo.

```mermaid
flowchart TD
    LOGIN["lukearch login password<br/>set with sudo passwd lukearch"]
    ADMIN["Administrator (root) password<br/>set once by lukearch-set-admin-password"]
    SUDO["sudo for wheel members<br/>Defaults:%wheel rootpw"]
    SETUP["lukearch-set-admin-password<br/>refuses once root has a password"]

    LOGIN -- "asked once, by the setup command" --> SETUP
    SETUP -- "sets" --> ADMIN
    ADMIN -- "required by" --> SUDO
    LOGIN -. "does not authorize sudo" .-> SUDO
```

## Where things are documented

| Topic | Where to look |
| --- | --- |
| Build and test commands, security notes | [`README.md`](README.md) |
| ARM and Apple silicon status | [`docs/arm-support.md`](docs/arm-support.md) |
| Change history and validation notes | [`DEV_HIST.md`](DEV_HIST.md) |
| Automated checks | [`.github/workflows/validate-project.yml`](.github/workflows/validate-project.yml) |
