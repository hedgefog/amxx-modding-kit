# 🛠️ AMX Mod X Modding Kit 🇺🇦

A powerful modular framework for **AMX Mod X** that provides ready-to-use game systems for building complex GoldSrc mods. Focus on game logic — not engine workarounds.

## ❔ Why Modding Kit?

- **Powerful & Flexible** — Pre-built systems for entities, weapons, roles, shops, and more
- **Easy to Maintain** — Unified API patterns and OOP-style architecture across all modules
- **Cross-Game** — Create mods that work across both **Counter-Strike** and **Half-Life**
- **Map Integration** — Custom entities can be placed directly through map editors

## 🔄 Requirements

- AMX Mod X **1.9+**
- ReAPI or Orpheu *(required by some APIs)*

## ⚙️ Available APIs

### Game Managers

| API | Description |
|-----|-------------|
| [🧸 Assets](./api/assets) | Resource management from JSON config files — models, sounds, sprites |
| [⏱️ Rounds](./api/rounds) | Round lifecycle, timing, win conditions, and events |
| [🛒 Shops](./api/shops) | In-game shops with items, balance systems, and access control |

### Custom Systems

| API | Description |
|-----|-------------|
| [♟️ Custom Entities](./api/custom-entities) | OOP-style custom entity API with methods, members, and inheritance |
| [🎭 Player Roles](./api/player-roles) | OOP-style role management API with methods, members and inheritance |
| [🔫 Custom Weapons](./api/custom-weapons) | OOP-style custom weapon API with methods, members, and inheritance |
| [🔄 Custom Events](./api/custom-events) | Simple event system to communicate between plugins |
| [🦸 Player Model](./api/player-model) | System to manage player model and custom animation |
| [🏃‍♂️ Player Effects](./api/player-effects) | Server-side particles system |
| [🎩 Player Cosmetics](./api/player-cosmetics) | Simple system to manage player cosmetics |
| [🔀 States](./api/states) | State machines with transitions, guards, and lifecycle hooks |

### Utilities

| API | Description |
|-----|-------------|
| [💥 Entity Force](./api/entity-force) | Physics forces, pushes, and momentum transfer |
| [🫳 Entity Grab](./api/entity-grab) | Pick up, carry, and throw entities |
| [🖱️ Entity Selection](./api/entity-selection) | RTS-style entity box selection |
| [🎥 Player Camera](./api/player-camera) | Custom camera views with smooth movement |
| [🎵 Player Music](./api/player-music) | MP3 music playback with duration detection and activity awareness |
| [👁️ Player Viewrange](./api/player-viewrange) | Per-player view distance control |
| [🥴 Player Dizziness](./api/player-dizziness) | Dizziness system |
| [📍 Waypoint Markers](./api/waypoint-markers) | 3D waypoint sprites with wall projection |
| [💫 Particles](./api/particles) | Custom particle effect system |

## 🔽 Download

- [Releases](https://github.com/Hedgefog/amxx-modding-kit/releases)

## 📝 License

This project is licensed under the [MIT License](./LICENSE).