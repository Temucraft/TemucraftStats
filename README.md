# Temucraft Stats

All your stats at once in a panel next to the character window, for WoW 3.3.5a. No more picking stat groups from the two dropdowns.

Sections (click a title to fold it):

- General: health, mana (or rage, energy, runic power), the five stats, average item level
- Melee: damage, speed, attack power, hit, crit, expertise, armor penetration, haste
- Ranged: damage, speed, attack power, hit, crit, haste
- Spell: bonus damage (each school in the tooltip), bonus healing, hit, crit (each school in the tooltip), haste, penetration
- Defense: armor (damage reduction in the tooltip), defense, dodge, parry, block, block value, resilience
- Regen: mana every 5 seconds casting and not casting, or energy, rage or runic power per second

Hover any value for a tooltip that explains it, with the rating behind it. Buffed stats are green, debuffed ones red.

Options (Interface, AddOns, or `/tstats options`): show the panel, hide the default stat boxes and their dropdowns, show ratings next to percents, scale.

`/tstats` shows or hides the panel. `/tstats default` hides or shows the default stat boxes, `/tstats ratings`, `/tstats print` (every value to the chat), `/tstats reset`.

Written from scratch for Temucraft. MIT licence, see LICENSE.

## Tests

`lua5.1 tests/tstats_test.lua TemucraftStats` runs a plain Lua test with stubbed stat functions.
