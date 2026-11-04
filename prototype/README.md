# Apocalypse 101 — playable prototype

A browser prototype of the PRD built with plain ES modules and [three.js](https://threejs.org) (vendored in `vendor/`, so it works offline). No build step, no dependencies to install.

## Run

```sh
cd prototype
python3 -m http.server 8000   # any static server works; ES modules need http://, not file://
```

Open http://localhost:8000.

## What's playable

- **Party selection**: choose 0–3 students, each with a major, clique, ATK/HP/DEF/INT and skills. Re-open the roster at the classroom whiteboard (also has a full-heal rest).
- **Exploration**: top-down, followers trail the teacher. The campus fence needs *everyone* to be able to jump. Dev and Tessa can't, so swap them out. No one gets left behind.
- **Collection**: scrap, cloth, medkits, energy drinks and four clues (journal: `J`).
- **Crafting**: tables in the classroom and the east quad. Priya lets the group craft anywhere (`C`). Gear unlocks skills and stats.
- **Combat**: turn-based, first-person. Pick an action and target for each party member. Skills carry a skill-based component: timing bar, button mashing or memory sequence. Stun, heal and buff skills are included. XP unlocks a second skill at level 2.

## Controls

| Action | Keyboard / mouse | Gamepad |
| --- | --- | --- |
| Move | WASD / arrows | Left stick |
| Interact, jump fence, minigame confirm | E / Space | A |
| Heal lowest-HP member | H | X |
| Craft anywhere | C | Y |
| Journal | J | Start |
| Combat menus | Click or number keys | (menus are mouse/keyboard only for now) |

## Layout

- `src/data.js`: students, skills, items, recipes, enemies, clues (tweak balance here)
- `src/main.js`: world, exploration, party/crafting UI, combat
