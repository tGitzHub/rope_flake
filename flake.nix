{
  description = "Flake: helenginn/rope";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };


  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
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
        lib = pkgs.lib;

        # helper: check & fetch attribute from pkgs if present, otherwise null
        hasAttr = name: builtins.hasAttr name pkgs;
        getAttr = name: if hasAttr name then builtins.getAttr name pkgs else null;

        # assemble dependency list by name (robust to slight name differences across pkgs commits)
        depsByName = nameList: lib.filter (x: x != null) (map getAttr nameList);

        # canonical candidate names for commonly required libs.
        coreDeps = depsByName [
          "cmake"
          "boost" # Boost libraries
          "fftw" # FFTW
          "fftwFloat"
          "glew" # GLEW
          "glm" # GLM
          "SDL2" # SDL2
          "SDL2_image" # SDL2_image
          "nlohmann_json" # JSON for Modern C++
          "gemmi" # gemmi library (if in nixpkgs)
          "libpng" # PNG support
          "libjpeg" # JPEG support (may be jpeg or libjpeg)
          "zlib" # compression
          "openssl" # TLS/crypto if required
          "curlpp"
          "curl"
        ];

        # final buildInputs: combine core + optional wrapper
        buildInputsFull = lib.concatLists [
          coreDeps
        ];

        nativeBuildInputs = [
          pkgs.meson
          pkgs.ninja
          pkgs.pkg-config
          pkgs.python3
        ];

        src = filteredSrc; # repo root; works locally and when fetched from GitHub
      in
      {
        packages = {
          rope = pkgs.stdenv.mkDerivation {
            pname = "rope";
            version = "release";

            src = src;

            nativeBuildInputs = nativeBuildInputs;
            buildInputs = buildInputsFull;

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
        };

        # default package for `nix build .#`
        defaultPackage = self.packages.${system}.rope;

        # optional app entry — adjust binary name if needed (inspect meson build for exact install name)

        apps = {
          rope_cli = {
            type = "app";
            program = "${self.packages.${system}.rope}/bin/rope";
          };
          rope_gui = {
            type = "app";
            program = "${self.packages.${system}.rope}/bin/rope.gui";
          };
        };
        defaultApp = self.apps.${system}.rope_gui;
        # development shell with headers/tools for iterative development
        devShells = {
          default = pkgs.mkShell {
            buildInputs = lib.concatLists [
              nativeBuildInputs
              buildInputsFull
            ];

            shellHook = ''
              echo "RoPE dev shell:"
              echo " - Meson, Ninja and pkg-config are available."
              echo " - To configure: meson setup build .. --prefix=$out --buildtype=release"
              echo " - To build: ninja -C build"
            '';
          };
        };
      }
    );
}
