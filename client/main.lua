local config = pr_lib.load('@forge-radialmenu/config/client')
local radialReady = false

local function getPlayerData()
    return pr_lib.framework.GetPlayerData() or {}
end

local function hasSeatbelt()
    return pr_lib.cache.get("seatbelt", false) == true
end

local function removeOwnRootItems()
    pr_lib.removeRadialItem('vehicle')

    for i = 1, #config.menuItems do
        pr_lib.removeRadialItem(config.menuItems[i].id)
    end

    pr_lib.removeRadialItem('gangInteractions')
    pr_lib.removeRadialItem('jobInteractions')
    pr_lib.removeRadialItem('emergencybutton2')
end

-----------------------
------- Events --------
-----------------------

if config.vehicleSeats then
    pr_lib.onCache('vehicle', function(vehicle)
        if vehicle then
            setupVehicleMenu(true)
            local vehicleSeats = {}
            local veh = vehicle
            local amountOfSeats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))

            local seatTable = {
                [1] = locale('options.driver_seat'),
                [2] = locale('options.passenger_seat'),
                [3] = locale('options.rear_left_seat'),
                [4] = locale('options.rear_right_seat')
            }

            for i = 1, amountOfSeats do
                vehicleSeats[#vehicleSeats + 1] = {
                    id = 'vehicleSeat' .. i,
                    label = seatTable[i] or locale('options.other_seats'),
                    icon = 'caret-up',
                    onSelect = function()
                        if pr_lib.cache.get('vehicle') then
                            TriggerEvent('radialmenu:client:ChangeSeat', i,
                                seatTable[i] or locale('options.other_seats'))
                        else
                            RadialUtils.notify(locale('error.not_in_vehicle'), 'error')
                        end
                        pr_lib.hideRadial()
                    end
                }
            end

            pr_lib.registerRadial({
                id = 'vehicleSeatsMenu',
                items = vehicleSeats
            })
        else
            setupVehicleMenu(false)
        end
    end)

end

-----------------------
------ Functions ------
-----------------------

