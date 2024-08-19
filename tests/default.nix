{
  makeNixvimWithModule,
  lib ? pkgs.lib,
  helpers,
  pkgs,
  pkgsUnfree,
}:
let
  fetchTests = import ./fetch-tests.nix;
  test-derivation = import ./test-derivation.nix { inherit pkgs lib makeNixvimWithModule; };
  inherit (test-derivation) mkTestDerivationFromNixvimModule;

  # List of files containing configurations
  testFiles = fetchTests {
    inherit lib pkgs helpers;
    root = ./test-sources;
  };

  exampleFiles = {
    name = "examples";
    cases =
      let
        config = import ../example.nix { inherit pkgs; };
      in
      [
        {
          name = "main";
          case = builtins.removeAttrs config.programs.nixvim [
            # This is not available to standalone modules, only HM & NixOS Modules
            "enable"
            # This is purely an example, it does not reflect a real usage
            "extraConfigLua"
            "extraConfigVim"
          ];
        }
      ];
  };
in
# We attempt to build & execute all configurations
lib.pipe (testFiles ++ [ exampleFiles ]) [
  (builtins.map (
    file:
    let
      # The test case can either be the actual definition,
      # or a child attr named `module`.
      prepareModule = case: if lib.isFunction case then case else case.module or case;

      mkTest =
        { name, case }:
        {
          inherit name;
          path = mkTestDerivationFromNixvimModule {
            inherit name;
            module = prepareModule case;
            pkgs = pkgsUnfree;
          };
        };
    in
    {
      inherit (file) name;
      path = pkgs.linkFarm file.name (builtins.map mkTest file.cases);
    }
  ))
  (helpers.groupListBySize 10)
  (lib.imap1 (
    i: group: rec {
      name = "test-${toString i}";
      value = pkgs.linkFarm name group;
    }
  ))
  builtins.listToAttrs
]
