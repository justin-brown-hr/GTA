-- Permanent pause-map blips for Heartless City (elite Cali RP — clean labels, not clutter spam)
local blips = {}

local function addBlip(coords, sprite, colour, scale, label)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, sprite)
    SetBlipDisplay(b, 4) -- main map + minimap
    SetBlipScale(b, scale or 0.75)
    SetBlipColour(b, colour)
    SetBlipAsShortRange(b, false) -- visible on pause map across the city
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(b)
    blips[#blips + 1] = b
    return b
end

-- Shared helper for other hc-* resources
exports('AddCityBlip', addBlip)

CreateThread(function()
    -- Landmarks / MLO areas (approx entrance coords)
    addBlip(vec3(4840.8, -5174.6, 2.1), 310, 1, 0.85, 'HC Island / Deadzone')
    addBlip(vec3(-56.8, -1096.6, 26.4), 326, 3, 0.8, 'HC Public Motors')
    addBlip(vec3(-783.5, -212.5, 37.0), 326, 5, 0.8, 'HC Exclusive Collection')
    addBlip(vec3(-552.6, -585.4, 34.7), 52, 0, 0.75, 'HC La Galeria Mall')
    addBlip(vec3(-365.5, -131.5, 38.7), 72, 5, 0.7, 'HC Customs / LSC')
    addBlip(vec3(-430.1, -23.5, 46.2), 93, 8, 0.75, 'HC Galaxy Club')
    addBlip(vec3(-1253.5, -1483.6, 4.3), 93, 2, 0.7, 'HC Limeys')
    addBlip(vec3(1273.4, -3166.8, 5.9), 310, 1, 0.8, 'HC Deadzone Gate')
end)

-- Reliable inventory open (ox_inventory) — F2
CreateThread(function()
    Wait(1500)
    if GetResourceState('ox_inventory') ~= 'started' then return end
    lib.addKeybind({
        name = 'hc_open_inventory',
        description = 'Open Heartless inventory',
        defaultKey = 'F2',
        onPressed = function()
            if LocalPlayer.state.invOpen then
                exports.ox_inventory:closeInventory()
            else
                exports.ox_inventory:openInventory('player')
            end
        end,
    })
end)

RegisterCommand('inv', function()
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:openInventory('player')
    end
end, false)

RegisterCommand('inventory', function()
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:openInventory('player')
    end
end, false)
