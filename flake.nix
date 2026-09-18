{
  description = "A standard for CI that stays green for the right reasons";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # The pinned toolbox for check-templates.sh, locally and in CI — the doctrine of
      # references/pinning.md applied to this repo itself
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            actionlint
            # The vendored check-sh.sh is moving to reading a script as a tree, out of
            # `shfmt --to-json`, with jq flattening that tree into rows. It arrives before
            # the checker that needs it, so the cascade does not deliver a red run
            jq
            shellcheck
            shfmt
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
