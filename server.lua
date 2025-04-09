ESX = exports["es_extended"]:getSharedObject()


ESX.RegisterServerCallback('carlock:getKeys', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @owner', {
        ['@owner'] = xPlayer.identifier,
    }, function(data)
        cb(data)
    end)
end)

ESX.RegisterServerCallback('carlock:getKeys2', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.fetchAll('SELECT * FROM owned_vehicles2 WHERE owner = @owner', {
        ['@owner'] = xPlayer.identifier,
    }, function(data)
        cb(data)
    end)
end)

RegisterServerEvent('carlock:giveKeysServer')
AddEventHandler('carlock:giveKeysServer', function(id, plate)
    TriggerClientEvent('carlock:giveKeysClient', id, plate)
end)
