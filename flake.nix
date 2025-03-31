{
  description = "Flake containing required tools to deploy infra";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        (python3.withPackages (py-pkgs: [
          py-pkgs.ansible-core
          py-pkgs.kubernetes
        ]))
      ];

      LC_ALL = "C.UTF-8";
    
      shellHook = ''
        export KUBECONFIG="$(git rev-parse --show-toplevel)/ansible/artifacts/kubeconfig.yaml"
      '';
    };
  };

}
