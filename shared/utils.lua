RadialUtils = {}

function RadialUtils.notify(message, kind, duration)
    return pr_lib.notify({
        description = message,
        type = kind or 'inform',
        duration = duration,
    })
end

function RadialUtils.getVehiclePlate(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    if not plate then return end
    return plate:gsub('^%s*(.-)%s*$', '%1')
end

function RadialUtils.setVehicleExtra(vehicle, extra, enabled)
    if not DoesExtraExist(vehicle, extra) then return false end
    SetVehicleExtra(vehicle, extra, not enabled)
    return true
end