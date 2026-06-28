{
  description = "DeepSeek-Reasonix — AI coding agent development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "reasonix-dev";

          nativeBuildInputs = with pkgs; [
            # Go toolchain
            go_1_26

            # Go development tools
            gopls                     # LSP server
            golangci-lint             # Linter (matches CI)
            go-tools                  # Staticcheck, etc.
            gotools                   # go vet, go fix, etc.
            delve                     # Debugger

            # Build/packaging tools
            goreleaser                # Release automation

            # Desktop build prerequisites (Wails + CGO)
            pkg-config                # Library path resolution
            gcc                       # C compiler for CGO/WebKitGTK

            # Utility
            git
            nodejs                    # For npm package building + desktop frontend
          ];

          # Libraries needed for CGO/WebKitGTK (Wails desktop)
          buildInputs = with pkgs; [
            gtk3                      # GTK3 toolkit
            webkitgtk_4_1             # WebKitGTK (webview engine)
            glib                      # GLib types (gobject-introspection)
            libsoup_3                 # HTTP client library (WebKit dep)
            cairo                     # 2D graphics library
            pango                     # Text layout engine
            gdk-pixbuf                # Image loading
            libadwaita                # GNOME styling (optional but system-theme)
            gsettings-desktop-schemas # GSettings schemas (needed by file dialogs)
            gst_all_1.gstreamer       # GStreamer core
            gst_all_1.gst-plugins-base # GStreamer base plugins (provides appsink)
            gst_all_1.gst-plugins-good # GStreamer good-quality plugins
          ];

          shellHook = ''
            echo "✦ Reasonix dev environment ✦"
            echo "  Go:    $(go version)"
            echo "  Nix:   $(nix --version 2>/dev/null || echo '?')"
            echo "  CGO:   enabled"

            # ---- GSettings schema path ----
            # Nixpkgs's setup-hooks already set GSETTINGS_SCHEMAS_PATH from our
            # buildInputs. GLib's GSettings looks up schemas via:
            #   1. $GSETTINGS_SCHEMA_DIR (single dir) or
            #   2. each $XDG_DATA_DIRS/glib-2.0/schemas/ (colon-separated)
            # We add the schema base dirs to XDG_DATA_DIRS so GLib finds them
            # without needing a merged GSETTINGS_SCHEMA_DIR.
            if [ -n "''${GSETTINGS_SCHEMAS_PATH:-}" ]; then
              export XDG_DATA_DIRS="''${GSETTINGS_SCHEMAS_PATH}:''${XDG_DATA_DIRS:-}"
              echo "  GSettings: $(echo "$GSETTINGS_SCHEMAS_PATH" | tr ':' '\n' | wc -l) schema packages"
            fi

            # ---- GStreamer ----
            # Wails/WebKitGTK needs the appsink element. Nixpkgs's GStreamer
            # setup-hook sets GST_PLUGIN_SYSTEM_PATH_1_0 from buildInputs;
            # map it to the unversioned variable for runtime compatibility.
            if [ -n "''${GST_PLUGIN_SYSTEM_PATH_1_0:-}" ]; then
              export GST_PLUGIN_SYSTEM_PATH="''${GST_PLUGIN_SYSTEM_PATH_1_0}"
            fi
            if ! command -v gst-inspect-1.0 &>/dev/null || \
               ! gst-inspect-1.0 appsink &>/dev/null 2>&1; then
              echo "  ⚠ appsink not found — GStreamer video playback may not work"
            fi

            echo ""
            echo "CLI build:      make build           → bin/reasonix"
            echo "Desktop build:  cd desktop && wails build  → desktop/build/"
            echo "Run desktop:    desktop/run-desktop.sh"
            echo "Test:           go test ./..."
            echo "Lint:           golangci-lint run"
            echo "Vet:            go vet ./..."
            echo "Format:         gofmt -w ."
          '';
        };
      });
}
