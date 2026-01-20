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
      self,
      nixpkgs,
      flake-utils,
      nixgl,
      rope-src,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        filteredSrc = builtins.filterSource (
          path: type:
          let
            bn = builtins.baseNameOf path;
          in
          # keep directories, but filter files by basename patterns
          if type == "directory" then
            true
          else
            (
              # blacklist common noisy items; return true to KEEP the file, false to DROP it
              (builtins.match "^(flake.nix|result|build|\\.git|node_modules|\\.direnv|\\.DS_Store)$" bn) == null
              && (builtins.match ".*(~$|^\\.#|\\.swp$)$" bn) == null
            )
        ) ./.;

        pkgs = import nixpkgs { inherit system; };
        inherit (pkgs) lib;

        # helper: check & fetch attribute from pkgs if present, otherwise null
        hasAttr = name: builtins.hasAttr name pkgs;
        getAttr = name: if hasAttr name then builtins.getAttr name pkgs else null;

        # assemble dependency list by name (robust to slight name differences across pkgs commits)
        depsByName = nameList: lib.filter (x: x != null) (map getAttr nameList);

        # canonical candidate names for commonly required libs.
        buildInputs = depsByName [
          "boost"
          "fftwFloat"
          "glew"
          "glm"
          "SDL2"
          "SDL2_image"
          "nlohmann_json"
          "gemmi"
          "libpng"
          "libjpeg"
          "zlib"
          "openssl"
          "curl"
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

            # configure/build/install phases using Meson + Ninja
            configurePhase = ''
              echo "Configuring with Meson..."
              # meson setup <builddir> <sourcedir> --prefix=$out <flags>
              meson setup build . --prefix=$out --buildtype=release
            '';

            buildPhase = ''
              echo "Building with ninja..."
              ninja -C build
            '';

            installPhase = ''
              echo "Installing..."
              ninja -C build install
            '';

            # ensure no user-specific metadata is recorded
            dontPatchELF = true;

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

            # configure/build/install phases using Meson + Ninja
            configurePhase = ''
              echo "Configuring with Meson..."
              # meson setup <builddir> <sourcedir> --prefix=$out <flags>
              meson setup build . --prefix=$out --buildtype=debug
            '';

            buildPhase = ''
              echo "Building with ninja..."
              ninja -C build
            '';

            installPhase = ''
              echo "Installing..."
              ninja -C build install
            '';

            # ensure no user-specific metadata is recorded
            dontPatchELF = true;

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
