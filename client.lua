ESX = exports["es_extended"]:getSharedObject()

local localkeys = {}

-- Key Mapping for /togglecarlock
RegisterCommand("togglecarlock", function()
    toggle()
end, false)

RegisterKeyMapping('togglecarlock', 'Toggle Vehicle Lock', 'keyboard', 'G')



function toggle()
    ESX.TriggerServerCallback('carlock:getKeys', function(xKeys)
        check(xKeys, localkeys)
    end)
    ESX.TriggerServerCallback('carlock:getKeys2', function(xKeys)
        check(xKeys, localkeys)
    end)
end

function check(xKeys, localkeys)
    local near_veh = ESX.Game.GetClosestVehicle()
    local near_plate = ESX.Game.GetVehicleProperties(near_veh).plate
    if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(near_veh)) < Config.CheckDist then
        for _, v in pairs(localkeys) do
            if string.gsub(v.plate, "%s+", "") == string.gsub(near_plate, "%s+", "") then
                openVehicle(near_veh, v.label)
                return
            end
        end
        for _, v in pairs(xKeys) do
            if string.gsub(json.decode(v.vehicle).plate, "%s+", "") == string.gsub(near_plate, "%s+", "") then
                openVehicle(near_veh, GetLabelFromVehicle(json.decode(v.vehicle).model))
                return
            end
        end
    end
end

function openVehicle(vehicle, label)
    local dict = "anim@mp_player_intmenu@key_fob@"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Citizen.Wait(0) end

    if not IsPedInAnyVehicle(PlayerPedId(), true) then
        TaskPlayAnim(PlayerPedId(), dict, "fob_click_fp", 8.0, 8.0, -1, 48, 1, false, false, false)
    end

    local lockstate = GetVehicleDoorLockStatus(vehicle)
    ESX.ShowNotification((Config.Notify[lockstate][1]):format(label))

    if lockstate == 1 or lockstate == 0 then
        PlayVehicleDoorCloseSound(vehicle, 1)
        SetVehicleDoorsLocked(vehicle, 2)
        FlashLights(vehicle)
    elseif lockstate == 2 then
        PlayVehicleDoorOpenSound(vehicle, 0)
        SetVehicleDoorsLocked(vehicle, 1)
        FlashLights(vehicle)
    end
end

function FlashLights(vehicle)
    for i = 1, 2 do
        SetVehicleLights(vehicle, 2)
        Citizen.Wait(150)
        SetVehicleLights(vehicle, 0)
        Citizen.Wait(150)
    end
end

function GetLabelFromVehicle(vehicle)
    local vehicleLabel = GetDisplayNameFromVehicleModel(vehicle)
    return Config.ShowLuaName and GetLabelText(vehicleLabel) or vehicleLabel
end

RegisterCommand(Config.Command, function()
    openMainMenu()
end)

function openMainMenu()
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'main_menu', {
        title    = "🔑 Fahrzeugschlüssel",
        align    = 'top-left',
        css      = 'autoschlussel',
        elements = {
            {label = "🚨 Gestohlene Fahrzeuge", value = "manage_own_vehicles"},
            {label = "🚗 Eigene Fahrzeuge", value = "manage_stolen_vehicles"},
            {label = "🗝️ Schlüssel stehlen", value = "steal_key"}
        }
    }, function(data, menu)
        if data.current.value == "manage_own_vehicles" then
            openOwnVehicles()
        elseif data.current.value == "manage_stolen_vehicles" then
            openStolenVehicles()
        elseif data.current.value == "steal_key" then
            stealKey()
        end
    end, function(data, menu)
        menu.close()
    end)
end

-- Open Own Vehicles
function openOwnVehicles()
    ESX.TriggerServerCallback('carlock:getKeys', function(xKeys)
        local elements = {}

        -- Display local keys (owned vehicles)
        for _, v in pairs(localkeys) do
            table.insert(elements, {label = v.label .. " - " .. v.plate, value = v.plate})
        end

        table.insert(elements, {label = "❌ Gestohlene Schlüssel entsorgen", value = "delete_key"})

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'own_vehicle_menu', {
            title    = "🚨 Gestohlene Fahrzeuge",
            align    = 'top-left',
            css      = 'autoschlussel',
            elements = elements
        }, function(data, menu)
            if data.current.value == "delete_key" then
                removeStolenKey()
            else
                giveKey(data.current.value)
            end
        end, function(data, menu)
            menu.close()
        end)
    end)
