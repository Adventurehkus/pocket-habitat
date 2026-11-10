# Pocket Habitat — Monetization Plan

## Design principles
- Keep the core collection, planting, discovery, and progression loop enjoyable without spending Robux.
- Favor optional cosmetics and convenience over pay-to-win advantages.
- Explain every purchase clearly and avoid pressure-based or misleading purchase prompts.
- Do not invent asset, game-pass, or developer-product IDs.

## Possible game passes
- Additional cosmetic habitat themes and decoration sets.
- Extra creature display or habitat customization slots.
- Optional quality-of-life features that do not gate core progression.

## Possible developer products
- Clearly labeled optional resource bundles.
- Temporary, modest convenience boosts.
- Limited cosmetic or event bundles where appropriate.

## Implementation requirements
- Use MarketplaceService APIs from server-controlled code.
- Process developer product receipts on the server and make grants idempotent.
- Validate ownership and entitlement server-side.
- Configure real product IDs only after creating the products in Creator Dashboard.
- Keep all publishing and commerce credentials out of the AI coding workflow.

## Current status
This is a design proposal only. No passes, developer products, prices, or purchase flows have been created or verified.
