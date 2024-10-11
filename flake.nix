{
  description = "Nix flake for building the OpenPLC Editor with custom matiec and headless adjustments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = nixpkgs.lib;

      python = pkgs.python39;
      pythonPackages = python.pkgs;

      myPython = python.withPackages (ps: with ps; [
        jinja2
        lxml
        future
        matplotlib
        pyserial
        pypubsub
        Pyro5
        attrdict3
        zeroconf
        (ps.wxPython_4_0.override { wxGTK = pkgs.wxGTK31; })
      ]);

      matiec = pkgs.stdenv.mkDerivation rec {
        pname = "matiec";
        version = "unstable-2024-10-11";

        src = pkgs.fetchFromGitHub {
          owner = "thiagoralves";
          repo = "matiec";
          rev = "<your-matiec-commit-hash>"; # Replace with your commit hash
          sha256 = "<replace-with-actual-sha256>"; # Nix will provide this
        };

        nativeBuildInputs = [ pkgs.autoconf pkgs.automake ];

        buildInputs = [ ];

        buildPhase = ''
          autoreconf -i
          ./configure --prefix=$out
          make
        '';

        installPhase = ''
          make install
        '';
      };

      openplc-editor = pkgs.stdenv.mkDerivation rec {
        pname = "openplc-editor";
        version = "1.0";

        src = pkgs.fetchFromGitHub {
          owner = "thiagoralves";
          repo = "OpenPLC_Editor";
          rev = "master";
          sha256 = "<replace-with-actual-sha256>"; # Replace after initial build
        };

        nativeBuildInputs = [
          pkgs.autoconf
          pkgs.automake
          pkgs.bison
          pkgs.flex
          pkgs.pkg-config
          pkgs.makeWrapper
        ];

        buildInputs = [
          myPython
          pkgs.gcc
          pkgs.libxml2
          pkgs.libxslt
          pkgs.gtk3
          pkgs.wxGTK31
          matiec
        ];

        buildPhase = "";

        installPhase = ''
          mkdir -p $out/bin
          mkdir -p $out/lib/openplc-editor
          mkdir -p $out/share/applications

          cp ${matiec}/bin/iec2c $out/bin/
          cp -r editor/* $out/lib/openplc-editor/

          cat > $out/share/applications/OpenPLC_Editor.desktop <<EOF
    [Desktop Entry]
    Name=OpenPLC Editor
    Categories=Development;
    Exec=$out/bin/openplc-editor
    Icon=$out/lib/openplc-editor/images/brz.png
    Type=Application
    Terminal=false
    EOF

          # Create a wrapper script to run the editor
          makeWrapper ${myPython.interpreter} $out/bin/openplc-editor \
            --add-flags "$out/lib/openplc-editor/Beremiz.py" \
            --set GDK_BACKEND x11 \
            --set PYTHONPATH "$out/lib/openplc-editor:${myPython.sitePackages}" \
            --set DISPLAY ${DISPLAY:-:0}
        '';
      };
    in
    {
      packages.${system} = {
        matiec = matiec;
        openplc-editor = openplc-editor;
      };
    }
}

