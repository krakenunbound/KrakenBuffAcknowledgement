# After maintenance

1. Load Forever; confirm version 2.3.18 with `/kba`, then `/kba status` and `/kba diagnose`. Open `/kba options` to inspect fixed/random typing delay, gap between replies, and cooldown. Existing fixed-delay preferences are preserved. Keep debug off for normal self-buff filtering.
2. Wait at least five seconds after loading, and until aura updates settle. Have another player apply a whitelisted buff while you have no player selected. Wait the configured response delay. Confirm the recipient receives one RP whisper.
3. Inspect `/kba diagnose`: detection, direct GUID resolution, API attempt, outgoing echo or unknown outcome. Unknown is not evidence of delivery failure and does not trigger a resend.
4. Have the same player apply several buffs quickly; expect one queued response and cooldown suppression. Refresh an already handled buff; expect no new response until it has been removed and received again.
5. Test another player, self buff, group/guild exclusions, login with existing buffs, reload, portal and layer transition. Expect no thanks for restored old buffs; genuine buffs during baseline settling are intentionally ignored.
6. If a response is missing, copy the short `/kba diagnose` output and client build, with the test's buff, timing and whether the recipient saw a whisper. Avoid copying unrelated private chat.

7. Receive mage, druid, priest and paladin buffs at available ranks; verify the RP sensation fits the buff. Warlock/shaman breath and water effects use the existing breath pool. Race voice belongs to your character; the giver's class is not guessed or named.
8. Try fixed delay, then random mode with 8–14 seconds. Confirm a full typing pause after caster resolution, replies to different players at least three seconds apart, and independent same-player cooldown. Zone with a response pending and with old auras restored late; neither should cause a duplicate whisper.

Restore: close the game; copy files from the timestamped backup over this addon folder. SavedVariables were not modified by this maintenance patch.
