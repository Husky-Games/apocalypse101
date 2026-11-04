# Copilot instructions

## Project scope

This repository contains design documentation for *Apocalypse 101*, a party-based survival RPG, plus a playable browser prototype in `prototype/`. The README and [apocalypse101_prd.md](../apocalypse101_prd.md) are the source of product intent; the prototype is a vertical slice, not a settled architecture. Treat the PRD as the source of truth for gameplay requirements, and do not present unspecified mechanics or technical choices as settled.

## Build, test, and lint

The only code is the browser prototype in [prototype/](../prototype), a no-build static site (plain ES modules + three.js vendored in `prototype/vendor/`). There is no package manifest, linter, or automated test suite.

- Run: `cd prototype && python3 -m http.server 8000`, then open http://localhost:8000 (must be served over http, not `file://`).
- Game content (students, skills, items, recipes, enemies, clues) lives in `prototype/src/data.js`; world, exploration, UI, and combat logic are in `prototype/src/main.js`. `window.__game` exposes state for debugging.
- Do not edit `prototype/vendor/`; it is a copy of three.js.

## Game structure and gameplay

- The player character is a teacher leading a classroom of students after a disappearance. Before leaving the classroom, the player selects zero to three students; student attributes and skills shape the party.
- Exploration is primarily top-down, with cardinal-direction movement and party members following the teacher. The whole party must be able to pass an obstacle: if any member cannot, the group cannot proceed, so no one is left behind.
- The classroom is a home base with a crafting table. Players explore the campus to scavenge recovery and crafting items and clues; crafting tables also appear elsewhere, and an ability may allow crafting anywhere.
- Party members gain XP, unlock skills, and progress stats. Crafting can unlock gear and skills.
- Combat is turn-based and primarily first-person. The player chooses a target for each party member; attacks may use skill-based interactions and can deal damage, apply status effects, heal, or buff.
- The planned presentation is top-down for ordinary exploration, with first-person views for combat and selected NPC interactions or obstacles. Mouse/keyboard and game controller are planned input options.

## Product-specific conventions

- Use the PRD’s domain terms consistently: teacher/player character, student, party, classroom, campus, exploration, crafting, skill, and clue.
- Preserve the explicit party limits (zero to three students) and the all-members-must-pass exploration rule when implementing related flows.
- Keep the planned camera distinction clear: top-down is the primary view; first-person is for the specified special interactions. Do not assume every scene uses the same view.
- The PRD describes intended behavior, not an existing technical design. When a feature needs details the PRD does not specify, avoid silently hard-coding assumptions into shared systems; surface the decision for confirmation or document the agreed requirement.
