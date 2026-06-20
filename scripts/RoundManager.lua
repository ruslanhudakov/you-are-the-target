-- Server: RoundManager.lua
-- Place in ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- RemoteEvents (create these in ReplicatedStorage):
-- SetTarget (OnClientEvent with Player), ClearTarget, RoundTimerUpdate, TargetKilled (OnServerEvent from clients when target dies)

local SetTargetEvent = ReplicatedStorage:FindFirstChild("SetTarget")
local ClearTargetEvent = ReplicatedStorage:FindFirstChild("ClearTarget")
local RoundTimerUpdate = ReplicatedStorage:FindFirstChild("RoundTimerUpdate")
local TargetKilled = ReplicatedStorage:FindFirstChild("TargetKilled")

assert(SetTargetEvent and ClearTargetEvent and RoundTimerUpdate and TargetKilled, "Missing RemoteEvents in ReplicatedStorage. Create SetTarget, ClearTarget, RoundTimerUpdate, TargetKilled.")

local ROUND_NORMAL = 30 -- спокойствие
local ROUND_HUNT = 30   -- охота
local CHOOSE_TIME = 5   -- время показа "PLAYER IS THE TARGET"

local currentTarget = nil
local roundState = "idle" -- idle, preselect, hunt

local function broadcastTimer(seconds, phase)
    RoundTimerUpdate:FireAllClients(seconds, phase)
end

local function clearTarget()
    if currentTarget then
        ClearTargetEvent:FireAllClients()
        currentTarget = nil
    end
end

local function chooseRandomPlayer()
    local list = {}
    for _,p in pairs(Players:GetPlayers()) do
        if p and p.Character and p.Character:FindFirstChildOfClass("Humanoid") then
            table.insert(list, p)
        end
    end
    if #list == 0 then return nil end
    return list[math.random(1,#list)]
end

local function giveBuffs(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local origSpeed = humanoid.WalkSpeed
        local origJump = humanoid.JumpPower or humanoid.JumpHeight
        local buffSpeed = origSpeed + 6
        local buffJump = (origJump or 50) + 10

        humanoid.WalkSpeed = buffSpeed
        if humanoid.JumpPower then humanoid.JumpPower = buffJump end

        -- rollback later
        delay(ROUND_HUNT + 5, function()
            if humanoid and humanoid.Parent then
                humanoid.WalkSpeed = origSpeed
                if humanoid.JumpPower and origJump then humanoid.JumpPower = origJump end
            end
        end)
    end
end

-- Listen for TargetKilled event from clients (trust model: clients must signal server)
TargetKilled.OnServerEvent:Connect(function(player, killer)
    -- player is the client who fired the event (the killer in some designs)
    -- Use server-side validation if you track damage server-side
    print("TargetKilled event from", player and player.Name, "killer:", killer and killer.Name)
    -- Reward logic here: grant coins/xp to killer, end round early if target died
    clearTarget()
end)

-- Основной цикл раундов
spawn(function()
    while true do
        roundState = "normal"
        for t=ROUND_NORMAL,1,-1 do
            broadcastTimer(t, roundState)
            wait(1)
        end

        roundState = "preselect"
        broadcastTimer(CHOOSE_TIME, roundState)
        local chosen = chooseRandomPlayer()
        if chosen then
            currentTarget = chosen
            SetTargetEvent:FireAllClients(chosen)
            giveBuffs(chosen)
        end

        for t=CHOOSE_TIME,1,-1 do
            broadcastTimer(t, roundState)
            wait(1)
        end

        roundState = "hunt"
        for t=ROUND_HUNT,1,-1 do
            broadcastTimer(t, roundState)
            wait(1)
        end

        -- по окончанию раунда: проверяем жив ли target
        if currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChildOfClass("Humanoid")
            and currentTarget.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            -- цель выжила -> награда (реализуйте вашу экономику здесь)
            print(currentTarget.Name .. " survived the round")
        end

        clearTarget()
        wait(1)
    end
end)
