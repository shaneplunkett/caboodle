{
  description = "caboodle: every machine Shane runs";

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
    llm-agents.url = "github:numtide/llm-agents.nix/8fa7ff4193be923056b342d48d5bb38466791fe1";
    electron-nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core/4aef89dc369d9f743e6427e4369c63d89492b1bc";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask/986ddaba01d9abc7707ef2d044fe1adf1f963d9c";
      flake = false;
    };
    omniwm = {
      url = "github:mst-mkt/omniwm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia.url = "git+https://github.com/noctalia-dev/noctalia?ref=cachix&shallow=1";
    noctalia-greeter.url = "github:noctalia-dev/noctalia-greeter";
    noctalia-plugins = {
      url = "git+ssh://forgejo@forge/shane/noctalia-plugins";
      flake = false;
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
      lxc =
        host: settings:
        {
          imports = [
            ./modules/lxc.nix
            ./hosts/${host}.nix
          ];
        }
        // settings;
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
            pkgs.git
            pkgs.nixfmt
            pkgs.terraform
            pkgs.ruff
            pkgs.biome
            pkgs.shfmt
            pkgs.go
          ];
          text = ''
            cd "$(git rev-parse --show-toplevel)"
            git ls-files --cached --others --exclude-standard -z '*.nix' \
              | xargs -0 -r nixfmt
            terraform fmt -recursive terraform
            ruff format .
            biome format --write .
            git ls-files --cached --others --exclude-standard -z '*.sh' | xargs -0 -r shfmt -w
            git ls-files --cached --others --exclude-standard -z '*.go' | xargs -0 -r gofmt -w
          '';
        }
      );

      devShells = forAllSystems (
        pkgs:
        let
          cf = pkgs.writeShellScriptBin "cf" ''
            exec ${pkgs.nodejs_22}/bin/npx --yes cf@1.0.0-beta.18 "$@"
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
              pkgs.mypy
              pkgs.uv
              pkgs.shellcheck
              pkgs.shfmt
              pkgs.go
              pkgs.bun
              pkgs.git
              pkgs.pre-commit
            ];

            shellHook = ''
              if hook="$(git rev-parse --git-path hooks/pre-commit 2>/dev/null)" && [ ! -e "$hook" ]; then
                pre-commit install >/dev/null || true
              fi
              unset hook
            '';
          };
        }
      );

      nixosConfigurations =
        nixpkgs.lib.filterAttrs (
          _: node: node.config.deployment.systemType == "nixos"
        ) self.colmenaHive.nodes
        // {
          base = nixpkgs.lib.nixosSystem {
            modules = [
              ./modules/homelab.nix
              ./modules/nixos.nix
              ./modules/lxc.nix
              { homelab.monitoring.enable = false; }
            ];
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
            desktop = workstationPkgs "x86_64-linux";
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
          ./modules/nixos.nix
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

        desktop = {
          imports = [ ./hosts/desktop ];
        };

        dashboard = lxc "dashboard" { homelab.lanAddress = "192.168.1.152"; };

        monitoring = lxc "monitoring" { homelab.lanAddress = "192.168.1.78"; };

        ingress = lxc "ingress" { homelab.lanAddress = "192.168.1.149"; };

        dns1 = lxc "dns" { homelab.lanAddress = "192.168.1.91"; };

        dns2 = lxc "dns" {
          homelab.lanAddress = "192.168.1.236";
          deployment.tags = [ "deploy-after-dns1" ];
        };

        plex = lxc "plex" { homelab.lanAddress = "192.168.1.237"; };

        arr = lxc "arr" { homelab.lanAddress = "192.168.1.90"; };

        dlna = lxc "dlna" { homelab.lanAddress = "192.168.1.66"; };

        gym = lxc "gym" { homelab.lanAddress = "192.168.1.209"; };

        rss = lxc "rss" { homelab.lanAddress = "192.168.1.153"; };

        photos = lxc "photos" { homelab.lanAddress = "192.168.1.154"; };

        paper = lxc "paper" { homelab.lanAddress = "192.168.1.155"; };

        home = lxc "home" { homelab.lanAddress = "192.168.1.117"; };

        brain = lxc "brain" { homelab.lanAddress = "192.168.1.243"; };

        auth = lxc "auth" { homelab.lanAddress = "192.168.1.31"; };

        forge = lxc "forge" { homelab.lanAddress = "192.168.1.115"; };

        builder = lxc "builder" { homelab.lanAddress = "192.168.1.224"; };

        nas = {
          imports = [
            ./modules/vm.nix
            ./hosts/nas.nix
          ];
        };
      };
    };

}
