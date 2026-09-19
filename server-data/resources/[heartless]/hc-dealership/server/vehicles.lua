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

-- qb-garages vehicle states. A car must be written as GARAGED: qb-garages
-- treats OUT as "somewhere in the world", so an OUT car that never actually
-- spawned cannot be taken out of the garage — and on every restart qb-garages
-- puts a depot fee on all OUT cars. It is only flipped to OUT once it exists.
local STATE_OUT, STATE_GARAGED = 0, 1

--- Write a car into a character's garage.
--- Takes raw license/citizenid so it works for players who are not online.
--- Returns false if the insert failed, so the caller can refund or retry
--- instead of silently pocketing the purchase.
---@return boolean
function HCInsertVehicle(license, citizenid, model, plate, garage)
    local ok, err = pcall(function()
        MySQL.insert.await(
            'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            { license, citizenid, model, joaat(model), '{}', plate, garage or Config.DefaultGarage, STATE_GARAGED }
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

--[[
    Spawn a purchased vehicle in the world from the SERVER.

    The client used to CreateVehicle itself. Server-side creation keeps this
    resource working under entity lockdown, and the server controls exactly
    what is spawned and where. Keys are granted server-side too.

    `vtype` must match the model (automobile / bike / boat / heli / plane /
    trailer) or the vehicle spawns broken — it comes from Config.

    Returns the network id, or nil if the spawn failed (the car is still in the
    player's garage in that case — it was written to player_vehicles first).
]]
---@return integer|nil
function HCSpawnOwnedVehicle(src, model, vtype, coords, plate)
    local veh = CreateVehicleServerSetter(joaat(model), vtype or 'automobile', coords.x, coords.y, coords.z, coords.w or 0.0)
    for _ = 1, 100 do
        if DoesEntityExist(veh) then break end
        Wait(10)
    end
    if not DoesEntityExist(veh) then
        print(('^1[hc-dealership]^7 could not spawn %s for %s'):format(model, src))
        return nil
    end
    SetVehicleNumberPlateText(veh, plate)
    -- It is the player's car now: do not delete it when they walk away from it.
    SetEntityOrphanMode(veh, 2)
    exports['qb-vehiclekeys']:GiveKeys(src, plate)
    -- It really is out in the world now, so the garage should say so.
    MySQL.update('UPDATE player_vehicles SET state = ? WHERE plate = ?', { STATE_OUT, plate })
    return NetworkGetNetworkIdFromEntity(veh)
end

--- Console diagnostic: run the same server-side spawn pipeline the dealership
--- uses (create, plate, orphan mode), report, then delete. Handy after adding
--- a car to the config. Needs no player online.
---   hc_dealer_spawntest <model> [type]
RegisterCommand('hc_dealer_spawntest', function(source, args)
    if source ~= 0 then return end
    local model, vtype = args[1], args[2]
    if not model then
        print('[hc-dealership] Usage: hc_dealer_spawntest <model> [automobile|bike|boat|heli|plane|trailer]')
        return
    end
    if not vtype then
        for _, list in ipairs({ Config.PublicLot.vehicles, Config.ExclusiveLot.vehicles }) do
            for _, v in ipairs(list) do
                if v.model:lower() == model:lower() then vtype = v.type end
            end
        end
    end
    vtype = vtype or 'automobile'
    CreateThread(function()
        local s = Config.PublicSpawn
        local veh = CreateVehicleServerSetter(joaat(model), vtype, s.x, s.y, s.z, s.w)
        for _ = 1, 100 do
            if DoesEntityExist(veh) then break end
            Wait(10)
        end
        if not DoesEntityExist(veh) then
            print(('[hc-dealership] spawntest FAILED: %s (%s) did not spawn'):format(model, vtype))
            return
        end
        SetVehicleNumberPlateText(veh, 'HCTEST01')
        SetEntityOrphanMode(veh, 2)
        Wait(500)
        print(('[hc-dealership] spawntest OK: %s as %s  netId=%s  plate=%q  modelMatches=%s'):format(
            model, vtype, NetworkGetNetworkIdFromEntity(veh), GetVehicleNumberPlateText(veh),
            tostring(GetEntityModel(veh) == joaat(model))))
        DeleteEntity(veh)
        Wait(200)
        print(('[hc-dealership] spawntest cleanup: exists after delete = %s'):format(tostring(DoesEntityExist(veh))))
    end)
end, true)
