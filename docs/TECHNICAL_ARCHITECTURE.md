# Pocket Habitat — Technical Architecture

## Architecture Overview
Pocket Habitat follows a strict **Client-Server Architecture** with **Server-Authoritative** state management. All critical actions—such as resource harvesting, planting, quest completion, currency rewards, inventory updates, and purchases—are validated and processed on the server to prevent exploitation and ensure data integrity.

## Directory & Module Structure
- **Server (`src/server`)**:
  - `ServerMain.server.luau`: Entry point for server initialization.
  - `Systems/`: Server-side simulation systems (DataStoreManager, EconomyManager, InventoryManager, QuestManager, CreatureManager, PlantManager).
- **Shared (`src/shared`)**:
  - `Data/`: Static configuration tables (ItemDefs, PlantDefs, CreatureDefs, QuestDefs).
  - `Network/`: RemoteEvent and RemoteFunction definitions and wrappers.
  - `Utils/`: Common utility math and helper functions.
- **Client (`src/client`)**:
  - `ClientMain.client.luau`: Entry point for client initialization.
  - `Controllers/`: UI controllers, input handlers, and audio/visual feedback managers.
- **Assets (`assets/runtime`)**:
  - Low-poly models, prefabs, particles, and sounds stored in ServerStorage during runtime.

## Data Persistence & Security (Planned Requirements)
The following are required design constraints; they are not implemented or verified yet:
- **DataStores**: Add versioned player data, safe migrations, retry logic with bounded backoff, and clear failure handling.
- **Multiplayer Isolation**: Key player records by `UserId` and prevent cross-player state changes or save races.
- **Client Validation**: Treat the client as presentation/input only. Validate requests, ownership, distance, cooldowns, and rewards on the server before mutating state.

## Implementation Status
This document describes the intended architecture. It does not claim the listed managers, persistence layer, network wrappers, or gameplay systems already exist.
