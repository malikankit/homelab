sudo ufw status
[sudo: authenticate] Password:
sudo: Authentication failed, try again.
[sudo: authenticate] Password:
Status: active

To                         Action      From
--                         ------      ----
41641/udp                  ALLOW       Anywhere                   # Tailscale
22                         ALLOW       100.87.74.44               # mbp16-mac tailnet1
22                         ALLOW       100.108.204.52             # mbp16-mac tailnet2
41641/udp (v6)             ALLOW       Anywhere (v6)              # Tailscale
