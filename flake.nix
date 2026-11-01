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
      url = "github:shaneplunkett/vex-brain";
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
    nix-config-private.url = "github:shaneplunkett/nix-config-private";
    ai-skills = {
      url = "github:shaneplunkett/ai-skills";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.vex-brain.follows = "vex-brain";
    };
    vex-code = {
      url = "github:shaneplunkett/vex-code";
      flake = false;
    };
    llm-agents.url = "github:numtide/llm-agents.nix/b14f9d18b6d127221bd9f63817a40e1cca2b344b";
    electron-nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core/b155c22479e977139561de5f79283586e89e1714";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask/5479f36345481e9b84a94e19a84d32bfec66639b";
      flake = false;
    };
    omniwm = {
      url = "github:mst-mkt/omniwm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jovian = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-github-actions.follows = "";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia.url = "git+https://github.com/noctalia-dev/noctalia?ref=cachix&shallow=1";
    noctalia-greeter.url = "github:noctalia-dev/noctalia-greeter";
    noctalia-plugins = {
      url = "github:shaneplunkett/noctalia-plugins";
      flake = false;
    };
    wallpapers = {
      url = "github:shaneplunkett/wallpapers";
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
      guest =
        module: host: settings:
        {
          imports = [
            module
            ./hosts/${host}.nix
          ];
        }
        // settings;
      incus = guest ./modules/incus.nix;
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
            exec ${pkgs.nodejs_22}/bin/npx --yes cf@1.0.0-beta.26 "$@"
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
          incus-base = nixpkgs.lib.nixosSystem {
            modules = [
              ./modules/homelab.nix
              ./modules/nixos.nix
              ./modules/incus.nix
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
              lib.mapAttrsToList (name: forward: {
                inherit name;
                inherit (forward) port protocol;
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
          guests = builtins.mapAttrs (_: node: node.config.homelab.guest) (
            lib.filterAttrs (_: node: node.config.homelab.guest != null) self.colmenaHive.nodes
          );
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
            deck = workstationPkgs "x86_64-linux";
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
          ./modules/services/attic/client.nix
        ];

        darwinDefaults.imports = [
          ./modules/darwin
          agenix.darwinModules.default
          ./modules/agenix
          ./modules/services/attic/client.nix
        ];

        mini = {
          imports = [ ./hosts/mini.nix ];
        };

        macbook = {
          imports = [ ./hosts/macbook.nix ];
        };

        desktop = {
          imports = [ ./hosts/desktop ];
        };

        deck = {
          imports = [ ./hosts/deck ];
        };

        dashboard = incus "dashboard" {
          homelab.lanAddress = "192.168.1.152";
          homelab.guest = {
            host = "pve";
            mac = "BC:24:11:C0:8C:06";
          };
        };

        monitoring = incus "monitoring" {
          homelab.lanAddress = "192.168.1.78";
          homelab.guest = {
            host = "cube";
            cores = 4;
            memory = 6144;
            disk = 40;
            mac = "BC:24:11:DD:65:EE";
          };
        };

        ingress = incus "ingress" {
          homelab.lanAddress = "192.168.1.149";
          homelab.guest = {
            host = "pve";
            cores = 1;
            memory = 1024;
            mac = "BC:24:11:42:4E:7D";
          };
        };

        dns1 = incus "dns" {
          homelab.lanAddress = "192.168.1.91";
          homelab.guest = {
            host = "pve";
            cores = 1;
            memory = 1024;
            mac = "BC:24:11:10:29:FC";
          };
        };

        dns2 = incus "dns" {
          homelab.lanAddress = "192.168.1.236";
          homelab.guest = {
            host = "cube";
            cores = 1;
            memory = 1024;
            mac = "BC:24:11:B3:E3:C3";
          };
          deployment.tags = [ "deploy-after-dns1" ];
        };

        plex = incus "plex" {
          homelab.lanAddress = "192.168.1.237";
          homelab.guest = {
            host = "cube";
            cores = 4;
            memory = 8192;
            disk = 100;
            mac = "BC:24:11:AA:D1:7C";
            mounts."/mnt/media" = "/mnt/media";
            devices = [
              {
                path = "/dev/dri/renderD128";
                gid = 303;
              }
            ];
          };
        };

        arr = incus "arr" {
          homelab.lanAddress = "192.168.1.90";
          homelab.guest = {
            host = "cube";
            cores = 4;
            memory = 8192;
            disk = 40;
            mac = "BC:24:11:25:4D:73";
            mounts."/mnt/media" = "/mnt/media";
          };
        };

        dlna = incus "dlna" {
          homelab.lanAddress = "192.168.1.66";
          homelab.guest = {
            host = "cube";
            cores = 1;
            memory = 512;
            mac = "BC:24:11:77:AD:79";
            mounts."/mnt/programs" = "/mnt/programs";
          };
        };

        rss = incus "rss" {
          homelab.lanAddress = "192.168.1.153";
          homelab.guest = {
            host = "pve";
            cores = 1;
            memory = 1024;
            mac = "BC:24:11:FD:C5:8A";
          };
        };

        photos = incus "photos" {
          homelab.lanAddress = "192.168.1.154";
          homelab.guest = {
            host = "cube";
            cores = 4;
            memory = 8192;
            disk = 250;
            mac = "BC:24:11:CA:51:3A";
          };
        };

        paper = incus "paper" {
          homelab.lanAddress = "192.168.1.155";
          homelab.guest = {
            host = "cube";
            memory = 8192;
            disk = 32;
            mac = "BC:24:11:2A:A7:BB";
          };
        };

        music = incus "music" {
          homelab.lanAddress = "192.168.1.156";
          homelab.guest = {
            host = "cube";
            cores = 2;
            memory = 2048;
            disk = 32;
            mounts."/mnt/media" = "/mnt/media";
          };
        };

        recipes = incus "recipes" {
          homelab.lanAddress = "192.168.1.157";
          homelab.guest = {
            host = "pve";
            disk = 16;
          };
        };

        home = incus "home" {
          homelab.lanAddress = "192.168.1.117";
          homelab.guest = {
            host = "pve";
            memory = 3072;
            disk = 16;
            mac = "BC:24:11:21:E0:4E";
            vlans = [
              {
                id = 20;
                mac = "BC:24:11:33:8D:CE";
                address = "192.168.20.117/24";
              }
            ];
          };
        };

        brain = incus "brain" {
          homelab.lanAddress = "192.168.1.243";
          homelab.guest = {
            host = "pve";
            cores = 4;
            memory = 8192;
            disk = 64;
            mac = "BC:24:11:D3:65:F1";
          };
        };

        auth = incus "auth" {
          homelab.lanAddress = "192.168.1.31";
          homelab.guest = {
            host = "pve";
            cores = 1;
            memory = 1024;
            mac = "BC:24:11:40:64:96";
          };
        };

        forge = incus "forge" {
          homelab.lanAddress = "192.168.1.115";
          homelab.guest = {
            host = "pve";
            disk = 32;
            mac = "BC:24:11:12:40:4A";
          };
        };

        cache = incus "cache" {
          homelab.lanAddress = "192.168.1.158";
          homelab.guest = {
            host = "pve";
            cores = 4;
            disk = 100;
          };
        };

        mirror = incus "mirror" {
          homelab.lanAddress = "192.168.1.159";
          homelab.guest = {
            host = "pve";
            mounts."/var/lib/mirror" = "/mnt/user/mirror";
          };
        };

        builder = incus "builder" {
          homelab.lanAddress = "192.168.1.224";
          homelab.guest = {
            host = "pve";
            cores = 20;
            memory = 49152;
            disk = 250;
            mac = "BC:24:11:CC:42:C2";
          };
          deployment.tags = [ ];
        };

        pve = {
          imports = [ ./hosts/pve ];
          deployment.tags = [ ];
        };

        cube = {
          imports = [ ./hosts/cube ];
          deployment.tags = [ ];
        };
      };
    };

}
