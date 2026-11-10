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

## Data Persistence & Security
- **DataStores**: Uses versioned, safe DataStore persistence with retry logic, exponential backoff, and robust error handling.
- **Multiplayer Isolation**: Player data is strictly isolated per `UserId` session, preventing cross-player data pollution or race conditions.
- **Client Validation**: The client acts purely as a presentation and input collection layer; all requests are validated against server state before applying mutations.
