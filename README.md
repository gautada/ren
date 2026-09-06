# ren

Infrastructure Architect Agent: Ren Nakatomi.

A specific `pi` agent harness built on the `gautada/pi` → `gautada/debian`
image chain.

## UID / GID contract

The container user is aligned to **UID 1000 / GID 1000** to match the ownership
of the persistent, NFS-backed volume mounted at `/mnt/volumes/data` (owned
`1000:10` by the operator/host). This eliminates the long-standing mismatch that
previously forced world-writable workarounds (see gautada/ren#9).

```
gautada/debian   ARG UID=1000   <- source of truth (base user)
   └── gautada/pi   (inherits base user)
         └── gautada/ren   (renames slice -> ren, keeps UID/GID)
```

- **UID is owned by the base image** (`gautada/debian`, `ARG UID`). `ren` only
  *renames* the base user (`usermod -l ren slice`); it does not set the UID. To
  change the UID, change it in `gautada/debian` and rebuild the chain.
- At runtime `id` reports `uid=1000(ren) gid=1000(ren)`, with supplementary
  groups including `10(uucp)` (matches the volume's group `10`) and
  `99(privileged)`.
- Because the process owns its durable state, `/mnt/volumes/data` uses sane
  owner-only perms (`0700` dirs / `0600` secrets) — **not** world-writable.

### Persistence

`~` (home) is reset on every pod restart; only `/mnt/volumes/data` survives.
Durable state (pi config, sessions, extensions, skills, secrets) lives on the
volume and is exposed under `~` via symlinks. The `00_bootstrap.ts` extension
re-creates the handful of links the image does not bake.
