{ pkgs, ... }: {
  users.users.root.openssh.authorizedKeys.keys = [
    ''command="${./start.sh}" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFOa5cbhZe3b8IkAYL5Fmel+HxlU6UXrepjz6JOywP4k Graham''
    ''command="${./start.sh}" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/R1f9h/cxrezisP2G27MtBABPV+1Jt0wNM68C5kRuk Emily''
  ];
  systemd.services."garage-door@" = {
    description = "Toggle the garage door.";
    script = ''${./garage-door.sh} "$1"'';
    path = [ pkgs.libgpiod ];
    scriptArgs = "%i";
  };
}
