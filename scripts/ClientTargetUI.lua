-- Client: ClientTargetUI.lua
-- Place this LocalScript in StarterPlayerScripts
-- Requirements in ReplicatedStorage: RemoteEvents named SetTarget, ClearTarget, RoundTimerUpdate

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SetTarget = ReplicatedStorage:WaitForChild("SetTarget")
local ClearTarget = ReplicatedStorage:WaitForChild("ClearTarget")
local RoundTimerUpdate = ReplicatedStorage:WaitForChild("RoundTimerUpdate")

-- CONFIG: replace these asset IDs
local ALARM_SOUND_ID = "rbxassetid://ALARM_ASSET_ID" -- replace with real id
local TARGET_PARTICLE_TEXTURE = "rbxassetid://CONFETTI_TEXTURE_ID"

-- GUI expectations:
-- StarterGui -> ScreenGui named TargetUI containing:
--  Banner (TextLabel) -- centered big text for "PLAYER IS THE TARGET!"
--  RedFlash (Frame) -- full-screen red panel, initially BackgroundTransparency = 1
--  TopArrow (Frame/ImageLabel) -- arrow UI at top-middle
--  RoundTimer (TextLabel)
-- If these don't exist, script will create simple fallback notifications.

local function findOrCreateGui()
    local gui = localPlayer:WaitForChild("PlayerGui")
    local screen = gui:FindFirstChild("TargetUI")
    if not screen then
        screen = Instance.new("ScreenGui")
        screen.Name = "TargetUI"
        screen.ResetOnSpawn = false
        screen.Parent = gui

        local banner = Instance.new("TextLabel")
        banner.Name = "Banner"
        banner.Size = UDim2.new(0.6,0,0.12,0)
        banner.Position = UDim2.new(0.2,0,0.2,0)
        banner.BackgroundTransparency = 0.5
        banner.TextScaled = true
        banner.Font = Enum.Font.SourceSansBold
        banner.TextColor3 = Color3.new(1,1,1)
        banner.Text = ""
        banner.Visible = false
        banner.Parent = screen

        local flash = Instance.new("Frame")
        flash.Name = "RedFlash"
        flash.Size = UDim2.new(1,0,1,0)
        flash.Position = UDim2.new(0,0,0,0)
        flash.BackgroundColor3 = Color3.new(1,0,0)
        flash.BackgroundTransparency = 1
        flash.ZIndex = 10
        flash.Parent = screen

        local timer = Instance.new("TextLabel")
        timer.Name = "RoundTimer"
        timer.Size = UDim2.new(0,0,0,0)
        timer.Position = UDim2.new(0.02,0,0.02,0)
        timer.Text = ""
        timer.TextColor3 = Color3.new(1,1,1)
        timer.TextScaled = true
        timer.BackgroundTransparency = 1
        timer.Parent = screen

        local arrow = Instance.new("ImageLabel")
        arrow.Name = "TopArrow"
        arrow.Size = UDim2.new(0.12,0,0.08,0)
        arrow.Position = UDim2.new(0.44,0,0,8)
        arrow.BackgroundTransparency = 1
        arrow.Image = "rbxassetid://" -- optionally set an asset
        arrow.Visible = false
        arrow.Parent = screen
    end
    return screen
end

local screenGui = findOrCreateGui()
local banner = screenGui:WaitForChild("Banner")
local redFlash = screenGui:WaitForChild("RedFlash")
local topArrow = screenGui:WaitForChild("TopArrow")
local timerLabel = screenGui:WaitForChild("RoundTimer")

local currentTarget = nil
local highlight = nil
local particle = nil

local function cameraShake(intensity, duration)
    intensity = intensity or 0.5
    duration = duration or 0.4
    local start = tick()
    local orig = camera.CFrame
    spawn(function()
        while tick() - start < duration do
            local dt = tick() - start
            local mag = intensity * (1 - dt/duration)
            local offset = Vector3.new((math.random()-0.5)*mag, (math.random()-0.5)*mag, (math.random()-0.5)*mag)
            camera.CFrame = orig * CFrame.new(offset)
            RunService.Heartbeat:Wait()
        end
        camera.CFrame = orig
    end)
