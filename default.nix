#
# The defaul.nix file. This will generate targets for all
# buildables (see release.nix for nomenclature, excluding
# the "build machine" last part, specific to release.nix), eg.:
#
# - nix build -f default.nix nix-tools.tests.cardano-shell # All `cardano-shell` tests
# - nix build -f default.nix nix-tools.tests.cardano-shell.tests
# - nix build -f default.nix nix-tools.exes.cardano-shell # All `cardano-shell` executables
# - nix build -f default.nix nix-tools.cexes.cardano-shell.cardano-launcher
#
# Generated targets include anything from stack.yaml (via
# nix-tools:stack-to-nix and the nix/regenerate.sh script)
# or cabal.project (via nix-tools:plan-to-nix), including all
# version overrides specified there.
#
# Nix-tools stack-to-nix will generate the `nix/.stack-pkgs.nix`
# file which is imported from the `nix/pkgs.nix` where further
# customizations outside of the ones in stack.yaml/cabal.project
# can be specified as needed for nix/ci.
#
# Please run `nix/regenerate.sh` after modifying stack.yaml
# or relevant part of cabal configuration files.
# When switching to recent stackage or hackage package version,
# you might also need to update the iohk-nix common lib. You
# can do so by running the `nix/update-iohk-nix.sh` script.
#
# More information about iohk-nix and nix-tools is available at:
# https://github.com/input-output-hk/iohk-nix/blob/master/docs/nix-toolification.org#for-a-stackage-project
#


# We will need to import the iohk-nix common lib, which includes
# the nix-tools tooling.
let
  commonLib = import ./nix/iohk-common.nix;
in
# This file needs to export a function that takes
# the arguments it is passed and forwards them to
# the default-nix template from iohk-nix. This is
# important so that the release.nix file can properly
# parameterize this file when targetting different
# hosts.
{ system ? builtins.currentSystem
, crossSystem ? null
, config ? {}
, pkgs ? commonLib.getPkgs { inherit config crossSystem system; }
, withHoogle ? true
}:
let
  # We will instantiate the default-nix template with the
  # nix/pkgs.nix file...
  defaultNix = commonLib.nix-tools.default-nix ./nix/pkgs.nix {
    inherit system crossSystem config pkgs;
  };
in defaultNix // {
  # ... and add additional packages we want to build on CI:

  env = defaultNix.nix-tools.shellFor {
    inherit withHoogle;
    # env will provide the dependencies of cardano-shell
    packages = ps: with ps; [ cardano-shell ];
    # This adds git to the shell, which is used by stack.
    buildInputs = with pkgs; [ git stack commonLib.stack-hpc-coveralls ];
  };

  runCoveralls = pkgs.stdenv.mkDerivation {
    name = "run-coveralls";
    buildInputs = with pkgs; [ commonLib.stack-hpc-coveralls stack ];
    shellHook = ''
      echo '~~~ stack nix test'
      stack test --nix --coverage
      echo '~~~ shc'
      shc --repo-token=$COVERALLS_REPO_TOKEN cardano-shell cardano-shell-test
      exit
    '';
  };
}
