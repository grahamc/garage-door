{ pkgs, ... }:
{
  networking.firewall.allowedTCPPorts = [
    9100 # node-exporter
  ];
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
  };
}
