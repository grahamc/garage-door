{
  users.users.root.openssh.authorizedKeys.keys = [
    ''command="systemctl start garage-door.service" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPZYXB4fnfK1HTWg4uQKq7BXA3SiXIxAJIRaJ29jKDhw Graham''
    ''command="systemctl start garage-door.service" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/R1f9h/cxrezisP2G27MtBABPV+1Jt0wNM68C5kRuk Emily''
  ];
  systemd.services.garage-door = {
    description = "Toggle the garage door.";
    script = "${./garage-door.sh}";
  };
}
