{
  description = "Goo: an FP-friendly Elixir fork.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      erlang = pkgs.erlang_26;

      # Specify dependencies
      buildInputs = [
        erlang
        pkgs.gnumake
        pkgs.glibcLocalesUtf8
      ];

      nativeBuildInputs = [
        pkgs.makeWrapper
      ];

    in {
      # Here we implement Nix flake API
      # https://nixos.wiki/wiki/Flakes#Output_schema

      # devShell is used by nix develop and direnv with `use flake`
      # defaultPackage is used by nix build and nix shell

      # By adding defaultPackage, we can use `nix shell github:doma-engineering/goo`
      # to get a shell with `elixir`, `mix` and `iex` in PATH.

      # And also we can use `goo` as a dependency in another flake like so:

      # ```
      # inputs = { goo.url = "github:doma-engineering/goo"; nixpkgs.url = "github:NixOS/nixpkgs"; };
      # outputs = { self, nixpkgs, goo }: {
      #   buildInputs = [ goo ]   ;
      #   # ...
      # };
      # ```

      # Enjoy!
      devShell.x86_64-linux = pkgs.mkShell {
        nativeBuildInputs = nativeBuildInputs;
        buildInputs = buildInputs ++ [ pkgs.hub ];
      };

      defaultPackage.x86_64-linux = pkgs.stdenv.mkDerivation {
        name = "goo";
        src = ./.;

        # Poggers: https://github.com/bclaud/orca/blob/a9243aa80a34c815886a1d595d1fb050905261b3/shell.nix
        LOCALE_ARCHIVE = if pkgs.stdenv.isLinux then "${pkgs.glibcLocalesUtf8}/lib/locale/locale-archive" else "";
        LANG = "en_US.UTF-8";
        LC_TYPE = "en_US.UTF-8";

        preBuild = ''
            patchShebangs lib/elixir/scripts/generate_app.escript || true
            substituteInPlace Makefile \
              --replace "/usr/local" $out
        '';

        postFixup = ''
            # Elixir binaries are shell scripts which run erl. Add some stuff
            # to PATH so the scripts can run without problems.
            for f in $out/bin/*; do
             b=$(basename $f)
              if [ "$b" = mix ]; then continue; fi
              wrapProgram $f \
                --prefix PATH ":" "${pkgs.lib.makeBinPath [ erlang pkgs.coreutils pkgs.curl pkgs.bash ]}"
            done
            substituteInPlace $out/bin/mix \
                  --replace "/usr/bin/env elixir" "${pkgs.coreutils}/bin/env elixir"
        '';

        buildInputs = buildInputs;
        nativeBuildInputs = nativeBuildInputs;
      };
    };
}

