{
  description = "V-RISC-V at FSiC 2023";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs = { self, nixpkgs, flake-utils, pre-commit-hooks }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        commited = self ? rev;
        texvars = name:
          if commited then
            " \\def\\reproduce{Reproduce using:\\newline nix build github:gabriel-doriath-dohler/V-RISC-V-FSiC-2023/${
               toString self.rev
             }\\#${name}}"
          else
            " \\def\\reproduce{Not reproducible. Please commit (and push) your changes. Last commit: \\today.}";

        defaultTex = pkgs.texlive.combine {
          inherit (pkgs.texlive)
            scheme-medium latexmk geometry hyperref fontspec minted latex-bin
            mdwtools amsmath fvextra upquote catchfile xstring framed
            gnu-freefont qrcode;
        };

        latexmkWrapped = pkgs.symlinkJoin {
          name = "latexmk";
          paths = [ defaultTex ];
          buildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/latexmk  \
              --set OSFONTDIR ${pkgs.fira-code}/share/fonts \
              --set SOURCE_DATE_EPOCH ${toString self.lastModified} \
              --add-flags '\
                -interaction=nonstopmode -pdfxe -lualatex \
                -pretex="\pdfvariable suppressoptionalinfo 512\relax${
                  texvars "slides"
                }" \
                --shell-escape \
                -usepretex \
                -file-line-error \
              ' \
          '';
        };

        buildDeps = with pkgs; [
          coreutils # Choose the GNU `mktemp` over the BSD one.
          fira-code
          fira-code-symbols
          python310Packages.pygments
          texlab
          which
        ];

        buildLaTeX = { name, tex ? defaultTex }: {
          "${name}" = pkgs.stdenvNoCC.mkDerivation rec {
            inherit name;
            src = self;

            propagatedBuildInputs = [ tex ] ++ buildDeps;

            phases = [ "unpackPhase" "buildPhase" ];

            buildPhase = ''
              prefix=${builtins.placeholder "out"}
              mkdir -p $prefix/share
              cp doc/${name}.tex $prefix/share/${name}.tex
              cp doc/ref.bib $prefix/share/ref.bib
              export PATH="${pkgs.lib.makeBinPath propagatedBuildInputs}";
              DIR=$(mktemp -d)
              cd $prefix/share
              mkdir -p $DIR/.cache/texmf-var
              env TEXMFHOME="$DIR/.cache" \
                  TEXMFVAR="$DIR/.cache/texmf-var" \
                  OSFONTDIR=${pkgs.fira-code}/share/fonts \
                  SOURCE_DATE_EPOCH=${toString self.lastModified} \
                latexmk -interaction=nonstopmode -pdfxe -lualatex \
                --shell-escape \
                -output-directory="$DIR" \
                -pretex="\pdfvariable suppressoptionalinfo 512\relax${
                  texvars name
                }" \
                -usepretex ${name}.tex
              mv "$DIR/${name}.pdf" $prefix/share/
              rm -rf "$DIR"
            '';
          };
        };

        multipleBuildLaTeX = params:
          with pkgs.lib.attrsets;
          zipAttrsWith (_: pkgs.lib.head) (map buildLaTeX params);
        paramsFromNames = map (name: { inherit name; });
      in rec {
        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              # Nix
              deadnix.enable = true;
              nil.enable = true;
              nixfmt.enable = true;
              statix.enable = true;
              # LaTeX
              chktex.enable = true;
              latexindent.enable = true;
            };
          };
        };

        packages = multipleBuildLaTeX (paramsFromNames [ "slides" ]);

        defaultPackage = packages.slides;

        devShell = pkgs.mkShell {
          buildInputs = with pkgs;
            [ shellcheck ripgrep fd latexmkWrapped ] ++ buildDeps;

          inherit (self.checks.${system}.pre-commit-check) shellHook;
        };
      });
}
