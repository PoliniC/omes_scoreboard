Config = Config or {}

local CFX_API_URL = ("https://servers-frontend.fivem.net/api/servers/single/%s"):format(Config.CfxJoinCode)
local CACHE = { players = {}, last_ok = 0 }
local REFRESH_MS = 180000
local fetching = false

local function UpdateCfxCache()
    if fetching then return end
    fetching = true
    PerformHttpRequest(CFX_API_URL, function(status, body)
        if status == 200 and body and body ~= "" then
            local ok, decoded = pcall(json.decode, body)
            if ok and decoded and decoded.Data and decoded.Data.players then
                local out = {}
                for _, p in ipairs(decoded.Data.players) do
                    out[#out+1] = {
                        id = tostring(p.id),
                        name = p.name or ("player_" .. tostring(p.id)),
                        ping = tonumber(p.ping) or -1
                    }
                end
                CACHE.players = out
                CACHE.last_ok = GetGameTimer()
            end
        end
        fetching = false
    end, "GET")
end

CreateThread(function()
    UpdateCfxCache()
    while true do
        Wait(REFRESH_MS)
        UpdateCfxCache()
    end
end)

RegisterNetEvent('omes_scoreboard:requestPings')
AddEventHandler('omes_scoreboard:requestPings', function()
    local src = source
    if #CACHE.players == 0 or (GetGameTimer() - CACHE.last_ok) > (REFRESH_MS + 5000) then
        UpdateCfxCache()
    end
    local compact = {}
    for _, p in ipairs(CACHE.players) do
        compact[#compact+1] = { id = p.id, ping = p.ping }
    end
    TriggerClientEvent('omes_scoreboard:receivePings', src, compact)
end)

RegisterNetEvent('omes_scoreboard:requestAllPlayers')
AddEventHandler('omes_scoreboard:requestAllPlayers', function()
    local src = source
    if #CACHE.players == 0 or (GetGameTimer() - CACHE.last_ok) > (REFRESH_MS + 5000) then
        UpdateCfxCache()
    end
    local allPlayers = {}
    for _, p in ipairs(CACHE.players) do
        allPlayers[#allPlayers+1] = { id = p.id, name = p.name }
    end
    TriggerClientEvent('omes_scoreboard:receiveAllPlayers', src, allPlayers)
end)

local ESX, QBCore = nil, nil
if Config.Framework == "esx" then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.Framework == "qbcore" then
    QBCore = exports['qb-core']:GetCoreObject()
end

local function GetPlayersWithJobs()
    local playerJobs = {}
    if Config.Framework == "esx" and ESX then
        local xPlayers = ESX.GetPlayers()
        for _, playerId in ipairs(xPlayers) do
            local xPlayer = ESX.GetPlayerFromId(playerId)
            if xPlayer then
                playerJobs[tostring(playerId)] = {
                    job = xPlayer.job.name,
                    jobGrade = xPlayer.job.grade
                }
            end
        end
    elseif Config.Framework == "qbcore" and QBCore then
        for _, playerId in ipairs(GetPlayers()) do
            local Player = QBCore.Functions.GetPlayer(tonumber(playerId))
            if Player then
                playerJobs[tostring(playerId)] = {
                    job = Player.PlayerData.job.name,
                    jobGrade = Player.PlayerData.job.grade.level
                }
            end
        end
    end
    return playerJobs
end

RegisterNetEvent('omes_scoreboard:requestJobs')
AddEventHandler('omes_scoreboard:requestJobs', function()
    local src = source
    local playerJobs = GetPlayersWithJobs()
    TriggerClientEvent('omes_scoreboard:receiveJobs', src, playerJobs)
end)
