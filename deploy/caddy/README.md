# Caddy / edge integration (deploy prep)

**Finding (2026-06-18 recon):** the BWH edge is ALREADY decoupled per-app — `9relay-caddy`
mounts `./caddy-snippets:/etc/caddy/snippets` and the main `/opt/9relay/Caddyfile` is
global-options + `import /etc/caddy/snippets/{english,billmind,status}.caddy`. Each app
owns its own snippet (the "right way" the PM wanted is in place). Only 9relay's own
vhosts remain inline in the main Caddyfile.

**So Diecast Vault needs NO restructure** — it just adds its own snippet
(`diecast-vault.caddy`) + one `import` line, exactly like BillMind/English/Status did.

**Concurrency safety:** the main Caddyfile is a single-file bind mount and is sometimes
edited by another session (recon found uncommitted `M Caddyfile` changes in flight).
NEVER edit it while another session is mid-edit. Add Diecast Vault's snippet only when
the box's git tree is clean / coordinated, then `caddy validate` → `docker restart
9relay-caddy` (not reload) → smoke-test every site → rollback ready.

**Optional later polish (touches the live relay — coordinate + explicit go-ahead):**
extract 9relay's own inline vhosts into `caddy-snippets/9relay.caddy` so the main
Caddyfile is purely globals + imports and 9relay is just another tenant.
