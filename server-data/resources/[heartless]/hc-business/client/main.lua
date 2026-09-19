CreateThread(function()
    for _, biz in ipairs(Config.Businesses) do
        local blip = AddBlipForCoord(biz.coords.x, biz.coords.y, biz.coords.z)
        SetBlipSprite(blip, 475)
        SetBlipScale(blip, 0.7)
        SetBlipColour(blip, 5)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(biz.label)
        EndTextCommandSetBlipName(blip)

        exports.ox_target:addBoxZone({
            coords = biz.coords,
            size = vec3(2.0, 2.0, 2.5),
            rotation = 0,
            options = {
                {
                    name = 'hc_biz_' .. biz.key,
                    icon = 'fa-solid fa-building',
                    label = 'Business desk — ' .. biz.label,
                    onSelect = function()
                        TriggerServerEvent('hc-business:server:openDesk', biz.key)
                    end,
                },
            },
        })

        if biz.stashCoords then
            exports.ox_target:addBoxZone({
                coords = biz.stashCoords,
                size = vec3(1.5, 1.5, 2.0),
                rotation = 0,
                options = {
                    {
                        name = 'hc_biz_stash_' .. biz.key,
                        icon = 'fa-solid fa-box',
                        label = 'Business stash',
                        onSelect = function()
                            TriggerServerEvent('hc-business:server:openStash', biz.key)
                        end,
                    },
                },
            })
        end
    end
end)

RegisterNetEvent('hc-business:client:showDesk', function(payload)
    local options = {}

    if not payload.owner then
        options[#options + 1] = {
            title = ('Buy for $%s'):format(payload.price),
            description = 'Purchase this business with bank money',
            onSelect = function()
                TriggerServerEvent('hc-business:server:buy', payload.key)
            end,
        }
    elseif payload.isOwner or payload.isEmployee then
        options[#options + 1] = {
            title = ('Balance: $%s'):format(payload.balance),
            description = payload.isOwner and 'You own this business' or 'You are an employee',
        }

        if payload.isOwner then
            options[#options + 1] = {
                title = 'Deposit $1000',
                description = 'Move bank money into the business',
                onSelect = function()
                    TriggerServerEvent('hc-business:server:deposit', payload.key, 1000)
                end,
            }
            options[#options + 1] = {
                title = 'Withdraw $1000',
                description = 'Move business money to your bank',
                onSelect = function()
                    TriggerServerEvent('hc-business:server:withdraw', payload.key, 1000)
                end,
            }
            options[#options + 1] = {
                title = 'Hire nearby player',
                description = ('Employees: %s / %s'):format(payload.employeeCount or 0, Config.MaxEmployees),
                onSelect = function()
                    local input = lib.inputDialog('Hire employee', {
                        { type = 'number', label = 'Server ID', required = true, min = 1 },
                    })
                    if input and input[1] then
                        TriggerServerEvent('hc-business:server:hire', payload.key, tonumber(input[1]))
                    end
                end,
            }
            options[#options + 1] = {
                title = 'Fire employee',
                description = 'Remove by server ID',
                onSelect = function()
                    local input = lib.inputDialog('Fire employee', {
                        { type = 'number', label = 'Server ID', required = true, min = 1 },
                    })
                    if input and input[1] then
                        TriggerServerEvent('hc-business:server:fire', payload.key, tonumber(input[1]))
                    end
                end,
            }
            options[#options + 1] = {
                title = 'Sell business',
                description = ('Sell back for 50%% = $%s'):format(math.floor(payload.price * 0.5)),
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = 'Sell ' .. payload.label,
                        content = 'This removes your ownership. Continue?',
                        centered = true,
                        cancel = true,
                    })
                    if confirm == 'confirm' then
                        TriggerServerEvent('hc-business:server:sell', payload.key)
                    end
                end,
            }
        end

        options[#options + 1] = {
            title = 'Open stash',
            onSelect = function()
                TriggerServerEvent('hc-business:server:openStash', payload.key)
            end,
        }
    else
        options[#options + 1] = {
            title = 'Owned by someone else',
            description = 'This business is not for sale',
        }
    end

    lib.registerContext({
        id = 'hc_business_desk',
        title = payload.label,
        options = options,
    })
    lib.showContext('hc_business_desk')
end)

RegisterNetEvent('hc-business:client:openStash', function(stashId)
    exports.ox_inventory:openInventory('stash', stashId)
end)
