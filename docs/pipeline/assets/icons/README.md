# Icon & asset system

## Policy (PM decision, 2026-06-18) — **hybrid**
- **App icon + illustrative art** (empty states, onboarding, marquee emblems, mascots) → generated with **GPT-Image-2** at **high quality**.
- **Tiny functional UI glyphs** (tab bar, buttons, drive L/R decals, etc.) → **vector / SF Symbols** so they stay sharp, tintable, and accessible.

## App icon — FINAL
- **Direction:** the "lit display cabinet" grid mark — a charcoal grid of niches with **one warmly-lit niche containing a car** (variant `v3-bold-contrast`).
- **Master:** `appicon/AppIcon-1024.png` (1024×1024). Exported sizes in `appicon/export/`.
- Candidates/explorations kept in `appicon/` and `appicon/refined/`.
- **Build note:** App Store / asset-catalog icons must be **opaque (no alpha)**; flatten the master onto its baked background at export time. Modern Xcode accepts a single 1024 universal icon.

## GPT-Image-2 recipe (reproduce / extend)
- Model `gpt-image-2`, OpenAI images API (`POST /v1/images/generations`), `quality:"high"`, `size:"1024x1024"`.
- Key: `OPENAI_API_KEY` in `~/.openai/keys.env` (dev-time asset generation only — NOT a product backend).
- `gpt-image-2` does **not** support `background:"transparent"` → **bake the background into the prompt**.
- App-icon prompts: state "no text/letters, full-bleed square, centered, reads at small sizes, no rounded corners (full square art)".
- Downscale 1024→smaller with `sips -Z <size>` for the asset catalog.
