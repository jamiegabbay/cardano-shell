let
  # adding the haskell environment for running lhs2tex
  pkgs = import (import ./../nixpkgs.nix) { config = import ./../default.nix; };
in
  pkgs.stdenv.mkDerivation {
    name = "docsEnv";
    buildInputs = [ (pkgs.texlive.combine {
                      inherit (pkgs.texlive)
                        scheme-small
  
                        # libraries
                        stmaryrd lm-math amsmath extarrows cleveref semantic xcolor 
  
                        # additional libs for UML and natural deduction style graphics
                        pgf-umlsd bussproofs
  
                        # bclogo and dependencies
                        bclogo mdframed xkeyval etoolbox needspace
  
                        # font libraries `mathpazo` seems to depend on palatino, but it isn't pulled.
                        mathpazo palatino microtype
  
                        # libraries for marginal notes
                        xargs todonotes
  
                        # build tools
                        latexmk
  
                        # packages for lhs2tex
                        polytable lazylist
  
                        ;
                    })
                    pkgs.haskellPackages.lhs2tex
                  ];
  }
