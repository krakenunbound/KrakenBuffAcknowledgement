# 2.3.19 diagnostic candidate — not installed

The active client was observed running 1.60.1.70170 with v2.3.18. Installed matching/detection files matched the existing staging copy. No reload, gameplay or chat sends were performed.

The installed slash dispatcher includes `/kba diagnose`; bare `/kba` displays help. The three supplied screenshots were identified by parent visual review as ordinary help, not the diagnostic report. Local Library reads returned image pointers/OCR only; direct image download could not be authorized, so no local pixel interpretation was claimed.

This candidate adds a bounded, copyable multiline snapshot and event/filter/caster/queue counters. `/kba diagnose`, `/kba diag` and `/kba diagnostics` open the same window. Click the report, Ctrl+A then Ctrl+C. Opening does not clear diagnostic history or change settings. Only addon-generated decisions and relevant buff recipients are included, not private chat. No automatic sending.

MotW and Thorns rank/name mappings already exist. Receipt during the silent baseline, old/restored classification, already-handled refreshes, unreadable identity and cooldown remain possible explanations, not established causes of the reported incident.

Confirmed code-path gap awaiting a separately tested behavioral repair: unknown pools supplied only in updatedAuraInstanceIDs are ignored if indexed/direct scanning cannot expose them. A safe fix must distinguish genuinely fresh readable applications from restoration without resetting handled gifts. This candidate preserves aura-detection behavior; current screenshots establish Thorns detection and caster-name lookup expiry. The whitespace requirement is removed: documented unitName/unitServer engine identity is retained exactly, not reinterpreted as display first/surname. Full spaced names/punctuation remain intact; a distinct readable server is realm-qualified. A secret routing component with a single-token primary stays unresolved. Relevant readable API return snapshots make the actual layout reviewable without guesses.

All eight Lua files syntax-parse locally. Runtime mock tests and actual in-game window rendering remain pending. Do not reload before capturing the existing v2.3.18 `/kba diagnose` evidence.

Confirmed from parent screenshot review: Thorns was detected, repeated name-format rejection occurred, lookup expired; indexed scan had a secret-access error. Four attempts/echoes cannot be attributed to this druid without temporal evidence. Actual canonical target delivery on70170 still needs live verification.

Provenance: original2.3.15, backed-up2.3.16 and2.3.17 accepted a readable first API return. Our2.3.18 maintenance changes introduced the literal-space rejection; it was not in the user's original addon. This candidate corrects that regression. It also validates authoritative caster GUIDs even if UnitNameFromGUID is absent, preventing stale source-token fallthrough for NPC, restricted or failed GUID reads.
