{
  description = "k8sdoom - Doom-based Kubernetes administration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "k8sdoom";
          version = "1.0.0";

          src = ./.;

          nativeBuildInputs = [ 
            pkgs.pkg-config 
            pkgs.autoconf 
            pkgs.automake 
            pkgs.git 
            pkgs.unzip 
          ];
          
          buildInputs = [ 
            pkgs.SDL 
            pkgs.SDL_mixer 
            pkgs.SDL_net 
            pkgs.kubectl 
            pkgs.jq 
          ];

          buildPhase = ''
            # We use the existing Makefile logic but Nix provides the deps
            make build FORCE_VENDORED=0
          '';

          installPhase = ''
            mkdir -p $out/bin $out/share/k8sdoom
            cp build_tmp/psdoom-ng/trunk/src/psdoom-ng $out/bin/
            cp k8s-poll.sh $out/share/k8sdoom/
            cp k8sdoom.sh $out/bin/k8sdoom
            
            # Update the wrapper to find the poller in the Nix store
            sed -i "s|DATA_DIR=.*|DATA_DIR=$out/share/k8sdoom|" $out/bin/k8sdoom
          '';
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self'.packages.default ];
          packages = [ pkgs.pkg-config ];
        };
      };
    };
}
