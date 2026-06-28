#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# run-desktop.sh  —  Run the pre-built reasonix-desktop with proper GSettings
#                     schema resolution for NixOS and other Linux distros.
#
# On NixOS this wrapper is usually unnecessary inside `nix develop` (whose
# shellHook already sets XDG_DATA_DIRS), but for standalone runs or distro
# packages we auto-discover GSettings schemas here.
#
# Usage:
#   ./desktop/run-desktop.sh                          # runs desktop/build/bin/reasonix-desktop
#   ./desktop/run-desktop.sh /path/to/reasonix-desktop # runs a custom binary
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BINARY="${1:-"$SCRIPT_DIR/build/bin/reasonix-desktop"}"
if [ ! -x "$BINARY" ]; then
  echo "❌ Binary not found or not executable: $BINARY"
  echo "   Build it first:  cd desktop && wails build"
  exit 1
fi

# ---- GSettings schema discovery -------------------------------------------
# GLib's GSettings looks up schemas in two ways:
#   1. $GSETTINGS_SCHEMA_DIR  — single directory containing gschemas.compiled
#   2. Each $XDG_DATA_DIRS/glib-2.0/schemas/  —  colon-separated fallback
#
# On NixOS, schema packages install their schemas under
#   share/gsettings-schemas/<pkg-name>/glib-2.0/schemas/
# and the build system sets $GSETTINGS_SCHEMAS_PATH to a colon-separated list
# of the parent directories. We piggyback on that variable when available and
# also do a manual search as a last resort.

SCHEMA_DIRS=()

# 1a. Honour $GSETTINGS_SCHEMAS_PATH (set by nixpkgs setup-hooks).
if [ -n "${GSETTINGS_SCHEMAS_PATH:-}" ]; then
  IFS=':' read -ra ENTRIES <<< "$GSETTINGS_SCHEMAS_PATH"
  for entry in "${ENTRIES[@]}"; do
    candidate="$entry/glib-2.0/schemas"
    if [ -f "$candidate/gschemas.compiled" ]; then
      SCHEMA_DIRS+=("$entry")
    fi
  done
fi

# 1b. Fallback: scan a few well-known Nix store prefixes.
if [ ${#SCHEMA_DIRS[@]} -eq 0 ]; then
  for prefix in /nix/store/*-gsettings-desktop-schemas-*/share/gsettings-schemas/gsettings-desktop-schemas-* \
                /nix/store/*-gtk+3-*/share/gsettings-schemas/gtk+3-* \
                /nix/store/*-gtk4-*/share/gsettings-schemas/gtk4-*; do
    [ -d "$prefix" ] || continue
    candidate="$prefix/glib-2.0/schemas"
    if [ -f "$candidate/gschemas.compiled" ]; then
      SCHEMA_DIRS+=("$prefix")
    fi
  done
fi

# 2. Prepend found schema dirs to XDG_DATA_DIRS so GLib finds them.
if [ ${#SCHEMA_DIRS[@]} -gt 0 ]; then
  joined="$(IFS=:; echo "${SCHEMA_DIRS[*]}")"
  export XDG_DATA_DIRS="$joined${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
  echo "🔧 GSettings schemas added to XDG_DATA_DIRS (${#SCHEMA_DIRS[@]} dirs)"
fi

# ---- GStreamer ------------------------------------------------------------
# Wails / WebKitGTK needs the appsink element for media playback. On NixOS
# the GStreamer setup-hook sets GST_PLUGIN_SYSTEM_PATH_1_0 from buildInputs;
# map it to the unversioned variable so the runtime finds the plugins.
if [ -n "${GST_PLUGIN_SYSTEM_PATH_1_0:-}" ]; then
  export GST_PLUGIN_SYSTEM_PATH="$GST_PLUGIN_SYSTEM_PATH_1_0"
elif [ -z "${GST_PLUGIN_SYSTEM_PATH:-}" ]; then
  # Manual fallback — scan the Nix store for GStreamer plugin dirs.
  GST_DIRS=()
  for d in /nix/store/*-gst-plugins-base-*/lib/gstreamer-1.0 \
           /nix/store/*-gst-plugins-good-*/lib/gstreamer-1.0; do
    [ -d "$d" ] && GST_DIRS+=("$d")
  done
  if [ ${#GST_DIRS[@]} -gt 0 ]; then
    joined="$(IFS=:; echo "${GST_DIRS[*]}")"
    export GST_PLUGIN_SYSTEM_PATH="$joined"
    echo "🔧 GStreamer plugins: ${#GST_DIRS[@]} dirs"
  fi
fi

# ---- Run ------------------------------------------------------------------
echo "🚀 Starting: $(basename "$BINARY")"
echo "   Binary:  $BINARY"
echo "   Workdir: $(pwd)"
exec "$BINARY"
