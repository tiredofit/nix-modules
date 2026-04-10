{config, lib, pkgs, ...}:

let
  cfg = config.host.network.vpn.zerotier;
  metrics_symlink =
    if cfg.metrics
      then ""
      else "ln -sf /dev/null /var/lib/zerotier-one/metrics.prom";
  metrics_cleanup =
    if cfg.metrics
      then ""
      else "rm -rf /var/lib/zerotier-one/metrics.prom";
in
  with lib;
{
  options = {
    host.network.vpn.zerotier = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables Zerotier virtual ethernet switch functionality";
      };
      identity = {
        public = {
          default = "null";
          type = with types; str;
          description = "Public Identity";
        };
        private = {
          default = "null";
          type = with types; str;
          description = "Private key of Identity";
        };
      };
      metrics = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables prometheus metrics writing";
      };
      exitNode = mkOption {
        default = false;
        type = with types; bool;
        description = "Enable exit-node behaviour by allowing IP forwarding and add firewall/NAT rules to allow routing traffic from Zerotier to the internet.";
      };
      configureClientFirewall = mkOption {
        default = false;
        type = with types; bool;
        description = "Configure local (CLIENT) firewall rules and sysctls to allow using a Zerotier exit node.";
      };
      configureExitFirewall = mkOption {
        default = true;
        type = with types; bool;
        description = "Configure firewall/NAT rules on this host to act as an exit node.";
      };
      openPort = mkOption {
        default = false;
        type = with types; bool;
        description = "Open the Zerotier UDP port in the firewall.";
      };
      networks = mkOption {
        type = with types; listOf str;
        description = "List of Network IDs to join on startup and back out of on stop";
      };
      port = mkOption {
        default = 9993;
        type = with types; port;
        description = "Network port used by Zerotier";
      };
    };
  };

  config = mkIf cfg.enable {
    services.zerotierone = {
      enable = true;
      #package = pkgs.unstable.zerotierone;
      port = cfg.port;
    };

    systemd.services.zerotierone = {
      preStart = mkOverride 50 ''
        mkdir -p /var/lib/zerotier-one/networks.d
        chmod 700 /var/lib/zerotier-one
        chown -R root:root /var/lib/zerotier-one
        network_list=$(echo ${toString cfg.networks} | tr ' ' '\n')

        _zt_join_network() {
          echo "Joining $1"
          touch /var/lib/zerotier-one/networks.d/"$1".conf
        }

        for network in $network_list ; do
            [[ "$network" =~ ^[[:space:]]*# ]] && continue
              if [ -f $network ] ; then
              echo "Reading networks from file"
              while read line; do
                [[ "$line" =~ ^[[:space:]]*# ]] && continue
                  _zt_join_network $(echo $line | ${pkgs.gawk}/bin/awk '{print $1}')
              done < "$network"
            else
                _zt_join_network $network
            fi
        done

        ${metrics_symlink}

        if [ -f /var/run/secrets/zerotier/identity_public ] ; then cat "/var/run/secrets/zerotier/identity_public" > /var/lib/zerotier-one/identity.public ; fi
        if [ -f /var/run/secrets/zerotier/identity_private ] ; then cat "/var/run/secrets/zerotier/identity_private" > /var/lib/zerotier-one/identity.secret  ; fi
      '';
      postStop = ''
        _zt_leave_network() {
          echo "Leaving $1"
          rm -rf /var/lib/zerotier-one/networks.d/"$1".conf
        }

        network_list=$(echo ${toString cfg.networks} | tr ' ' '\n')
        for network in $network_list ; do
            if [ -f $network ] ; then
              echo "Reading networks from file"
              while read line; do
                [[ "$line" =~ ^[[:space:]]*# ]] && continue
                  _zt_leave_network $(echo $line | ${pkgs.gawk}/bin/awk '{print $1}')
              done < "$network"
            else
                _zt_leave_network $network
            fi
        done

        if [ -f /var/run/secrets/zerotier/identity_public ] ; then rm -rf "/var/lib/zerotier-one/identity.public" ; fi
        if [ -f /var/run/secrets/zerotier/identity_private ] ; then rm -rf "/var/lib/zerotier-one/identity.secret" ; fi

        ${metrics_cleanup}
      '';
      serviceConfig = {
        Restart = "always";
        RestartSec = 10;
      };
      startLimitIntervalSec = 300;
      startLimitBurst = 50;
    };

      systemd.services.zerotier-firewall-exitnode = mkIf cfg.exitNode {
        description = "Add iptables MASQUERADE and FORWARD rules for ZeroTier (one-shot)";
        after = [ "network-online.target" "zerotierone.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" "zerotierone.service" ];
        unitConfig = {
          PartOf = "zerotierone.service";
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash /etc/zerotier-firewall-exitnode.sh";
        };
      };

      environment.etc."zerotier-firewall-exitnode.sh" = mkIf cfg.exitNode {
        text = ''
#!${pkgs.bash}/bin/bash -eu

IPTABLES=${pkgs.iptables}/bin/iptables

apply() {
  EXT_IF=$(get_ext_if)
  ZTS=$(ZT_CIDRS)
  if [ -n "$ZTS" ]; then
    for cidr in $ZTS; do
      $IPTABLES -t nat -C POSTROUTING -s "$cidr" -o "$EXT_IF" -j MASQUERADE 2>/dev/null || \
        $IPTABLES -t nat -A POSTROUTING -s "$cidr" -o "$EXT_IF" -j MASQUERADE
    done
  else
    echo "[zerotier] [exitNode] no ZeroTier IPv4 addresses found; skipping MASQUERADE addition"
  fi

  # Ensure FORWARD rules allow traffic between zt+ and external interface
  if [ -n "$EXT_IF" ]; then
    $IPTABLES -C FORWARD -i zt+ -o "$EXT_IF" -j ACCEPT 2>/dev/null || $IPTABLES -A FORWARD -i zt+ -o "$EXT_IF" -j ACCEPT
    $IPTABLES -C FORWARD -i "$EXT_IF" -o zt+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
      $IPTABLES -A FORWARD -i "$EXT_IF" -o zt+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  fi
  echo "[zerotier] [exitNode] Applied rules"
}

get_ext_if() {
  ${pkgs.iproute2}/bin/ip route get 8.8.8.8 2>/dev/null | ${pkgs.gawk}/bin/awk '{for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}'
}

remove() {
  EXT_IF=$(get_ext_if)
  ZTS=$(ZT_CIDRS)
  if [ -n "$ZTS" ]; then
    for cidr in $ZTS; do
      $IPTABLES -t nat -C POSTROUTING -s "$cidr" -o "$EXT_IF" -j MASQUERADE 2>/dev/null && \
        $IPTABLES -t nat -D POSTROUTING -s "$cidr" -o "$EXT_IF" -j MASQUERADE || true
    done
  else
    $IPTABLES -t nat -C POSTROUTING -o "$EXT_IF" -j MASQUERADE 2>/dev/null && \
      $IPTABLES -t nat -D POSTROUTING -o "$EXT_IF" -j MASQUERADE || true
  fi

  $IPTABLES -C FORWARD -i zt+ -o "$EXT_IF" -j ACCEPT 2>/dev/null && $IPTABLES -D FORWARD -i zt+ -o "$EXT_IF" -j ACCEPT || true
  $IPTABLES -C FORWARD -i "$EXT_IF" -o zt+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null && \
    $IPTABLES -D FORWARD -i "$EXT_IF" -o zt+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || true

  echo "[zerotier] [exitNode] Removed rules"
}

status() {
  echo "[zerotier] [exitNode] Status check for exit-node configuration"
  echo "net.ipv4.ip_forward: $(cat /proc/sys/net/ipv4/ip_forward)"
  echo
  echo "zerotierone: $(systemctl is-active zerotierone 2>/dev/null || true)"
  echo
  echo "ZeroTier interfaces:"
  ${pkgs.iproute2}/bin/ip -brief link show | ${pkgs.gawk}/bin/awk '/zt/ {print $0}' || echo "no zt* interfaces"
  echo

  IPTABLES=${pkgs.iptables}/bin/iptables
  if [ -z "$IPTABLES" ]; then
    echo "[zerotier] [exitNode] iptables not found; firewall rules not present"
    return 2
  fi

  EXT_IF=$(get_ext_if)
  if [ -n "$EXT_IF" ]; then
    echo "[zerotier] [exitNode] external interface: $EXT_IF"
  else
    echo "[zerotier] [exitNode] external interface: <unknown>"
  fi

  missing=0
  ZTS=$(ZT_CIDRS)
  if [ -n "$ZTS" ]; then
    for cidr in $ZTS; do
      if ! $IPTABLES -t nat -C POSTROUTING -s "$cidr" -o "$EXT_IF" -j MASQUERADE 2>/dev/null; then
        echo "[zerotier] [exitNode] MASQUERADE missing for $cidr -> $EXT_IF"
        missing=1
      else
        echo "[zerotier] [exitNode] MASQUERADE present for $cidr -> $EXT_IF"
      fi
    done
  else
    if $IPTABLES -t nat -C POSTROUTING -o "$EXT_IF" -j MASQUERADE 2>/dev/null; then
      echo "[zerotier] [exitNode] Broad MASQUERADE present on $EXT_IF"
    else
      echo "[zerotier] [exitNode] No ZeroTier CIDRs found and no broad MASQUERADE on $EXT_IF"
      missing=1
    fi
  fi

  # FORWARD rules
  if ! $IPTABLES -C FORWARD -i zt+ -o "$EXT_IF" -j ACCEPT 2>/dev/null; then
    echo "[zerotier] [exitNode] FORWARD zt+ -> $EXT_IF missing"
    missing=1
  else
    echo "FORWARD zt+ -> $EXT_IF present"
  fi
  if ! $IPTABLES -C FORWARD -i "$EXT_IF" -o zt+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
    echo "[zerotier] [exitNode] FORWARD $EXT_IF -> zt+ (RELATED,ESTABLISHED) missing"
    missing=1
  else
    echo "[zerotier] [exitNode] FORWARD $EXT_IF -> zt+ (RELATED,ESTABLISHED) present"
  fi

  return $missing
}

ZT_CIDRS() {
  ${pkgs.iproute2}/bin/ip -o -4 addr show | ${pkgs.gawk}/bin/awk '/ zt/ {print $4}' | sort -u
}

case "$1" in
  --status|-status|status)
    status
    exit $?
  ;;
  --remove|-remove|remove)
    remove
    exit $?
  ;;
  -h|--help|help)
    echo "Usage: $0 [--status|--remove]"
    exit 0
  ;;
  *)
    apply
  ;;
esac

'';
        mode = "0755";
      };

    boot.kernel.sysctl = mkMerge [ (mkIf cfg.exitNode { "net.ipv4.ip_forward" = 1; }) {
      "net.ipv4.conf.all.rp_filter" = 0;
      "net.ipv4.conf.default.rp_filter" = 0;
    } ];
    networking.firewall = mkMerge [
      (mkIf cfg.configureClientFirewall {
        trustedInterfaces = [ "zt+" ];
        checkReversePath = "loose";
      })

      (mkIf cfg.configureExitFirewall {
        checkReversePath = "loose";
      })

      (mkIf (cfg.openPort) { allowedUDPPorts = [ cfg.port ]; })

      { extraCommands = ''
        ${optionalString cfg.configureClientFirewall ''
          ${pkgs.iptables}/bin/iptables -C OUTPUT -o zt+ -j ACCEPT 2>/dev/null || ${pkgs.iptables}/bin/iptables -I OUTPUT -o zt+ -j ACCEPT
          ${pkgs.iptables}/bin/iptables -C INPUT -i zt+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || ${pkgs.iptables}/bin/iptables -I INPUT -i zt+ -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        ''}

        ${optionalString cfg.configureExitFirewall ''
          EXT_IF=$(${pkgs.iproute2}/bin/ip route get 8.8.8.8 2>/dev/null | ${pkgs.gawk}/bin/awk '{for(i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')
          if [ -n "$EXT_IF" ]; then
            ${pkgs.iptables}/bin/iptables -C FORWARD -i zt+ -o "$EXT_IF" -j ACCEPT 2>/dev/null || ${pkgs.iptables}/bin/iptables -A FORWARD -i zt+ -o "$EXT_IF" -j ACCEPT
            ${pkgs.iptables}/bin/iptables -C FORWARD -i "$EXT_IF" -o zt+ -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || ${pkgs.iptables}/bin/iptables -A FORWARD -i "$EXT_IF" -o zt+ -m state --state RELATED,ESTABLISHED -j ACCEPT
          fi
        ''}
        '';
      }
    ];

    sops.secrets = {
      ## Only read these secrets if the secret exists
      "zerotier/networks" = mkIf (builtins.pathExists "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/zerotier/networks.yaml")  {
        sopsFile = "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/zerotier/networks.yaml";
        restartUnits = [ "zerotierone.service" ];
      };
      "zerotier/identity_public" = mkIf (builtins.pathExists "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/zerotier/identity.yaml")  {
        sopsFile = "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/zerotier/identity.yaml";
        restartUnits = [ "zerotierone.service" ];
      };
      "zerotier/identity_private" = mkIf (builtins.pathExists "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/zerotier/identity.yaml")  {
        sopsFile = "${config.host.configDir}/hosts/${config.host.network.hostname}/secrets/zerotier/identity.yaml";
        restartUnits = [ "zerotierone.service" ];
      };
    };
  };
}