local isScoreboardOpen = false
local playerPings = {}
local playerJobs = {} -- Store all players' job information
local serverPlayerList = {} -- Store the server's complete player list
local scrollOffset = 0 -- Track scroll position
local ESX, QBCore = nil, nil

-- Initialize the appropriate framework
CreateThread(function()
    if Config.Framework == "esx" then
        ESX = exports['es_extended']:getSharedObject()
    elseif Config.Framework == "qbcore" then
        QBCore = exports['qb-core']:GetCoreObject()
    end
end)

-- Event to receive ping data from server
RegisterNetEvent('omes_scoreboard:receivePings')
AddEventHandler('omes_scoreboard:receivePings', function(players)
    -- Update ping data
    playerPings = {}
    for _, player in ipairs(players) do
        playerPings[tostring(player.id)] = player.ping
    end
end)

-- Event to receive job data from server
RegisterNetEvent('omes_scoreboard:receiveJobs')
AddEventHandler('omes_scoreboard:receiveJobs', function(jobs)
    playerJobs = jobs
end)

-- Event to receive complete player list from server
RegisterNetEvent('omes_scoreboard:receiveAllPlayers')
AddEventHandler('omes_scoreboard:receiveAllPlayers', function(players)
    serverPlayerList = players
end)

-- Function to get all players data
local function GetAllPlayers()
    -- Get players from server's complete list
    local players = {}
    
    for _, player in ipairs(serverPlayerList) do
        local serverID = player.id
        local strServerID = tostring(serverID)
        
        -- Get ping from stored values or set to 0 if not available
        local ping = playerPings[strServerID] or 0
        
        -- Get job info from server data or set to unknown
        local playerJob = "Unknown"
        local playerJobGrade = 0
        
        if playerJobs[strServerID] then
            playerJob = playerJobs[strServerID].job
            playerJobGrade = playerJobs[strServerID].jobGrade
        elseif NetworkIsPlayerActive(GetPlayerFromServerId(tonumber(serverID))) and GetPlayerFromServerId(tonumber(serverID)) == PlayerId() then
            -- Fallback to local data for current player if server data not available
            if Config.Framework == "esx" and ESX then
                local playerData = ESX.GetPlayerData()
                if playerData and playerData.job then
                    playerJob = playerData.job.name
                    playerJobGrade = playerData.job.grade
                end
            elseif Config.Framework == "qbcore" and QBCore then
                local playerData = QBCore.Functions.GetPlayerData()
                if playerData and playerData.job then
                    playerJob = playerData.job.name
                    playerJobGrade = playerData.job.grade.level
                end
            end
        end
        
        -- Add player to list
        table.insert(players, {
            id = serverID,
            name = player.name,
            ping = ping,
            job = playerJob,
            jobGrade = playerJobGrade
        })
    end
    
    -- Sort players by ID
    table.sort(players, function(a, b)
        return a.id < b.id
    end)
    
    return players
end

-- Function to request ping data from server
local function RequestPingData()
    TriggerServerEvent('omes_scoreboard:requestPings')
end

-- Function to request job data from server
local function RequestJobData()
    TriggerServerEvent('omes_scoreboard:requestJobs')
end

-- Function to request complete player list from server
local function RequestAllPlayers()
    TriggerServerEvent('omes_scoreboard:requestAllPlayers')
end

-- Function to toggle scoreboard
function ToggleScoreboard()
    isScoreboardOpen = not isScoreboardOpen
    
    if isScoreboardOpen then
        -- Reset scroll position when opening
        scrollOffset = 0
        
        -- Request data before showing scoreboard
        RequestPingData()
        RequestJobData()
        RequestAllPlayers()
        Citizen.Wait(100) -- Small delay to allow data to arrive
        
        -- Get players data and send to NUI
        local players = GetAllPlayers()
        
        -- Count players in each configured job (if enabled)
        local jobCounts = {}
        local jobConfigs = nil
        
        -- Only process jobs if the feature is enabled
        if Config.ShowJobs then
            jobConfigs = Config.DisplayedJobs
            
            -- Initialize all jobs with 0 count
            for _, jobConfig in ipairs(Config.DisplayedJobs) do
                jobCounts[jobConfig.name] = 0
            end
            
            -- Count players in each job
            for _, player in ipairs(players) do
                for _, jobConfig in ipairs(Config.DisplayedJobs) do
                    if player.job == jobConfig.name then
                        jobCounts[jobConfig.name] = jobCounts[jobConfig.name] + 1
                    end
                end
            end
        end
        
        SendNUIMessage({
            type = "showScoreboard",
            players = players,
            title = Config.ScoreboardTitle,
            position = Config.Position,
            largeMode = Config.LargeMode,
            showJobs = Config.ShowJobs,
            jobConfigs = jobConfigs,
            jobCounts = jobCounts
        })
    else
        -- Hide scoreboard
        SendNUIMessage({
            type = "hideScoreboard"
        })
    end
