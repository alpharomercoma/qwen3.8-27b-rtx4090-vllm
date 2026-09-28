# edge/: the alphaexperiments.com server

The domain's apex is served by Caddy on the PengePassportPH server. These files add `/heretic-inference` to it.
Install or update with `scripts/edge.sh install` ([docs/DEPLOY.md step 4](../docs/DEPLOY.md#4-connect-the-edge-mac--edge-server)).

| File | Installed as | What it is |
|---|---|---|
| `heretic-inference.caddy` | `/etc/caddy/apps.d/heretic-inference.caddy` | `/heretic-inference/v1/*` → the tunnel on `127.0.0.1:18443`; the rest of `/heretic-inference*` → the Vercel app |
| `sshd-heretic-tunnel.conf` | `/etc/ssh/sshd_config.d/20-heretic-tunnel.conf` | The tunnel account may only listen on `127.0.0.1:18443`: no shell, TTY or other forwarding |
| `sysctl-heretic-tunnel.conf` | `/etc/sysctl.d/60-heretic-tunnel.conf` | BBR and no slow start after idle, for the long, lossy path to the pod |
| `install.sh` | runs on the server | Creates `heretic-tunnel`, installs the three files, adds the Caddy `import` line, validates, reloads |
| `known_hosts` | used on the Mac and the pod | The server's SSH host keys (public), so neither side can be tricked into another server |

PengePassportPH's own template (`~/appointment-checker/deploy/caddy/Caddyfile.template`) needs the same
`import /etc/caddy/apps.d/*.caddy` line; otherwise its next provisioning run drops these routes.

Undo: delete `/etc/caddy/apps.d/heretic-inference.caddy`, `/etc/ssh/sshd_config.d/20-heretic-tunnel.conf`,
`/etc/sysctl.d/60-heretic-tunnel.conf` and the `heretic-tunnel` user, then `systemctl reload caddy ssh` and
`sysctl --system`.
