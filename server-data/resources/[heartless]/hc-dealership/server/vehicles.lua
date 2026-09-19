--[[
    Vehicle issuing helpers shared by the public lot and the Tebex grant queue.
    Globals (not exports) — these are internal to hc-dealership.
]]

--- A plate is the primary way QB identifies a car. Two cars sharing one plate
--- means keys, garages and impound all get confused — and if player_vehicles
--- has a unique index, the second INSERT fails and the buyer loses the money
--- they just paid. Keep drawing until we find one nobody owns.
---@return string|nil
function HCUniquePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    for _ = 1, 25 do
        local plate = 'HC'
        for _ = 1, 6 do
            local i = math.random(#chars)
            plate = plate .. chars:sub(i, i)
        end
        local taken = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
        if not taken then return plate end
    end
    return nil
end

--- Write a car into a character's garage.
--- Takes raw license/citizenid so it works for players who are not online.
--- Returns false if the insert failed, so the caller can refund or retry
--- instead of silently pocketing the purchase.
---@return boolean
function HCInsertVehicle(license, citizenid, model, plate, garage)
    local ok, err = pcall(function()
        MySQL.insert.await(
            'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            { license, citizenid, model, joaat(model), '{}', plate, garage or Config.DefaultGarage, 0 }
        )
    end)
    if not ok then
        print(('^1[hc-dealership]^7 vehicle insert failed for %s (%s): %s'):format(citizenid, model, err))
    end
    return ok
end

--- Convenience wrapper for an online QB player object.
---@return boolean
function HCGiveVehicle(Player, model, plate, garage)
    return HCInsertVehicle(Player.PlayerData.license, Player.PlayerData.citizenid, model, plate, garage)
end
