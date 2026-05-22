# AGENTS.md — Fuwari (Astro Blog)

A static blog built on [Fuwari](https://github.com/saicaca/fuwari), an Astro template. This file contains repo-specific facts a future agent session needs to avoid mistakes.

## Quick start

```bash
pnpm install          # pnpm 9.14.4 required (enforced by preinstall hook)
pnpm dev              # localhost:4321
pnpm new-post <name>  # creates src/content/posts/<name>.md
```

**Package manager is ALWAYS pnpm.** `npm` and `yarn` are blocked at the hook level.

## Build, test, lint

| Command | What it does |
|---|---|
| `pnpm dev` / `pnpm start` | Dev server at localhost:4321 |
| `pnpm build` | `astro build` then `pagefind --site dist` (search index) |
| `pnpm preview` | Preview production build locally |
| `pnpm type-check` | `tsc --noEmit --isolatedDeclarations` |
| `pnpm format` | `biome format --write ./src` |
| `pnpm lint` | `biome check --apply ./src` |

**Testing:** There is no test runner. The project has NO test suite — lint + type-check + build is the verification surface.

**Before committing, always run:** `pnpm type-check && pnpm build`. The build step generates both the static site AND the Pagefind search index — an incomplete build silently breaks search.

## Architecture

```
src/
├── config.ts          # User-editable site config (title, lang, themeColor, banner, etc.)
├── content/
│   ├── config.ts      # Astro content collections schema (zod)
│   ├── posts/         # Blog posts (*.md, can be in subdirectories)
│   └── spec/          # Static pages (about.md, friends.md)
├── pages/
│   ├── [...page].astro       # Paginated post list (8 per page)
│   ├── posts/[...slug].astro # Individual post
│   ├── archive/              # Archive, tag, and category pages
│   ├── about.astro, friends.astro
│   ├── rss.xml.ts            # RSS feed
│   └── robots.txt.ts
├── layouts/
│   ├── Layout.astro          # Base HTML shell (theme, swup, photoswipe, scrollbars)
│   └── MainGridLayout.astro  # Main content grid with sidebar
├── components/
│   ├── *.astro               # Astro components (PostCard, PostMeta, Navbar, etc.)
│   ├── *.svelte              # Interactive Svelte 5 components (Search, LightDarkSwitch)
│   ├── control/              # Pagination, theme/profile panels
│   ├── misc/                 # Markdown renderer, License, ImageWrapper
│   └── widget/               # Sidebar widgets
├── i18n/                     # Translations: en, zh_CN, zh_TW, ja, ko, es, th
├── plugins/                  # remark/rehype plugins (admonitions, katex, reading-time, etc.)
├── styles/                   # main.css (Tailwind) + variables.styl (Stylus CSS vars)
├── constants/                # PAGE_SIZE, banner dimensions, link presets, icon defs
├── types/                    # TypeScript type definitions (config types)
└── utils/                    # content-utils, date-utils, url-utils, setting-utils
```

### Key conventions

- **All URLs end with `/`.** Astro's `trailingSlash: "always"` is set. When linking internally, always include the trailing slash: `url('/posts/my-post/')`, NOT `'/posts/my-post'`.
- **Image paths in posts are relative to the markdown file.** To resolve them in components, use `path.join("content/posts/", getDir(entry.id))` as the base. See `posts/[...slug].astro` for the pattern.
- **Draft posts are hidden in production but visible in dev.** Collection queries check `import.meta.env.PROD ? data.draft !== true : true`.
- **Pagefind search ONLY works after `pnpm build`.** In dev mode, search shows fake results. Test search with `pnpm build && pnpm preview`.
- **Site config language uses underscores** (`zh_CN`, `zh_TW`). Layout.astro converts to hyphens for the HTML `lang` attribute.
- **CSS variables for theming** are defined in `styles/variables.styl` (Stylus). The `define()` mixin generates light/dark pairs. The `--hue` variable controls the entire color scheme.
- **Biome ignores `src/config.ts`** for formatting — it's user-editable and the formatter shouldn't rearrange it.
- **Svelte 5** (runes mode) is used. Svelte components are `.svelte` files, NOT `.svelte.js` or `.svelte.ts`.
- **TypeScript path aliases** are configured in `tsconfig.json`: `@components/*`, `@constants/*`, `@utils/*`, `@i18n/*`, `@layouts/*`, `@/*`. Use these in imports to avoid fragile relative paths.

## Framework quirks

### Swup page transitions
- Swup animates page transitions. The animation class prefix is `transition-swup-` (not `transition-`) to avoid conflict with Tailwind's `transition-*` classes.
- Swup requires special handling for JS that reinits on navigation. See Layout.astro's `content:replace` / `page:view` hooks for the pattern (scrollbars, photoswipe, etc.).
- `window.swup` is typed incorrectly by `@swup/astro`; the global type override is in `src/global.d.ts`.

### Astro Compress
- CSS and Image compression are **disabled** in the Compress integration. Don't add them back.
- There's a workaround for an upstream bug: `Action.Passed: async () => true` is required.

### Rollup dynamic import warning
- A specific import-order warning is suppressed in `astro.config.mjs` (`"is dynamically imported by... but also statically imported by"`). Don't remove the suppression.

### Content collections
- Blog posts use `astro:content` with Zod validation (`src/content/config.ts`).
- Auto-generated types live in `.astro/types.d.ts`. If content schema changes, run `pnpm astro sync` to regenerate.

### Markdown plugins
Custom directives: `::github{repo="org/repo"}`, `::note`, `::tip`, `::important`, `::caution`, `::warning`.
These are processed by remark-directive + custom rehype components in `src/plugins/`.

## Deployment

### Primary: self-hosted Aliyun server via rsync

```bash
pnpm ship    # calls scripts/deploy.sh — builds dist/ then rsyncs to Aliyun
```

- Deploy script: `scripts/deploy.sh`
- SSH alias: `Aliyun` (override with `DEPLOY_HOST` env var)
- Remote path: `/srv/blog` (override with `DEPLOY_PATH` env var)
- Domain: **`https://lorenzofeng.top/`** (that's `.top`, NOT `.cc` — `.cc` is a legacy subdomain)
- CNAME: `public/CNAME` contains all domains served by the host

### Secondary: AtomGit Pages (CI)

- GitHub Actions (`.github/workflows/astro.yml`) deploys to AtomGit Pages from the `atomgit` branch on push. This is a **backup deployment** path.
- Dockerfile supports multi-stage build: `preview` (dev server) and `builder` + `uploader` (build and push to AtomGit Pages via git).

### Static files

Files placed in `public/` are copied as-is to the site root. Use this for:
- Domain verification files (e.g., `public/<hash>.txt`)
- `CNAME` (multi-domain config)

## Files you should NOT edit without context

- `src/config.ts` — site-wide configuration. Changes here affect all pages.
- `astro.config.mjs` — many integrations with careful ordering and workarounds.
- `src/styles/variables.styl` — the design token system. Changes affect every component.
- `src/layouts/Layout.astro` — 542 line file with deeply interconnected theme, scroll, animation, lightbox, and Swup logic.
