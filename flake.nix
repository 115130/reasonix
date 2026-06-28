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

            # Utility
            git
            nodejs                    # For npm package building
          ];

          shellHook = ''
            echo "✦ Reasonix dev environment ✦"
            echo "  Go:    $(go version)"
            echo "  Nix:   $(nix --version 2>/dev/null || echo '?')"
            echo ""
            echo "Build:  make build     → bin/reasonix"
            echo "Test:   go test ./..."
            echo "Lint:   golangci-lint run"
            echo "Vet:    go vet ./..."
            echo "Format: gofmt -w ."
          '';
        };
      });
}