end

-- Key press to toggle scoreboard and handle controls
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        -- Toggle scoreboard key
        if IsControlJustPressed(0, Config.OpenKey) then
            ToggleScoreboard()
        end
        
        -- When scoreboard is open
        if isScoreboardOpen then
            -- Close scoreboard key
            if IsControlJustPressed(0, Config.OpenKey) then -- HOME key
                ToggleScoreboard()
            end
            
            -- Scroll with arrow keys
            -- Scroll up with UP ARROW
            if IsControlPressed(0, 172) then -- UP ARROW
                scrollOffset = scrollOffset - 5
                if scrollOffset < 0 then scrollOffset = 0 end
                SendNUIMessage({
                    type = "scroll",
                    offset = scrollOffset
                })
            end
            
            -- Scroll down with DOWN ARROW
            if IsControlPressed(0, 173) then -- DOWN ARROW
                scrollOffset = scrollOffset + 5
                SendNUIMessage({
                    type = "scroll",
                    offset = scrollOffset
                })
            end
        end
    end
end)

-- Refresh player list periodically when scoreboard is open
Citizen.CreateThread(function()
    while true do
        if isScoreboardOpen then
            -- Request latest data
            RequestPingData()
            RequestJobData()
            RequestAllPlayers()
            Citizen.Wait(100) -- Small delay to allow data to arrive
            
            local players = GetAllPlayers()
            
            -- Count players in each configured job (if enabled)
            local jobCounts = {}
            local jobConfigs = nil
            
            -- Only process jobs if the feature is enabled
            if Config.ShowJobs then
                jobConfigs = Config.DisplayedJobs
                
                -- Initialize all jobs with 0 count
                for _, jobConfig in ipairs(Config.DisplayedJobs) do
                    jobCounts[jobConfig.name] = 0
                end
                
                -- Count players in each job
                for _, player in ipairs(players) do
                    for _, jobConfig in ipairs(Config.DisplayedJobs) do
                        if player.job == jobConfig.name then
                            jobCounts[jobConfig.name] = jobCounts[jobConfig.name] + 1
                        end
                    end
                end
            end
            
            SendNUIMessage({
                type = "updatePlayers",
                players = players,
                title = Config.ScoreboardTitle,
                position = Config.Position,
                largeMode = Config.LargeMode,
                showJobs = Config.ShowJobs,
                jobConfigs = jobConfigs,
                jobCounts = jobCounts
            })
        end
        Citizen.Wait(Config.RefreshInterval) -- Update interval from config
    end
end)

-- Helper function to draw 3D text in the world
function Draw3DText(x, y, z, text, size)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    
    size = size or Config.MaxTextSize -- Default size from config
    
    SetTextScale(size, size)
    SetTextFont(Config.TextFont)
    SetTextProportional(1)
    SetTextColour(table.unpack(Config.TextColor))
    SetTextDropshadow(table.unpack(Config.TextDropShadow))
    SetTextEdge(table.unpack(Config.TextEdge))
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
end

-- Draw player IDs above heads when scoreboard is open
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if isScoreboardOpen and Config.ShowPlayerIDs then
            local players = GetActivePlayers()
            local myPed = PlayerPedId()
            local myCoords = GetEntityCoords(myPed)
            
            for _, id in ipairs(players) do
                local ped = GetPlayerPed(id)
                if DoesEntityExist(ped) then
                    local coords = GetEntityCoords(ped)
                    -- Calculate distance between players
                    local distance = #(myCoords - coords)
                    
                    -- Only show ID if player is within configured distance
                    if distance <= Config.MaxDisplayDistance then
                        local serverID = GetPlayerServerId(id)
                        -- Adjust text size based on distance (closer = bigger)
                        local textSize = Config.MaxTextSize * (1.0 - (distance / 20.0))
                        textSize = math.max(Config.MinTextSize, textSize) -- Don't let it get too small
                        
                        -- Calculate dynamic height offset based on distance
                        local heightOffset = Config.HeightOffsetBase
                        if distance > 5.0 then
                            -- Gradually increase height offset as distance increases
                            heightOffset = Config.HeightOffsetBase + (distance - 5.0) * Config.HeightOffsetFactor
                        end
                        
                        -- Draw ID above head with dynamic height offset
                        Draw3DText(coords.x, coords.y, coords.z + heightOffset, "ID: " .. serverID, textSize)
                    end
                end
            end
        else
            -- If scoreboard is closed, wait longer to save resources
            Citizen.Wait(500)
        end
    end
end)