end

-- Open Stolen Vehicles
function openStolenVehicles()
    ESX.TriggerServerCallback('carlock:getKeys', function(xKeys)
        local elements = {}

        -- Display stolen vehicle keys fetched from server
        for _, v in pairs(xKeys) do
            table.insert(elements, {label = GetLabelFromVehicle(json.decode(v.vehicle).model) .. " - " .. json.decode(v.vehicle).plate, value = json.decode(v.vehicle).plate})
        end

        -- Display local stolen keys (keys that have been stolen but not disposed of)
        for _, v in pairs(localkeys) do
            table.insert(elements, {label = v.label .. " - " .. v.plate, value = v.plate})
        end

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'stolen_vehicle_menu', {
            title    = "🚗 Eigene Fahrzeuge",
            css      = 'autoschlussel',
            align    = 'top-left',
            elements = elements
        }, function(data, menu)
            giveKey(data.current.value)
        end, function(data, menu)
            menu.close()
        end)
    end)
end

function stealKey()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        local label = GetLabelFromVehicle(GetEntityModel(vehicle))
        local plate = ESX.Game.GetVehicleProperties(vehicle).plate
        local exist = false

        -- Check if key is already stolen
        for _, v in pairs(localkeys) do
            if v.plate == plate then
                exist = true
            end
        end

        if not exist then
            table.insert(localkeys, {label = label, plate = plate})
            ESX.ShowNotification("✅ Du hast den Schlüssel gestohlen!")
        else
            ESX.ShowNotification("❌ Du besitzt den Schlüssel bereits!")
        end
    else
        ESX.ShowNotification("❌ Du sitzt in keinem Fahrzeug!")
    end
end

RegisterCommand("stealKey", function()
    stealKey()
end)

function removeStolenKey()
    local elements = {}

    -- List all stolen keys (local stolen keys)
    for k, v in pairs(localkeys) do
        table.insert(elements, {label = v.label .. " - " .. v.plate, value = k})
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'deleteKey', {
        title    = "❌ Schlüssel entsorgen",
        css      = 'autoschlussel',
        align    = 'top-left',
        elements = elements
    }, function(data, menu)
        table.remove(localkeys, data.current.value)
        ESX.ShowNotification("✅ Schlüssel wurde entsorgt!")
        menu.close()
    end, function(data, menu)
        menu.close()
    end)
end

function giveKey(plate)
    local closestPlayer, closestPlayerDistance = ESX.Game.GetClosestPlayer()
    if closestPlayer ~= -1 and closestPlayerDistance < 3.0 then
        TriggerServerEvent('carlock:giveKeysServer', GetPlayerServerId(closestPlayer), plate)
        ESX.ShowNotification("✅ Schlüssel übergeben!")
    else
        ESX.ShowNotification("❌ Kein Spieler in der Nähe!")
    end
end



RegisterNetEvent("esx_vehiclelock:lockpick")
AddEventHandler("esx_vehiclelock:lockpick", function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = GetClosestVehicle(coords, 4.0, 0, 71)

    if not DoesEntityExist(vehicle) then
        ESX.ShowNotification("~r~Kein Fahrzeug in der Nähe!")
        return
    end

    TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_WELDING", 0, true)
    Citizen.Wait(2000)
    ClearPedTasksImmediately(playerPed)

    if lib.progressCircle({
        duration = 2000,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true },
    }) then
        SetVehicleDoorsLocked(vehicle, 1)
        PlayVehicleDoorOpenSound(vehicle, 0)
        ESX.ShowNotification("~g~Fahrzeug erfolgreich geknackt!")
    else
        ESX.ShowNotification("~r~Lockpicking abgebrochen!")
    end
end)
