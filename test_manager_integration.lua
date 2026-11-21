-- Minimal sanity check
local Constants = require("src/shared/Constants")
local EconomyRules = require("src/shared/EconomyRules")

print("Constants loaded:", Constants and "YES" or "NO")
print("EconomyRules loaded:", EconomyRules and "YES" or "NO")

if Constants and EconomyRules then
    print("Sanity check passed")
else
    print("Sanity check failed")
    os.exit(1)
end
