# Icon & asset system

## Policy (PM decision, 2026-06-18) — **hybrid**
- **App icon + illustrative art** (empty states, onboarding, marquee emblems, mascots) → generated with **GPT-Image-2** at **high quality**.
- **Tiny functional UI glyphs** (tab bar, buttons, drive L/R decals, etc.) → **vector / SF Symbols** so they stay sharp, tintable, and accessible.

## App icon — FINAL
- **Direction:** the "lit display cabinet" mark — a **2×2** charcoal grid of glass niches with **one warmly-lit niche containing a car** (final = `appicon/grid2x2/g2-br-glass.png`, lit bottom-right with glossy glass). Moved from 3×3 → 2×2 (PM, 2026-06-18) so the cells are roomier and the car reads at small sizes.
- **Master:** `appicon/AppIcon-1024.png` (1024×1024). Exported sizes in `appicon/export/`.
- Candidates/explorations kept in `appicon/` (4 concepts), `appicon/refined/` (3 grid-marks, 3×3), and `appicon/grid2x2/` (3 final 2×2 variants).
- **Build note:** App Store / asset-catalog icons must be **opaque (no alpha)**; flatten the master onto its baked background at export time. Modern Xcode accepts a single 1024 universal icon.

## GPT-Image-2 recipe (reproduce / extend)
- Model `gpt-image-2`, OpenAI images API (`POST /v1/images/generations`), `quality:"high"`, `size:"1024x1024"`.
- Key: `OPENAI_API_KEY` in `~/.openai/keys.env` (dev-time asset generation only — NOT a product backend).
- `gpt-image-2` does **not** support `background:"transparent"` → **bake the background into the prompt**.
- App-icon prompts: state "no text/letters, full-bleed square, centered, reads at small sizes, no rounded corners (full square art)".
- Downscale 1024→smaller with `sips -Z <size>` for the asset catalog.
