# Changelog

## 1.0.0

- Initial release for WoW: Forever (`Interface: 16001`).
- Adds animated 2D additive sparkles to open-world Rogue lockboxes, footlockers, and locked chests via Blizzard's GameObject Soft-Interact system.
- Curated database of Classic & Forever footlockers/practice lockboxes plus live tooltip inspection (`Requires Lockpicking (N)` / `Locked`) for custom WoW: Forever containers.
- Reads live Lockpicking skill via `C_SkillInfo` (including gear bonuses like Dark Leather Gloves `+5`).
- Supports Rogue Gold, Skill-Up Difficulty (orange/yellow/green/grey), and Custom Color modes, plus scale, intensity, offset, and skill-label options under **Options → AddOns → Lockbox Sparkles** and `/lbs`.
- Combat-safe GameObject CVar management with one-click restore; never touches `SoftTargetEnemy`, `SoftTargetFriend`, or `SoftTargetNameplateInteract`.
