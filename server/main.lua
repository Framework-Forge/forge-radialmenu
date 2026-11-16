-- qb-amublancejob compatibility
RegisterNetEvent('hospital:server:SetDeathStatus', function(isDead)
    TriggerClientEvent('radialmenu:client:deadradial', source, isDead)
end)