end

local function playAlarm()
    local s = Instance.new("Sound")
    s.SoundId = ALARM_SOUND_ID
    s.Volume = 1
    s.Parent = camera
    s:Play()
    game:GetService("Debris"):AddItem(s, 5)
end

local function createHighlight(character)
    if not character then return end
    local h = Instance.new("Highlight")
    h.Adornee = character
    h.FillColor = Color3.fromRGB(255,80,80)
    h.OutlineColor = Color3.fromRGB(180,30,30)
    h.Parent = workspace
    return h
end

local function createParticleOverHead(character)
    local head = character:FindFirstChild("Head")
    if not head then return end
    local attachment = head:FindFirstChild("TargetParticleAttachment")
    if not attachment then
        attachment = Instance.new("Attachment")
        attachment.Name = "TargetParticleAttachment"
        attachment.Parent = head
        attachment.Position = Vector3.new(0, 0.5, 0)
    end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = TARGET_PARTICLE_TEXTURE
    emitter.Rate = 12
    emitter.Lifetime = NumberRange.new(0.6)
    emitter.Speed = NumberRange.new(0)
    emitter.Parent = attachment
    return emitter
end

SetTarget.OnClientEvent:Connect(function(targetPlayer)
    if not targetPlayer then return end
    currentTarget = targetPlayer

    -- notification banner
    banner.Text = (targetPlayer.Name or "PLAYER") .. " IS THE TARGET!"
    banner.Visible = true
    banner.TextColor3 = Color3.new(1,1,1)
    TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {BackgroundTransparency = 0}):Play()

    -- red flash
    redFlash.BackgroundTransparency = 1
    TweenService:Create(redFlash, TweenInfo.new(0.15), {BackgroundTransparency = 0.45}):Play()
    cameraShake(0.5, 0.45)
    playAlarm()

    -- highlight and particle
    if targetPlayer.Character then
        highlight = createHighlight(targetPlayer.Character)
        particle = createParticleOverHead(targetPlayer.Character)
    end

    -- hide banner after short time
    spawn(function()
        wait(3.5)
        banner.Visible = false
        TweenService:Create(redFlash, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
    end)
end)

ClearTarget.OnClientEvent:Connect(function()
    if highlight then
        highlight:Destroy()
        highlight = nil
    end
    if particle and particle.Parent then
        particle.Enabled = false
        wait(0.6)
        if particle and particle.Parent then
            particle:Destroy()
        end
        particle = nil
    end
    currentTarget = nil
end)

-- Arrow and distance display: update every frame if target exists
RunService.RenderStepped:Connect(function()
    if currentTarget and currentTarget.Character and currentTarget.Character.PrimaryPart then
        local char = currentTarget.Character
        local worldPos = char.PrimaryPart.Position
        local screenPos, onScreen = camera:WorldToViewportPoint(worldPos + Vector3.new(0, 3, 0))
        topArrow.Visible = onScreen and true or false
        if onScreen then
            topArrow.Position = UDim2.new(0, screenPos.X - topArrow.AbsoluteSize.X/2, 0, 8)
        else
            -- clamp to screen edges when off-screen (optional)
            local centerX = camera.ViewportSize.X/2
            topArrow.Position = UDim2.new(0, centerX - topArrow.AbsoluteSize.X/2, 0, 8)
        end
    else
        topArrow.Visible = false
    end
end)

-- Timer updates
RoundTimerUpdate.OnClientEvent:Connect(function(seconds, phase)
    timerLabel.Text = tostring(seconds)
    -- hide quest GUI if needed: leave to separate script HideQuestsDuringHunt
end)
