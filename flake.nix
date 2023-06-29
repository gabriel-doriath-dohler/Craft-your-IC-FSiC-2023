{
  description = "V-RISC-V at FSiC 2023";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        vars = [ "paramDate" ];
        commited = self ? rev;
        texvars = name:
          toString
          (pkgs.lib.imap1 (i: n: "\\def\\${n}{${"$" + (toString i)}}") vars)
          + (if commited then
            " \\def\\reproduce{Reproduce using:\\newline nix run github:gabriel-doriath-dohler/V-RISC-V-FSiC-2023/${
               toString self.rev
             }\\#${name} -- "
          else
            " \\def\\reproduce{Not reproducible. Please commit (and push) your changes. Last commit: \\today. Arguments are: ")
          + (pkgs.lib.concatMapStrings (v: "'\\${v}'\\ ") vars)
          + "}"; # TODO better bash escape

        defaultTex = pkgs.texlive.combine {
          inherit (pkgs.texlive)
            scheme-medium latexmk geometry hyperref fontspec minted latex-bin
            mdwtools amsmath fvextra upquote catchfile xstring framed;
        };

        buildLaTeX = { name, tex ? defaultTex }: {
          "${name}" = pkgs.stdenvNoCC.mkDerivation rec {
            inherit name;
            src = self;

            propagatedBuildInputs = [ tex ] ++ (with pkgs; [
              coreutils # Choose the GNU `mktemp` over the BSD one.
              fira-code
              fira-code-symbols
              python310Packages.pygments
            ]);

            phases = [ "unpackPhase" "buildPhase" "installPhase" ];

            SCRIPT = ''
              #!/usr/bin/env bash
              prefix=${builtins.placeholder "out"}
              export PATH="${pkgs.lib.makeBinPath propagatedBuildInputs}";
              DIR=$(mktemp -d)
              RES=$(pwd)/${name}.pdf
              cd $prefix/share
              mkdir -p $DIR/.cache/texmf-var
              env TEXMFHOME="$DIR/.cache" \
                  TEXMFVAR="$DIR/.cache/texmf-var" \
                  OSFONTDIR=${pkgs.fira-code}/share/fonts \
                  SOURCE_DATE_EPOCH=${toString self.lastModified} \
                latexmk -interaction=nonstopmode -pdfxe -lualatex \
                -output-directory="$DIR" \
                -pretex="\pdfvariable suppressoptionalinfo 512\relax${
                  texvars name
                }" \
                -usepretex ${name}.tex
              mv "$DIR/${name}.pdf" $RES
              rm -rf "$DIR"
            '';

            buildPhase = ''
              printenv SCRIPT >${name}
            '';

            installPhase = ''
              mkdir -p $out/{bin,share}
              cp doc/${name}.tex $out/share/${name}.tex
              cp doc/ref.bib $out/share/ref.bib
              cp ${name} $out/bin/${name}
              chmod u+x $out/bin/${name}
            '';
          };
        };

        multipleBuildLaTeX = params:
          with pkgs.lib.attrsets;
          zipAttrsWith (_: l: pkgs.lib.head l) (map buildLaTeX params);
        paramsFromNames = names: map (name: { inherit name; }) names;
      in rec {
        packages = multipleBuildLaTeX (paramsFromNames [ "slides" ]);

        defaultPackage = packages.slides;

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ nixfmt shellcheck ripgrep fd ];
        };
      });
}
