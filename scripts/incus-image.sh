#!/usr/bin/env bash
# Builds the Incus base image for Terraform's external data source, and
# prints the metadata tarball's and root filesystem's paths as JSON.
set -euo pipefail

build=..#nixosConfigurations.incus-base.config.system.build
metadata=$(nix build --no-link --print-out-paths "$build.metadata")
rootfs=$(nix build --no-link --print-out-paths "$build.squashfs")
printf '{"metadata":"%s","rootfs":"%s"}\n' "$metadata"/tarball/*.tar.xz "$rootfs"/*.squashfs
