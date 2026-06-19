# Okami RPG — CLAUDE.md

iOS port of "The Catacombs of Margüento" web roguelike.

## Architecture

- **SpriteKit** (`GameScene.swift`) renders tiles, entities, effects via `SKCameraNode`
- **SwiftUI overlays** (HUD, controls, shop, rest screen, equipment) stacked on `SpriteView`
- **`@Observable GameState`** is the single source of truth — all logic mutates it directly
- **No async** — all game logic is synchronous, called on MainActor

## File map

| File | Role |
|------|------|
| `Game/Constants.swift` | Tile enum, floor names/pools, trap types, log types, narrations |
| `Game/EntityData.swift` | HeroClass, EquipItem, EnemyTemplate, CurseData, RelicData |
| `Game/GameState.swift` | @Observable GameState + all supporting structs |
| `Game/MapGenerator.swift` | BSP map gen, room placement, torches/traps/enemies |
| `Game/VisionSystem.swift` | Bresenham LOS, torch glow, trap detection, auto-aim |
| `Game/PathFinder.swift` | A* (200 iter limit) |
| `Game/CombatSystem.swift` | movePlayer, playerAttack, enemyTurns, skills, projectiles, traps |
| `Game/SaveManager.swift` | JSON encode/decode to UserDefaults |
| `Game/GameScene.swift` | SKScene: tile/entity/projectile nodes, damage floats, flash FX |
| `Utilities/AudioEngine.swift` | AudioServicesPlaySystemSound wrapper |
| `Utilities/HapticEngine.swift` | UIImpactFeedbackGenerator wrappers |
| `Utilities/AppSettings.swift` | UserDefaults keys (sfxMuted, hapticsEnabled) |
| `Utilities/Extensions.swift` | Color(hex:), UIColor(hex:) |
| `App/OkamiRPGApp.swift` | @main, auto-save on scenePhase change |
| `App/SplashView.swift` | Title / class select / dante screens |
| `App/GameContainerView.swift` | SpriteView + HUD + Controls + all overlays |
| `Views/HUDView.swift` | HP/XP bars, gold, log button, pause |
| `Views/ControlsView.swift` | Virtual D-pad + 3 skill buttons + shoot/wait/equip |
| `Views/RestScreenView.swift` | 4-dice rest screen between floors |
| `Views/EquipmentView.swift` | 7-slot equipment grid + relic list |
| `Views/ShopAltarView.swift` | Merchant shop + Dark Altar |
| `Views/GameOverView.swift` | Death / victory + run summary |

## Game constants

- Grid: 23×14 tiles, TILE_SIZE = 38pt
- 12 floors, 3 classes (warrior/mage/rogue), 15 enemy types
- Boss: Margüento on floor 12 (4 phases)
- Bundle ID: `com.Marguento.OkamiRPG`
- Team: VDGLR9P76K
- Deployment: iOS 17.6
