# edge/: the alphaexperiments.com server

The domain's apex is served by Caddy on a small server that also hosts another project (PengePassportPH), which owns
`/etc/caddy/Caddyfile`. These files add `/heretic-inference` to it without changing that project's code. Install or
update with `scripts/edge.sh install` ([docs/DEPLOY.md step 4](../docs/DEPLOY.md#4-connect-the-edge-mac--edge-server)).

| File | Installed as | What it is |
|---|---|---|
| `heretic-inference.caddy` | `/etc/caddy/apps.d/heretic-inference.caddy` | `/heretic-inference/v1/*` → the tunnel on `127.0.0.1:18443`; the rest of `/heretic-inference*` → the Vercel app |
| `sshd-heretic-tunnel.conf` | `/etc/ssh/sshd_config.d/20-heretic-tunnel.conf` | The tunnel account may only listen on `127.0.0.1:18443`: no shell, TTY or other forwarding |
| `sysctl-heretic-tunnel.conf` | `/etc/sysctl.d/60-heretic-tunnel.conf` | BBR and no slow start after idle, for the long, lossy path to the pod |
| `install.sh` | runs on the server | Creates `heretic-tunnel`, installs the three files, adds the Caddy `import` line if missing, validates, reloads |
| `known_hosts` | used on the Mac and the pod | The server's SSH host keys (public), so neither side can be tricked into another server |

The only change to the other project's file is one `import /etc/caddy/apps.d/*.caddy` line inside the
`alphaexperiments.com { ... }` block. If that project regenerates its Caddyfile, the line disappears and
`/heretic-inference` stops answering: run `scripts/edge.sh install` again, it adds the line back when it is missing.

Undo: delete `/etc/caddy/apps.d/heretic-inference.caddy`, `/etc/ssh/sshd_config.d/20-heretic-tunnel.conf`,
`/etc/sysctl.d/60-heretic-tunnel.conf`, the `heretic-tunnel` user and the import line, then `systemctl reload caddy
ssh` and `sysctl --system`.
