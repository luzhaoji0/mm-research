{
  description = "mm-research の Python・Rust 開発環境";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, rust-overlay, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
      packagesFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };
    in
    {
      formatter = forEachSystem (system: (packagesFor system).nixfmt);

      devShells = forEachSystem (
        system:
        let
          pkgs = packagesFor system;
          rust = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          runtimeLibraries = [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
            pkgs.openssl
          ];
          mkDevShell =
            cuda:
            assert builtins.elem "maturin==${pkgs.maturin.version}"
              (builtins.fromTOML (builtins.readFile ./python/pyproject.toml)).build-system.requires;
            pkgs.mkShell {
              packages = [
                rust
                pkgs.python313
                pkgs.uv
                pkgs.maturin
                pkgs.ruff
                pkgs.pyrefly
                pkgs.prek
                pkgs.gnumake
                pkgs.git
                pkgs.pkg-config
                pkgs.taplo
                pkgs.nixfmt
                pkgs.actionlint
                pkgs.gitleaks
                pkgs.cargo-deny
                pkgs.typos
                pkgs.yamlfmt
                pkgs.yamllint
                pkgs.python313Packages.pre-commit-hooks
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.patchelf ];

              UV_PYTHON = "${pkgs.python313}/bin/python3";
              UV_PYTHON_DOWNLOADS = "never";
              PYTHONNOUSERSITE = "1";
              MM_ML_BACKEND = if cuda then "cuda" else "none";

              shellHook = ''
                unset PYTHONPATH
              ''
              + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
                export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibraries}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              ''
              + pkgs.lib.optionalString cuda ''
                export LD_LIBRARY_PATH="''${NVIDIA_DRIVER_LIBRARY_PATH:-/run/opengl-driver/lib}:$LD_LIBRARY_PATH"
              '';
            };
        in
        {
          default = mkDevShell false;
        }
        // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
          cuda = mkDevShell true;
        }
      );
    };
}
