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
          ];

          shellHook = ''
            echo "✦ Reasonix dev environment ✦"
            echo "  Go:    $(go version)"
            echo "  Nix:   $(nix --version 2>/dev/null || echo '?')"
            echo "  CGO:   enabled"
            echo ""
            echo "CLI build:      make build           → bin/reasonix"
            echo "Desktop build:  cd desktop && wails build  → desktop/build/"
            echo "Test:           go test ./..."
            echo "Lint:           golangci-lint run"
            echo "Vet:            go vet ./..."
            echo "Format:         gofmt -w ."
          '';
        };
      });
}
