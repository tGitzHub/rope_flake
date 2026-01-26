{
  description = "Flake: helenginn/rope";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixgl.url = "github:nix-community/nixGL";
    rope-src = {
      url = "github:helenginn/rope/protons";
      flake = false;
    };
  };

  outputs =
    {
      # comment
      self,
      nixpkgs,
      flake-utils,
      nixgl,
      rope-src,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let

        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) lib;

        buildInputs = with pkgs; [
          boost
          fftwFloat
          glew
          glm
          SDL2
          SDL2_image
          nlohmann_json
          gemmi
          libpng
          libjpeg
          zlib
          openssl
          curl
        ];

        nativeBuildInputs = [
          pkgs.meson
          pkgs.ninja
          pkgs.pkg-config
          pkgs.python3
          pkgs.cmake
        ];

        src = rope-src; # set github src as source directory
      in
      {
        packages = {
          rope_release = pkgs.stdenv.mkDerivation {
            pname = "rope";
            version = "release";
            inherit src;
            inherit nativeBuildInputs;
            inherit buildInputs;

            mesonFlags = [
              "--buildtype=release"
              "-Dwarning_level=0"
            ];

            # minimal metadata
            meta = with lib; {
              description = "RoPE: protein conformational-space analysis tools (helenginn/rope)";
              homepage = "https://github.com/helenginn/rope";
              license = licenses.gpl3;
              platforms = platforms.linux;
            };
          };

          rope_debug = pkgs.stdenv.mkDerivation {
            pname = "rope";
            version = "debug";

            inherit src;
            inherit nativeBuildInputs;
            inherit buildInputs;

            mesonFlags = [
              "--buildtype=debug"
              "-Dwarning_level=0"
            ];

            # minimal metadata
            meta = with lib; {
              description = "RoPE: protein conformational-space analysis tools (helenginn/rope)";
              homepage = "https://github.com/helenginn/rope";
              license = licenses.gpl3;
              platforms = platforms.linux;
            };
          };
        };

        # default package for `nix build .#`
        defaultPackage = self.packages.${system}.rope_release;

        # optional app entry — adjust binary name if needed (inspect meson build for exact install name)

        apps = {
          rope_cli = {
            type = "app";
            program = "${self.packages.${system}.rope_release}/bin/rope";
          };
          rope_gui = {
            type = "app";
            program = "${self.packages.${system}.rope_release}/bin/rope.gui";
          };
          rope_cli_release = {
            type = "app";
            program = "${self.packages.${system}.rope_release}/bin/rope";
          };
          rope_gui_release = {
            type = "app";
            program = "${self.packages.${system}.rope_release}/bin/rope.gui";
          };
          rope_cli_debug = {
            type = "app";
            program = "${self.packages.${system}.rope_debug}/bin/rope";
          };
          rope_gui_debug = {
            type = "app";
            program = "${self.packages.${system}.rope_debug}/bin/rope.gui";
          };
        };
        defaultApp = self.apps.${system}.rope_gui;
        # development shell with headers/tools for iterative development
        devShells = {
          default = pkgs.mkShell {
            buildInputs = lib.concatLists [
              nativeBuildInputs
              buildInputs
            ];

            shellHook = ''
              echo "RoPE dev shell:"
              echo " - Meson, Ninja and pkg-config are available."
              echo " - To configure: meson setup build .. --prefix=$out --buildtype=debug"
              echo " - To build: ninja -C build"
            '';
          };
        };
      }
    );
}
