# Offline verification — 2.3.18

Independent cloud review executed the final production candidate under Lua 5.3 and Lua 5.4:

- 21/21 independent regression scenarios passed in both runtimes: loading/zone dedupe, changed aura IDs, delayed restoration, fresh buffs after old expiry, refresh dedupe, lookup expiry, authoritative secret/NPC identity refusal, retargeting, full names and separate queued identities.
- Expanded timing/options/rank/persona harness passed in both runtimes after a test-only clock correction: the original giver remained inside its legitimate 60-second cooldown. Production cooldown was not weakened.
- Original caster/echo/API-error/no-resend harness passed with its obsolete NPC assertion corrected to require the explicit blocked identity contract.
- All seven production Lua files compiled; package hashes were verified. Windows luaparser syntax and structural checks also passed.

These are mock-based approximations. Lua 5.3/5.4 execution does not reproduce the Forever client, its real secret-value enforcement, UI rendering or recipient chat delivery. Live testing on build 1.60.1.70124 remains required after maintenance.

Settings defaults: fixed typing delay 10 seconds; random range 8–14 seconds when selected; gap between replies 3 seconds; same-player cooldown 60 seconds. Valid saved fixed delays are preserved. Limits: fixed 0–120; random 1–120 with minimum <= maximum; gap 1–60; cooldown 0–3600. API attempts retain a minimum three-second same-player throttle even when a shorter cooldown is selected. Defaults never produce instant replies.

Use `/kba options` or the addon Settings category. Slash equivalents: `/kba typing fixed|random`, `/kba delay SECONDS`, `/kba range MIN MAX`, `/kba gap SECONDS`, `/kba cooldown SECONDS`. `/kba diagnose` shows recent decisions and attempted/echo/unknown counts. Current queued replies retain their chosen typing pause; zoning cancels them.

Canonical names use readable full `unitName`, preserve spaces/apostrophes/hyphens, and treat `unitServer` separately. Incomplete primary names remain unresolved. Giver class is not guessed; buff-appropriate sensations and verified recipient-class voice provide RP context.
