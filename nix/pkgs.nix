{ pkgs ? import <nixpkgs> {}
, iohk-extras ? {}
, iohk-module ? {}
, haskell
, ...
}:
let

  # our packages
  stack-pkgs = import ./.stack.nix;

  # Build the packageset with module support.
  # We can essentially override anything in the modules
  # section.
  #
  #  packages.cbors.patches = [ ./one.patch ];
  #  packages.cbors.flags.optimize-gmp = false;
  #
  compiler = (stack-pkgs.extras haskell.hackage).compiler;
  pkgSet = haskell.mkStackPkgSet {
    inherit stack-pkgs;
    # The extras allow extension or restriction of the set of
    # packages we are interested in. By using the stack-pkgs.extras
    # we restrict our package set to the ones provided in stack.yaml.
    pkg-def-extras = [
      iohk-extras.${compiler.nix-name}
    ];
    modules = [
      # the iohk-module will supply us with the necessary
      # cross compilation plumbing to make Template Haskell
      # work when cross compiling.
      iohk-module
      {
        # katip has an version bound of Win32 < 2.6; this however
        # implies that it's incompatible with ghc-8.6 (on windows).
        # Let's force it to accept out packageset.
        packages.katip.doExactConfig = true;
        # turtle seems to have the same issue.
        packages.turtle.doExactConfig = true;
      }
    ];
  };

in
  pkgSet.config.hsPkgs // { _config = pkgSet.config; }
