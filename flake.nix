{
  description = "Homelab Flake";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    colmena = {
      url = "github:stepbrobd/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.stable.follows = "nixpkgs";
      inputs.nix-github-actions.follows = "";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vex-brain = {
      url = "git+ssh://forgejo@forge/shane/vex-brain";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim.url = "github:nix-community/nixvim";
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-config-private.url = "git+ssh://forgejo@forge/shane/nix-config-private";
    ai-skills = {
      url = "git+ssh://forgejo@forge/shane/ai-skills";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.vex-brain.follows = "vex-brain";
    };
    vex-code = {
      url = "git+ssh://forgejo@forge/shane/vex-code?shallow=1";
      flake = false;
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    electron-nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    omniwm = {
      url = "github:mst-mkt/omniwm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      colmena,
      agenix,
      nix-darwin,
      vex-brain,
      ...
    }@inputs:
    let
      workstationPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ colmena.overlays.default ] ++ import ./pkgs/overlays.nix { inherit inputs; };
        };
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "terraform";
              overlays = [ colmena.overlays.default ];
            }
          )
        );
    in
    {
      formatter = forAllSystems (
        pkgs:
        pkgs.writeShellApplication {
          name = "format";
          runtimeInputs = [
            pkgs.nixfmt
            pkgs.terraform
            pkgs.git
          ];
          text = ''
            cd "$(git rev-parse --show-toplevel)"
            git ls-files --cached --others --exclude-standard -z '*.nix' \
              | xargs -0 -r nixfmt
            terraform fmt -recursive terraform
          '';
        }
      );

      devShells = forAllSystems (
        pkgs:
        let
          cf = pkgs.writeShellScriptBin "cf" ''
            exec ${pkgs.nodejs_22}/bin/npx --yes cf@1.0.0-beta.14 "$@"
          '';
        in
        {
          default = pkgs.mkShell {
            packages = [
              cf
              pkgs.cloudflared
              pkgs.wrangler
              pkgs.nodejs_22
              pkgs.dnsutils
              pkgs.doggo
              pkgs.jq
              pkgs.colmena
              agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
              pkgs.grafana-alloy
              pkgs.restic
              pkgs.rclone
              pkgs.nixfmt
              pkgs.statix
              pkgs.deadnix
              pkgs.terraform
              pkgs.tflint
              pkgs.biome
              pkgs.python3
              pkgs.ruff
              pkgs.uv
              pkgs.pre-commit
            ];
          };
        }
      );

      nixosConfigurations = {
        base = nixpkgs.lib.nixosSystem {
          modules = [ ./modules/base.nix ];
        };

      };

      darwinConfigurations = nixpkgs.lib.filterAttrs (
        _: node: node.config.deployment.systemType == "darwin"
      ) self.colmenaHive.nodes;

      hydraJobs = self.colmenaHive.toplevel;

      network =
        let
          inherit ((nixpkgs.lib.evalModules { modules = [ ./modules/devices.nix ]; }).config.homelab)
            gateway
            devices
            ;
          inherit (nixpkgs) lib;
          onLan = lib.filterAttrs (_: node: node.config.homelab.lanAddress != null) self.colmenaHive.nodes;
          forwardList = lib.concatLists (
            lib.mapAttrsToList (
              _: node:
              lib.mapAttrsToList (name: port: {
                inherit name port;
                ip = node.config.homelab.lanAddress;
              }) node.config.homelab.portForwards
            ) onLan
          );
          forwards =
            assert lib.assertMsg (
              lib.allUnique (map (forward: forward.name) forwardList)
              && lib.allUnique (map (forward: forward.port) forwardList)
            ) "Two hosts' homelab.portForwards share a name or a port.";
            forwardList;
        in
        {
          inherit gateway devices forwards;
          hosts = builtins.mapAttrs (_: node: node.config.homelab.lanAddress) onLan;
        };

      colmenaHive = colmena.lib.makeHive {
        meta = {
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = [ colmena.overlays.default ];
          };
          nodeNixpkgs = {
            mini = workstationPkgs "aarch64-darwin";
            macbook = workstationPkgs "aarch64-darwin";
          };
          inherit nix-darwin;
          specialArgs = { inherit inputs vex-brain; };
        };
        defaults =
          {
            config,
            lib,
            name,
            ...
          }:
          {
            deployment.targetHost = lib.mkDefault (
              if config.homelab.tailscale.enable then name else config.homelab.lanAddress
            );
            deployment.tags = lib.mkDefault [ "deploy-on-merge" ];
            imports = [
              ./modules/homelab.nix
              ./modules/devices.nix
              ./modules/services/tailscale/options.nix
              ./modules/services/backup/options.nix
            ];
          };

        nixosDefaults.imports = [
          ./modules/base.nix
          agenix.nixosModules.default
          ./modules/agenix
          ./modules/services/backup
          ./modules/services/alloy
          ./modules/services/tailscale
        ];

        darwinDefaults.imports = [ ./modules/darwin ];

        mini = {
          imports = [ ./hosts/mini.nix ];
        };

        macbook = {
          imports = [ ./hosts/macbook.nix ];
        };

        dashboard = {
          imports = [ ./hosts/dashboard.nix ];
          homelab.lanAddress = "192.168.1.152";
        };

        monitoring = {
          imports = [ ./hosts/monitoring.nix ];
          homelab.lanAddress = "192.168.1.78";
        };

        ingress = {
          imports = [ ./hosts/ingress.nix ];
          homelab.lanAddress = "192.168.1.149";
        };

        dns1 = {
          imports = [ ./hosts/dns.nix ];
          homelab.lanAddress = "192.168.1.91";
        };

        dns2 = {
          imports = [ ./hosts/dns.nix ];
          homelab.lanAddress = "192.168.1.236";
          deployment.tags = [ "deploy-after-dns1" ];
        };

        plex = {
          imports = [ ./hosts/plex.nix ];
          homelab.lanAddress = "192.168.1.237";
        };

        arr = {
          imports = [ ./hosts/arr.nix ];
          homelab.lanAddress = "192.168.1.90";
        };

        dlna = {
          imports = [ ./hosts/dlna.nix ];
          homelab.lanAddress = "192.168.1.66";
        };

        gym = {
          imports = [ ./hosts/gym.nix ];
          homelab.lanAddress = "192.168.1.209";
        };

        rss = {
          imports = [ ./hosts/rss.nix ];
          homelab.lanAddress = "192.168.1.153";
        };

        photos = {
          imports = [ ./hosts/photos.nix ];
          homelab.lanAddress = "192.168.1.154";
        };

        home = {
          imports = [ ./hosts/home.nix ];
          homelab.lanAddress = "192.168.1.117";
        };

        brain = {
          imports = [ ./hosts/brain.nix ];
          homelab.lanAddress = "192.168.1.243";
        };

        auth = {
          imports = [ ./hosts/auth.nix ];
          homelab.lanAddress = "192.168.1.31";
        };

        forge = {
          imports = [ ./hosts/forge.nix ];
          homelab.lanAddress = "192.168.1.115";
        };

        builder = {
          imports = [ ./hosts/builder.nix ];
          homelab.lanAddress = "192.168.1.224";
        };
      };
    };

}
