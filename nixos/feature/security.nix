{ config, lib, pkgs, ... }:
with lib;
let
  sys = config.host.hardware;
  cfg = config.host.feature.security;
in {
  options = {
    host.feature.security = {
      enable = mkOption {
        default = false;
        type = with types; bool;
        description = "Enables security hardening features";        # NOTE: enabling this may break some things
      };
    };
  };

  config = mkIf cfg.enable {
    boot = {
      blacklistedKernelModules = [
        # Obscure network protocols
        "ax25"
        "netrom"
        "rose"
        # Old or rare or insufficiently audited filesystems
        "adfs"
        "affs"
        "bfs"
        "befs"
        "cramfs"
        "efs"
        "erofs"
        "exofs"
        "freevxfs"
        "f2fs"
        "hfs"
        "hpfs"
        "jfs"
        "minix"
        "nilfs2"
        "ntfs"
        "omfs"
        "qnx4"
        "qnx6"
        "sysv"
        "ufs"
      ] ++ lib.optionals (!sys.bluetooth.enable) [
        "btusb"                                         # Allow Bluetooth dongles to work
      ] ++ lib.optionals (!sys.webcam.enable) [
        "uvcvideo"                                      # Allow webcam to work
      ];

      kernel.sysctl = {
        "kernel.ftrace_enabled" = mkDefault false;        # Disable ftrace debugging
        "kernel.kptr_restrict" = mkOverride 500 2;        # Hide kptrs even for processes with CAP_SYSLOG
        "kernel.sysrq" = mkDefault 0;                     # The Magic SysRq key is a key combo that allows users connected to the Linux kernel to perform some low-level commands. Disable it, since we don't need it, and is a potential security concern.
        "kernel.yama.ptrace_scope" = mkDefault 2;         # Restrict ptrace() usage to processes with a pre-defined relationship (e.g., parent/child)
        "net.core.bpf_jit_enable" = mkDefault false;      # Disable bpf() JIT (to eliminate spray attacks)
      };
    };

    security = {
      allowSimultaneousMultithreading = mkDefault false;
      allowUserNamespaces = mkDefault true;     # User namespaces are required for sandboxing. Better than nothing imo.
      apparmor = {
        enable = mkDefault true;
        killUnconfinedConfinables = mkDefault true;
        packages = [ pkgs.apparmor-profiles ];
      };
      auditd.enable = mkDefault true;           # TODO: make this optional, audit logs get massive really quick
      audit = {
        enable = mkDefault true;
        backlogLimit = 8192;
        failureMode = "printk";
        rules = [ "-a exit,always -F arch=b64 -S execve" ];
      };
      forcePageTableIsolation = mkDefault true; # force-enable the Page Table Isolation (PTI) Linux kernel feature
      lockKernelModules = mkDefault false;      # breaks virtd, wireguard and iptables
      pam = {
        loginLimits = [                         # fix "too many files open"
          {
            domain = "@wheel";
            item = "nofile";
            type = "soft";
            value = "524288";
          }
          {
            domain = "@wheel";
            item = "nofile";
            type = "hard";
            value = "1048576";
          }
        ];
      };
      polkit.extraConfig = ''                   # log polkit request actions
        polkit.addRule(function(action, subject) {
          polkit.log("user " +  subject.user + " is attempting action " + action.id + " from PID " + subject.pid);
        });
      '';
      protectKernelImage = mkDefault true;
      sudo = {
        enable = mkDefault true;
        execWheelOnly = mkDefault true;
        extraConfig = ''
          Defaults env_keep += "EDITOR PATH"
          Defaults lecture = never # rollback results in sudo lectures after each reboot
          Defaults passprompt="[31m sudo: password for %p@%h, running as %U:[0m "
          Defaults pwfeedback
          Defaults timestamp_timeout = 300
        '';
        wheelNeedsPassword = mkDefault false;
      };
      unprivilegedUsernsClone = config.host.feature.virtualization.docker.enable; # Disable unprivileged user namespaces, unless containers are enabled
      virtualisation = {
        flushL1DataCache = "always";            #  flush the L1 data cache before entering guests
      };
    };
  };
}
