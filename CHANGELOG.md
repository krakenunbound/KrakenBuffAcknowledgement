# 2.3.18 — Zoning, RP and typing timing

- Carry prior buff-pool history across zone transfers, including delayed aura restoration and changed instance IDs. Readable aura application age also suppresses old restoration after loading. Restoration suppression is bounded by the old aura expiration when readable, otherwise 180 seconds; genuinely fresh buffs after that bound can be thanked.
- Treat name API returns as documented unitName/unitServer: preserve the full first-and-last string and punctuation, append a distinct remote server only as a realm suffix, never manufacture a surname. Incomplete/secret primary names stay unresolved; a readable full primary name survives an unreadable server field; live diagnostics flag unexpected name layouts. Group/guild checks retain full names, and queued/cooldown identity uses a readable GUID where available.
- Bind pending identity resolution to its initially readable caster GUID; preserve immutable recipient name/GUID snapshots through the typing delay. Caster selection and vanished unit tokens are not needed when direct aura identity is readable.
- Add `/kba options` and an addon Settings panel for fixed/random typing delay, random range, spacing between replies and per-player cooldown. Preserve saved fixed delays, including four-second legacy values. New defaults are fixed ten seconds, random range eight–fourteen seconds when selected, and three-second spacing.
- Start a full typing pause after identity is resolved, and serialize simultaneous responses through the gap. Delayed recipient resolution cannot turn the default response into an instant reply.
- Keep cooldown independent of typing delay. Zoning cancels queued replies; current pending replies retain their chosen typing delay after options changes.
- Preserve correct existing RP text. Split Water Walking from underwater breath effects, and Divine Spirit from mana-oriented Blessing of Wisdom. Occasional recipient voice fragments can now use verified player class; giver class is never guessed from a spell or scroll. Rank mappings are covered by the mock harness.
- Add `offline_harness_v17.lua` for settings, mapping, login/reload/late-restoration, updated-aura dedupe, typing bounds, send gap, cooldown and canceled callback cases. Independent 21-case regressions and supplied harnesses passed cloud Lua 5.3/5.4 testing; see TEST-RESULTS.md for mock limitations and test-only fixture corrections. Live client verification remains pending.

# 2.3.16 — Forever maintenance build

- Resolve readable player aura caster GUIDs and names without requiring sourceUnit; retain safe unit fallback. Existing RP content and WHISPER channel are unchanged.
- Nearby-cast, tooltip text and targeting-only guesses no longer select automatic recipients; unresolved identity is skipped rather than risking a misaddressed whisper.
- Explicitly secret/restricted or non-player authoritative caster GUIDs cannot be replaced with a different readable source-token player.
- Known caster GUIDs with unreadable names are not replaced by speculative recipients.
- Resolve updated aura instances without resetting handled-gift deduplication.
- Cancel pending work on leaving world; use five-second minimum loading baseline, one-second aura quiet period, and final silent snapshot. Genuine buffs received during settling are intentionally suppressed.
- Bound unresolved caster retries to 180 seconds. No automatic chat retransmission or name-spelling retry.
- Show API attempts, errors, matched outgoing echoes, and unknown outcomes separately with /kba diagnose. An outgoing echo is not confirmation that the recipient received the message.
- Apply at least three seconds of per-player attempt throttling, including failed API calls. Keep handled gifts deduplicated to avoid floods.

Offline verification: all Lua files syntax-parsed with installed luaparser; structural regression checks passed. Runtime harness supplied but not executed because no Lua runtime is installed. Server maintenance prevented live verification. Compatibility improvement and root-cause hypothesis remain unconfirmed until live testing.

Sources: Forever 1.60.1.70124 UI/API mirror, https://github.com/Gethe/wow-ui-source/tree/forever ; caster lookup precedent, https://github.com/DjSinestro1/forever_thanks ; combat-log availability evidence, https://github.com/GudaAddons/HeadHunter/blob/main/Detection/ForeverDeaths.lua .
