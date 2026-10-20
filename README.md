# Kraken Buff Acknowledgement

Kraken's automatic buff responder for World of Warcraft: Forever. It notices
supported player buffs and sends the giver a delayed, in-character thank-you
whisper, with buff-specific response pools and configurable timing/cooldowns.

Current version: **2.3.19**. The included manifests target Forever interface
**16001** (`camelot`). Compatibility with other clients/builds is unverified.
Restricted or unresolved caster identity can prevent a reply; diagnostic API
attempts/outgoing echoes do not prove that the recipient received a whisper.

## Installation

Download the repository ZIP, extract it, and rename the extracted addon folder
to **KrakenBuffAcknowledgement**. Put it in the intended client's
`Interface/AddOns` directory. The folder must directly contain
`KrakenBuffAcknowledgement.toc` and the Lua files, without an extra nested folder.
Enable the addon in WoW and restart the client if it was newly installed.

## Using it

- `/kba` or `/buffr` — command help.
- `/kba options` — timing and cooldown settings.
- `/kba status` — current configuration.
- `/kba on` / `/kba off` — enable or disable responses.
- `/kba typing fixed` / `/kba typing random` — typing-delay mode.
- `/kba delay 10` — fixed delay in seconds.
- `/kba range 8 14` — random typing-delay range.
- `/kba gap 3` — minimum gap between replies.
- `/kba cooldown 60` — same-player cooldown.
- `/kba excludegroup on` / `/kba excludeguild on` — exclude those players.
- `/kba plates on` / `/kba plates off` — friendly-nameplate assistance.
- `/kba diagnose` — copyable diagnostic snapshot.

The default fixed delay is 10 seconds, random range is 8–14 seconds, reply gap
is 3 seconds, and same-player cooldown is 60 seconds. Friendly-nameplate
assistance is enabled by default. `/kba test` sends a test whisper to another
targeted player; use it only when you intend to send that message.

Settings are stored locally in `DB_BuffResponder` through WoW SavedVariables.
Personal settings, account folders and live diagnostic exports are not included
in this repository. Exit WoW before copying SavedVariables to another client.

## Validation and maintenance

See [CHANGELOG.md](CHANGELOG.md), [LIVE-TEST.md](LIVE-TEST.md),
[LIVE-INVESTIGATION.md](LIVE-INVESTIGATION.md), and
[TEST-RESULTS.md](TEST-RESULTS.md) for existing maintenance notes. Some refer
to earlier versions and historical tests; they are not fresh verification of
this publication. The published Lua files were syntax-checked locally.
Live recipient delivery still needs in-game verification for the target build.

## License

The existing [LICENSE](LICENSE) is preserved: copyright 2026 tf4482,
all rights reserved unless otherwise explicitly stated.
