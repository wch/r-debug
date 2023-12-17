{
  description = "R-devel";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11"; };

  outputs = { self, nixpkgs }:
    let
      allSystems =
        [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];

      recommended-base-url = "https://cran.rstudio.com/src/contrib";

      forEachSupportedSystem = f:
        nixpkgs.lib.genAttrs allSystems (system:
          f rec {
            pkgs = import nixpkgs { inherit system; };
            inherit system;

            # ==================================================================
            # Get information about the most recent commit on r-source
            # ==================================================================
            r-source-commit-info-text =
              builtins.readFile ./r-source-commit-info.txt;
            r-source-commit-info-lines =
              nixpkgs.lib.splitString "\n" r-source-commit-info-text;
            getValue = key:
              with nixpkgs.lib;
              head (filter (line: hasPrefix (key + "=") line)
                r-source-commit-info-lines);
            extractValue = key:
              with nixpkgs.lib;
              substring (stringLength key + 1) (stringLength (getValue key))
              (getValue key);

            commit = extractValue "commit";
            commit-date = extractValue "commit-date";
            version-string = extractValue "version-string";
            svn-id = extractValue "svn-id";
            sha256 = extractValue "sha256";

            r-source = pkgs.fetchgit {
              url = "https://github.com/wch/r-source.git";
              rev = commit;
              sha256 = sha256;
            };

            # ==================================================================
            # Get the files from the rsync-recommended script
            # ==================================================================
            fetchMultipleFiles = { dataFile, baseUrl }:
              let
                fileContent = builtins.readFile dataFile;
                all_lines = pkgs.lib.splitString "\n" fileContent;
                lines = pkgs.lib.filter (line: line != "") all_lines;

                fetchFile = line:
                  let
                    parts = pkgs.lib.splitString " " line;
                    name = builtins.head parts;
                    hash = builtins.elemAt parts 1;
                  in pkgs.fetchurl {
                    url = baseUrl + name;
                    sha256 = hash;
                  };

              in builtins.map fetchFile lines;

            recommendedPackages = fetchMultipleFiles {
              dataFile = ./recommended_files.txt;
              baseUrl =
                "${recommended-base-url}/${version-string}/Recommended/";
            };

            # This is a single string containing paths to all the recommended package
            # tarballs that were downloaded, as in:
            # "/nix/store/iz71wp-KernSmooth_2.23-22.tar.gz /nix/store/ya86vy-MASS_7.3-60.1.tar.gz ..."
            # This is used for a shell script later on.
            recommendedPackagesPaths = pkgs.lib.concatStringsSep " "
              (map (x: x.outPath) recommendedPackages);
          });

      withRecommendedPackages = true;
      enableStrictBarrier = false;
      enableMemoryProfiling = false;
      static = false;

    in {
      packages = forEachSupportedSystem ({ pkgs, system, r-source, svn-id
        , commit-date, recommendedPackagesPaths, ... }: {

          default = pkgs.stdenv.mkDerivation {
            name = "R-devel";
            src = r-source;

            enableParallelBuilding = true;

            dontUseImakeConfigure = true;

            nativeBuildInputs = [ pkgs.pkg-config ];

            buildInputs = with pkgs;
              [
                bzip2
                gfortran
                xorg.libX11
                xorg.libXmu
                xorg.libXt
                libjpeg
                libpng
                libtiff
                ncurses
                pango
                pcre2
                perl
                readline
                (texliveSmall.withPackages (ps:
                  with ps; [
                    inconsolata
                    helvetic
                    ps.texinfo
                    fancyvrb
                    cm-super
                    rsfs
                  ]))
                xz
                zlib
                less
                texinfo
                graphviz
                icu
                bison
                xorg.imake
                which
                blas
                lapack
                curl
                tcl
                tk
                jdk
                tzdata
              ] ++ lib.optionals stdenv.isDarwin [
                darwin.apple_sdk.frameworks.Cocoa
                darwin.apple_sdk.frameworks.Foundation
                darwin.libobjc
                libcxx
              ];

            setupHook = ./setup-hook.sh;

            # patches = [ ./no-usr-local-search-paths.patch ];

            # Test of the examples for package 'tcltk' fails in Darwin sandbox. See:
            # https://github.com/NixOS/nixpkgs/issues/146131
            postPatch = pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
              substituteInPlace configure \
                --replace "-install_name libRblas.dylib" "-install_name $out/lib/R/lib/libRblas.dylib" \
                --replace "-install_name libRlapack.dylib" "-install_name $out/lib/R/lib/libRlapack.dylib" \
                --replace "-install_name libR.dylib" "-install_name $out/lib/R/lib/libR.dylib"
              substituteInPlace tests/Examples/Makefile.in \
                --replace "test-Examples: test-Examples-Base" "test-Examples:" # do not test the examples
            '';

            dontDisableStatic = static;

            preConfigure = ''
              configureFlagsArray=(
                --disable-lto
                --with${
                  pkgs.lib.optionalString (!withRecommendedPackages) "out"
                }-recommended-packages
                --with-blas="-L${pkgs.blas}/lib -lblas"
                --with-lapack="-L${pkgs.lapack}/lib -llapack"
                --with-readline
                --with-tcltk --with-tcl-config="${pkgs.tcl}/lib/tclConfig.sh" --with-tk-config="${pkgs.tk}/lib/tkConfig.sh"
                --with-cairo
                --with-libpng
                --with-jpeglib
                --with-libtiff
                --with-ICU
                ${
                  pkgs.lib.optionalString enableStrictBarrier
                  "--enable-strict-barrier"
                }
                ${
                  pkgs.lib.optionalString enableMemoryProfiling
                  "--enable-memory-profiling"
                }
                ${
                  if static then "--enable-R-static-lib" else "--enable-R-shlib"
                }
                AR=$(type -p ar)
                AWK=$(type -p gawk)
                CC=$(type -p cc)
                CXX=$(type -p c++)
                FC="${pkgs.gfortran}/bin/gfortran" F77="${pkgs.gfortran}/bin/gfortran"
                JAVA_HOME="${pkgs.jdk}"
                RANLIB=$(type -p ranlib)
                r_cv_have_curl728=yes
                R_SHELL="${pkgs.stdenv.shell}"
            '' +
              # 2023-12-07: Extra flags so R doesn't turn warnings into errors.
              # The flags that we're unsetting are coming from somewhere, but
              # I'm not sure where. Hopefully we can remove this in the future.
              ''
                CFLAGS="-Wno-error -Wno-format-security"
              '' + pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
                --disable-R-framework
                --without-x
                OBJC="clang"
                CPPFLAGS="-isystem ${
                  pkgs.lib.getDev pkgs.libcxx
                }/include/c++/v1"
                LDFLAGS="-L${pkgs.lib.getLib pkgs.libcxx}/lib"
              '' + ''
                )

                echo >>etc/Renviron.in "TCLLIBPATH=${pkgs.tk}/lib"
                echo >>etc/Renviron.in "TZDIR=${pkgs.tzdata}/share/zoneinfo"
              '' + ''
                # Do tasks similar to the rsync-recommended script
                cd src/library/Recommended
                for file in ${recommendedPackagesPaths} ; do
                  file_no_nix_path=$(echo $file | sed -E -e 's/[^-]+-//')
                  file_no_version=$(echo $file_no_nix_path | sed -e 's/_.*\.tar\.gz/.tgz/')
                  # At this point:
                  #  - file is like /nix/store/ya86vy-MASS_7.3-60.1.tar.gz
                  #  - file_no_nix_path is MASS_7.3-60.1.tar.gz
                  #  - file_no_version is MASS.tgz
                  ln -s $file $file_no_nix_path
                  ln -s $file_no_nix_path $file_no_version
                done
                ls -l
                cd ../../..
              '';

            postConfigure = ''
              # Do some stuff to simulate an SVN checkout.
              # https://github.com/wch/r-source/wiki
              (cd doc/manual && make front-matter html-non-svn)
              echo 'Revision: ${svn-id}' > SVN-REVISION
              echo 'Last Changed Date: ${commit-date}' >>  SVN-REVISION
            '';

            # The store path to "which" is baked into src/library/base/R/unix/system.unix.R,
            # but Nix cannot detect it as a run-time dependency because the installed file
            # is compiled and compressed, which hides the store path.
            postFixup = ''
              mkdir -p $out/nix-support/
              echo ${pkgs.which} > $out/nix-support/undetected-runtime-dependencies
            '';

          };
        });

      apps = forEachSupportedSystem ({ system, ... }: rec {
        R = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/R";
        };

        default = R;

        Rscript = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/Rscript";
        };
      });

      devShells = forEachSupportedSystem ({ pkgs, system, r-source, ... }: {
        default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];

          packages = with pkgs; [ git ];

          shellHook = ''
            echo "R-devel shell"
          '';
        };
      });
    };
}
