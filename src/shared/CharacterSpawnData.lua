--!strict

local CharacterSpawnData = {}

local function isFiniteNumber(value: any): boolean
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function CharacterSpawnData.isValidVector3(value: any): boolean
    if typeof(value) == "Vector3" then
        return true
    end
    if type(value) ~= "table" then
        return false
    end

    local x = value.x or value[1]
    local y = value.y or value[2]
    local z = value.z or value[3]
    return isFiniteNumber(x)
        and isFiniteNumber(y)
        and isFiniteNumber(z)
        and math.abs(x) <= 100000
        and math.abs(y) <= 100000
        and math.abs(z) <= 100000
end

function CharacterSpawnData.decodeVector3(value: any, fallback: Vector3): Vector3
    if typeof(value) == "Vector3" then
        return value
    end
    if not CharacterSpawnData.isValidVector3(value) then
        return fallback
    end

    return Vector3.new(value.x or value[1], value.y or value[2], value.z or value[3])
end

function CharacterSpawnData.encodeVector3(value: Vector3)
    return { x = value.X, y = value.Y, z = value.Z }
end

return CharacterSpawnData
