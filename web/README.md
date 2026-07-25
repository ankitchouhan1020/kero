# Sora — website

Landing page for **Sora**, the native terminal workspace for macOS.

## Stack

- [TanStack Start](https://tanstack.com/start) (React 19 + Vite 8)
- [Tailwind CSS v4](https://tailwindcss.com)
- [shadcn/ui](https://ui.shadcn.com) with **Base UI** primitives (`@base-ui/react`)
- Deployed to [Cloudflare Workers](https://developers.cloudflare.com/workers/)
  via [`@cloudflare/vite-plugin`](https://developers.cloudflare.com/workers/vite-plugin/)

## Develop

```sh
bun install
bun run dev        # http://localhost:3000 (runs in the Workers runtime)
bun run typecheck  # tsc --noEmit
```

## Deploy (Cloudflare Workers)

```sh
bunx wrangler login   # once, to authenticate
bun run deploy        # vite build → wrangler deploy
```

`bun run build` outputs the Worker + client assets to `dist/`; the
`@cloudflare/vite-plugin` generates the deploy config, so plain `wrangler deploy`
picks it up. `bun run preview` serves the built Worker locally.

Config lives in [`wrangler.jsonc`](wrangler.jsonc). Deployments use the
maintainer-owned Cloudflare account selected by Wrangler and publish to the
Worker's `workers.dev` address. The `kero.sh` custom-domain route is ready to
enable after that zone is moved from its current Cloudflare account. Run
`bun run cf-typegen` after adding any bindings.

## Notes

- The theme lives in [`src/styles/app.css`](src/styles/app.css) — a GitHub-dark
  palette that mirrors the macOS app (`kero/Theme.swift`).
- Add more components with `bunx shadcn@latest add <name>` — the project is
  already configured for Base UI (`components.json` → `"style": "base-nova"`).
- The Worker reads the latest version and download URL from the Sparkle appcast;
  update the fallback in [`src/routes/index.tsx`](src/routes/index.tsx) when releasing.
- The hero product shot is [`public/sora-screenshot.png`](public/sora-screenshot.png)
  — swap the file to update it.

## Cutover and rollback

Verify the `workers.dev` deployment, download link, and Homebrew command first.
After the `kero.sh` zone is available in the same account, uncomment its custom
domain route in `wrangler.jsonc`, deploy, verify HTTPS and DNS, then remove the
old host. Wrangler keeps deployment history; rollback with
`bunx wrangler rollback` from this directory.
