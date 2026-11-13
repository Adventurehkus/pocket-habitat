--!strict
-- selene: allow(undefined_variable)

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")
local DataStoreManager = require(Server:WaitForChild("DataStoreManager"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterSpawnData =
    require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterSpawnData"))

return function()
    describe("Character spawn persistence", function()
        it("provides an isolated habitat-safe spawn default", function()
            local data = DataStoreManager.getDefaultData(12345)
            local spawnData = data.characterSpawnData

            expect(data.userId).to.equal(12345)
            expect(typeof(spawnData.position)).to.equal("Vector3")
            expect(spawnData.position).to.equal(Vector3.new(0, 5, 0))
            expect(spawnData.orientation).to.equal(Vector3.zero)
        end)

        it("creates independent mutable session defaults", function()
            local first = DataStoreManager.getDefaultData(12345)
            local second = DataStoreManager.getDefaultData(67890)

            first.inventory.wood = 1
            first.characterSpawnData.position = Vector3.new(10, 5, 10)

            expect(second.userId).to.equal(67890)
            expect(second.inventory.wood).to.equal(nil)
            expect(second.characterSpawnData.position).to.equal(Vector3.new(0, 5, 0))
        end)

        it("round-trips DataStore-safe numeric spawn coordinates", function()
            local source = Vector3.new(12.5, 6, -8)
            local serialized = CharacterSpawnData.encodeVector3(source)
            local restored = CharacterSpawnData.decodeVector3(serialized, Vector3.zero)

            expect(serialized.x).to.equal(12.5)
            expect(serialized.y).to.equal(6)
            expect(serialized.z).to.equal(-8)
            expect(restored).to.equal(source)
        end)

        it("rejects malformed or out-of-range stored coordinates", function()
            local fallback = Vector3.new(0, 5, 0)
            local malformed = CharacterSpawnData.decodeVector3({ x = 1, y = 2 }, fallback)
            local outOfRange =
                CharacterSpawnData.decodeVector3({ x = 100001, y = 2, z = 3 }, fallback)
            local notANumber =
                CharacterSpawnData.decodeVector3({ x = 0 / 0, y = 2, z = 3 }, fallback)

            expect(malformed).to.equal(fallback)
            expect(outOfRange).to.equal(fallback)
            expect(notANumber).to.equal(fallback)
        end)
    end)
end