local function convert(tbl)
    if tbl.items then
        local items = {}
        for _, v in pairs(tbl.items) do
            items[#items + 1] = convert(v)
        end

        pr_lib.registerRadial({
            id = tbl.id .. 'Menu',
            items = items
        })

        return {
            id = tbl.id,
            label = tbl.label,
            icon = tbl.icon,
            menu = tbl.id .. 'Menu'
        }
    end

    local action
    if tbl.event then
        action = function()
            TriggerEvent(tbl.event, tbl.args or nil)
        end
    elseif tbl.serverEvent then
        action = function()
            TriggerServerEvent(tbl.serverEvent, tbl.args or nil)
        end
    elseif tbl.action then
        action = tbl.action(tbl.arg)
    elseif tbl.command then
        action = function()
            ExecuteCommand(tbl.command .. ' ' .. tbl.args)
        end
    end

    return {
        id = tbl.id,
        label = tbl.label,
        icon = tbl.icon,
        onSelect = tbl.onSelect or function()
            if action then
                action()
            end
        end,
        keepOpen = tbl.keepOpen
    }
end

function setupVehicleMenu(seat)
    -- Evita duplicar o menu ao atualizar o estado do veículo
    pr_lib.removeRadialItem('vehicle')

    local vehicleMenu = {
        id = 'vehicle',
        label = locale('options.vehicle'),
        icon = 'car',
        menu = 'vehicleMenu'
    }

    local vehicleItems = {
        {
            id = 'vehicle-flip',
            label = locale('options.flip'),
            icon = 'car-burst',
            onSelect = function()
                TriggerEvent('radialmenu:flipVehicle')
                pr_lib.hideRadial()
            end
        }
    }

    vehicleItems[#vehicleItems + 1] = convert(config.vehicleDoors)
    vehicleItems[#vehicleItems + 1] = convert(config.vehicleWindows)

    if config.enableExtraMenu then
        vehicleItems[#vehicleItems + 1] = convert(config.vehicleExtras)
    end

    if config.vehicleSeats and seat then
        vehicleItems[#vehicleItems + 1] = config.vehicleSeats
    end

    pr_lib.registerRadial({
        id = 'vehicleMenu',
        items = vehicleItems
    })

    pr_lib.addRadialItem(vehicleMenu)
end

local function setupRadialMenu()
    removeOwnRootItems()
    setupVehicleMenu()

    for _, v in pairs(config.menuItems) do
        pr_lib.addRadialItem(convert(v))
    end

    local playerData = getPlayerData()
    local gangName = playerData.gang and playerData.gang.name
    local jobName = playerData.job and playerData.job.name
    local onDuty = playerData.job and playerData.job.onduty

    if gangName and config.gangItems[gangName] then
        pr_lib.addRadialItem(convert({
            id = 'gangInteractions',
            label = locale('general.gang_radial'),
            icon = 'skull-crossbones',
            items = config.gangItems[gangName]
        }))
    end

    local jobItems = jobName and config.jobItems[jobName]
    if not jobItems and playerData.job and playerData.job.type == 'leo' then
        jobItems = config.jobItems.police
    end

    if jobName and onDuty and jobItems then
        pr_lib.addRadialItem(convert({
            id = 'jobInteractions',
            label = locale('general.job_radial'),
            icon = 'briefcase',
            items = jobItems
        }))
    end

    radialReady = true
end

local function isPolice()
    local job = getPlayerData().job
    return job and job.type == 'leo' and job.onduty
end

local function isEMS()
    local job = getPlayerData().job
    return job and job.type == 'ems' and job.onduty
end

-- Events
local function setDeathRadial(isDead)
    if isDead then
        local ispolice, isems = isPolice(), isEMS()
        if not ispolice or isems then
            return pr_lib.disableRadial(true)
        end
        removeOwnRootItems()
        pr_lib.addRadialItem({
            id = 'emergencybutton2',
            label = locale('options.emergency_button'),
            icon = 'circle-exclamation',
            onSelect = function()
                if ispolice then
                    TriggerEvent('police:client:SendPoliceEmergencyAlert')
                elseif isems then
                    TriggerServerEvent('hospital:server:emergencyAlert')
                end
                pr_lib.hideRadial()
            end
        })
    else
        setupRadialMenu()
        pr_lib.disableRadial(false)
    end
end

RegisterNetEvent('radialmenu:client:deadradial', setDeathRadial)

pr_lib.onCache('dead', function(isDead)
    setDeathRadial(isDead == true)
end)

RegisterNetEvent('radialmenu:client:ChangeSeat', function(id, label)
    local isSeatFree = IsVehicleSeatFree(pr_lib.cache.get('vehicle'), id - 2)
    local speed = GetEntitySpeed(pr_lib.cache.get('vehicle'))
    if hasSeatbelt() then
        return RadialUtils.notify(locale('error.race_harness_on'), 'error')
    end

    if not isSeatFree then
        return RadialUtils.notify(locale('error.seat_occupied'), 'error')
    end

    local kmh = speed * 3.6

    if kmh > 100.0 then
        return RadialUtils.notify(locale('error.vehicle_driving_fast'), 'error')
    end

    SetPedIntoVehicle(pr_lib.cache.get('ped', PlayerPedId()), pr_lib.cache.get('vehicle'), id - 2)
    RadialUtils.notify(locale('info.switched_seats', label))
end)

RegisterNetEvent('qb-radialmenu:trunk:client:Door', function(plate, door, open)
    if not pr_lib.cache.get('vehicle') then
        return
    end

    local pl = RadialUtils.getVehiclePlate(pr_lib.cache.get('vehicle'))
    if pl ~= plate then
        return
    end

    if open then
        SetVehicleDoorOpen(pr_lib.cache.get('vehicle'), door, false, false)
    else
        SetVehicleDoorShut(pr_lib.cache.get('vehicle'), door, false)
    end
end)

RegisterNetEvent('qb-radialmenu:client:noPlayers', function()
    RadialUtils.notify(locale('error.no_people_nearby'), 'error', 2500)
end)

RegisterNetEvent('qb-radialmenu:client:openDoor', function(id)
    local door = id
    local coords = GetEntityCoords(pr_lib.cache.get('ped', PlayerPedId()))
    local closestVehicle = pr_lib.cache.get('vehicle') or pr_lib.getClosestVehicle(coords, 5.0, false)
    if closestVehicle and closestVehicle ~= 0 then
        if closestVehicle ~= pr_lib.cache.get('vehicle') then
            local plate = RadialUtils.getVehiclePlate(closestVehicle)
            if GetVehicleDoorAngleRatio(closestVehicle, door) > 0.0 then
                if not IsVehicleSeatFree(closestVehicle, -1) then
                    TriggerServerEvent('qb-radialmenu:trunk:server:Door', false, plate, door)
                else
                    SetVehicleDoorShut(closestVehicle, door, false)
                end
            else
                if not IsVehicleSeatFree(closestVehicle, -1) then
                    TriggerServerEvent('qb-radialmenu:trunk:server:Door', true, plate, door)
                else
                    SetVehicleDoorOpen(closestVehicle, door, false, false)
                end
            end
        else
            if GetVehicleDoorAngleRatio(closestVehicle, door) > 0.0 then
                SetVehicleDoorShut(closestVehicle, door, false)
            else
                SetVehicleDoorOpen(closestVehicle, door, false, false)
            end
        end
    else
        RadialUtils.notify(locale('error.no_vehicle_found'), 'error', 2500)
    end
end)

RegisterNetEvent('forge-radialmenu:client:toggleWindows', function(id)
    local window = id
    local vehicle = pr_lib.cache.get('vehicle')

    if vehicle ~= false then
        if IsVehicleWindowIntact(vehicle, window) then
            RollDownWindow(vehicle, window)
        else
            RollUpWindow(vehicle, window)
        end
    else
        RadialUtils.notify(locale('error.no_vehicle_found'), 'error', 2500)
    end
end)

RegisterNetEvent('radialmenu:client:setExtra', function(id)
    local extra = id
    if pr_lib.cache.get('vehicle') ~= nil then
        if pr_lib.cache.get('seat') == -1 then
            SetVehicleAutoRepairDisabled(pr_lib.cache.get('vehicle'), true) -- Forces Auto Repair off when Toggling Extra [GTA 5 Niche Issue]
            if DoesExtraExist(pr_lib.cache.get('vehicle'), extra) then
                if IsVehicleExtraTurnedOn(pr_lib.cache.get('vehicle'), extra) then
                    RadialUtils.setVehicleExtra(pr_lib.cache.get('vehicle'), extra, false)
                    RadialUtils.notify(locale('error.extra_deactivated', extra), 'error', 2500)
                else
                    RadialUtils.setVehicleExtra(pr_lib.cache.get('vehicle'), extra, true)
                    RadialUtils.notify(locale('success.extra_activated', extra), 'success', 2500)
                end
            else
                RadialUtils.notify(locale('error.extra_not_present', extra), 'error', 2500)
            end
        else
            RadialUtils.notify(locale('error.not_driver'), 'error', 2500)
        end
    end
end)

RegisterNetEvent('radialmenu:flipVehicle', function()
    if pr_lib.cache.get('vehicle') then
        return
    end
    local coords = GetEntityCoords(pr_lib.cache.get('ped', PlayerPedId()))
    local vehicle = pr_lib.getClosestVehicle(coords)
    if not vehicle then
        return RadialUtils.notify(locale('error.no_vehicle_nearby'), 'error')
    end
    if pr_lib.progressBar({
        label = locale('progress.flipping_car'),
        duration = config.flipTime,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            mouse = false,
            combat = true
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped'
        }
    }) then
        SetVehicleOnGroundProperly(vehicle)
        RadialUtils.notify(locale('success.flipped_car'), 'success')
    else
        RadialUtils.notify(locale('error.cancel_task'), 'error')
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if pr_lib.cache.get('resource', GetCurrentResourceName()) ~= resource then
        return
    end

    CreateThread(function()
        local timeout = GetGameTimer() + 15000
        while GetGameTimer() < timeout do
            local playerData = getPlayerData()
            if playerData and (playerData.citizenid or playerData.job or playerData.gang) then
                break
            end
            Wait(250)
        end

        setupRadialMenu()
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if pr_lib.cache.get('resource', GetCurrentResourceName()) ~= resource then
        return
    end
    removeOwnRootItems()
    radialReady = false
end)

-- Sets the metadata when the player spawns
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    setupRadialMenu()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function()
    if not radialReady then
        setupRadialMenu()
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    pr_lib.removeRadialItem('jobInteractions')
    setupRadialMenu()
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
    pr_lib.removeRadialItem('jobInteractions')
    local playerData = getPlayerData()
    local jobName = playerData.job and playerData.job.name
    if onDuty and jobName and config.jobItems[jobName] then
        pr_lib.addRadialItem(convert({
            id = 'jobInteractions',
            label = locale('general.job_radial'),
            icon = 'briefcase',
            items = config.jobItems[jobName]
        }))
    end
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang)
    pr_lib.removeRadialItem('gangInteractions')
    if config.gangItems[gang.name] and next(config.gangItems[gang.name]) then
        pr_lib.addRadialItem(convert({
            id = 'gangInteractions',
            label = locale('general.gang_radial'),
            icon = 'skull-crossbones',
            items = config.gangItems[gang.name]
        }))
    end
end)

local function createQBExport(name, cb)
    AddEventHandler(('__cfx_export_qb-radialmenu_%s'):format(name), function(setCB)
        setCB(cb)
    end)
end

local function addOption(data, id)
    data.id = data.id or id and id
    pr_lib.addRadialItem(convert(data))
    return data.id
end

exports('AddOption', addOption)
createQBExport('AddOption', addOption)

local function removeOption(id)
    pr_lib.removeRadialItem(id)
end

exports('RemoveOption', removeOption)
createQBExport('RemoveOption', removeOption)
