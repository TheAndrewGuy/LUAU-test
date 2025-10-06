-- Round System

--// Variables
local Status = game.ReplicatedStorage:WaitForChild("Status") -- Displays game status text (e.g., “Round begins in…”)
local Timer = game.ReplicatedStorage:WaitForChild("Timer") -- Used for communicating timer changes to clients

--// Round Timers (Defaults)
local ActualRound = 240 -- Default round duration (seconds)
local ActualIntermission = 30 -- Default intermission duration (seconds)

--// Changeable (Current) Timers
local Round = 240
local Intermission = 30

local OnGoingRound = false -- Flag to check if a round is currently active

--// Timer Adjustments Handler (Killer or Survivor progress)
game.ReplicatedStorage.Timer.Event:Connect(function(type)
	if OnGoingRound then
		if type and type == "add" then
			Round += 35 -- Increases round timer (when killer kills a survivor)
		else
			Round -= 2 -- Decreases round timer (when survivors progress a generator)
		end
	end
end)

--// When a player finishes loading in
game.ReplicatedStorage.Loaded.OnServerEvent:Connect(function(plr)
	plr.Loaded.Value = true
end)

--// Testing Mode (for Studio)
local Testing = false
if Testing == true then Testing = game:GetService("RunService"):IsStudio() end

--// Checks if player(s) are fully loaded
function LoadedCheck(type, player)
	if type and type == "Everyone" then
		-- Returns table of all loaded players
		local heh = {}
		for i, v in pairs(game.Players:GetPlayers()) do
			if v:FindFirstChild("Loaded") and v.Loaded.Value and v.Character and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
				table.insert(heh, v)
				if Testing then table.insert(heh, v) end
			end
		end
		return heh
	elseif player then
		-- Checks if a single player is loaded
		local val = false
		if player:FindFirstChild("Loaded") and player.Loaded.Value then
			if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
				val = true
			end
		end
		return val
	end
end

--// Converts time into “M:SS” format
function InitiateNumber(num)
	local Minutes = math.floor(num / 60)
	local Seconds = math.floor(num % 60)
	if Seconds < 10 then Seconds = "0" .. Seconds end
	return Minutes .. ":" .. Seconds
end

--// Core Player Variables
local InRound = {} -- Stores current survivors in round
local Killer = nil -- Stores current killer

--// Money Module (used to reward players)
local Money = require(game.ReplicatedStorage:WaitForChild("Money"))

--// Player death handling
game.Players.PlayerAdded:Connect(function(plr)
	local function Do()
		local char = plr.Character or plr.CharacterAdded:Wait()
		local hum = char:WaitForChild("Humanoid")
		local Health = char:WaitForChild("Health")

		if Health then Health.Disabled = true end

		hum.Died:Connect(function()
			-- Removes player from active list on death
			for i = #InRound, 1, -1 do
				if InRound[i] == plr then
					table.remove(InRound, i)
					break
				end
			end
			-- Clears killer if killer died
			if Killer == plr then Killer = nil end
		end)
	end

	Do()
	plr.CharacterAdded:Connect(Do)
end)

--// When player leaves mid-round
game.Players.PlayerRemoving:Connect(function(plr)
	local WasInRound = false
	local char = plr.Character
	local hum = char and char:FindFirstChild("Humanoid")

	-- Remove from survivor list
	for i = #InRound, 1, -1 do
		if InRound[i] == plr then
			table.remove(InRound, i)
			WasInRound = true
			break
		end
	end

	-- If killer leaves or survivor rage quits
	if Killer and Killer == plr then
		Killer = nil
	elseif WasInRound and hum then
		if hum.Health < hum.MaxHealth and Killer then
			game.ReplicatedStorage.Timer:Fire("add") -- Bonus time for killer
			Money.Initiate(Killer, 15, "Survivor rage quit.")
		end
	end
end)

--// Importing core modules
local Transform = require(game.ReplicatedStorage:WaitForChild("Transform")).Initiate
local RI = require(game.ReplicatedStorage:WaitForChild("RoundInitiation"))
local GetLMS = require(game.ReplicatedStorage:WaitForChild("GetLMS"))
local Highlight = game.ReplicatedStorage:WaitForChild("HighlightClient")
local MusicStart = require(game.ReplicatedStorage:WaitForChild("MusicStart"))

--//==============================
--// ROUND LOOP (MAIN GAME CYCLE)
--//==============================

while true do
	-- Clear leftover map objects
	for _, folderName in pairs({"Hitbox", "CollisionBoxes"}) do
		local folder = workspace:WaitForChild(folderName)
		for _, v in pairs(folder:GetChildren()) do v:Destroy() end
	end

	for _, v in pairs(workspace.Generators:GetChildren()) do
		if v:IsA("BasePart") or v:IsA("Model") then v:Destroy() end
	end

	-- Reset round states
	game.ReplicatedStorage.ObjectivesDone.Value = 0
	game.SoundService.Lobby:Play()
	Round = ActualRound
	Intermission = ActualIntermission
	InRound = {}
	Status.Value = "There needs to be at least 2 people."
	Killer = nil

	if Testing then Intermission = 3 end

	-- Preload random map halfway through intermission
	local map
	task.spawn(function()
		task.wait(Intermission / 2)
		local maps = game.ServerStorage.Maps:GetChildren()
		map = maps[math.random(1, #maps)]:Clone()
		map.Parent = workspace
	end)

	-- INTERMISSION LOOP
	repeat
		local loaded = LoadedCheck("Everyone")
		if #loaded < 2 then
			Status.Value = "There needs to be at least 2 people."
			repeat task.wait(0.5) until #LoadedCheck("Everyone") > 1
		end
		Intermission -= 1
		Status.Value = "Round Begins: " .. InitiateNumber(Intermission)
		task.wait(1)
	until Intermission == 0

	-- START ROUND
	OnGoingRound = true
	game.SoundService.Lobby:Stop()

	-- Select killer (player with highest “Malice” stat)
	local OldKillerMalice = 0
	for _, v in pairs(game.Players:GetPlayers()) do
		local Malice = v:FindFirstChild("leaderstats") and v.leaderstats:FindFirstChild("Malice")
		if Malice and Malice.Value > OldKillerMalice and LoadedCheck(nil, v) then
			OldKillerMalice = Malice.Value
			Killer = v
		end
	end

	local Cutscene
	local Killa
	local KillerSkin

	if Testing then Killer = nil end
	if Killer then
		-- Ensure killer’s character is valid
		local char = Killer.Character
		if not char then Killer = nil return end
		local hum = char:FindFirstChild("Humanoid")
		if not hum or hum.Health < 1 then Killer = nil return end

		Killer.leaderstats.Malice.Value = 1
		Killa = Killer.Killer.Value
		KillerSkin = Killer:FindFirstChild("Skins"):FindFirstChild(Killa).Value

		-- Transform player into killer
		Transform(Killer.Character, Killa, KillerSkin, false)

		-- Cutscene handling
		Cutscene = game.ServerStorage.Cutscenes:FindFirstChild(Killa):FindFirstChild(KillerSkin)
			or game.ServerStorage.Cutscenes:FindFirstChild(Killa):FindFirstChild("Default")
		if not Cutscene or not Cutscene:FindFirstChild("Camera") then
			game.ReplicatedStorage.Killer:FireAllClients("Cutscene", Killer.Killer.Value, Killer.Name)
		end

		game.ReplicatedStorage.RoundStart:FireClient(Killer)
		MusicStart.Initiate(char)
	end

	--// Transform all other players into survivors
	for _, v in pairs(game.Players:GetPlayers()) do
		if v ~= Killer and LoadedCheck(nil, v) then
			task.spawn(function()
				table.insert(InRound, v)
				local Malice = v:FindFirstChild("leaderstats") and v.leaderstats:FindFirstChild("Malice")
				if Malice and not v:GetAttribute("DisableBeingKiller") then
					Malice.Value += 1
				end
				game.ReplicatedStorage.RoundStart:FireClient(v)
				local Survivor = v.Survivor.Value
				local SurvivorSkin = v:FindFirstChild("Skins"):FindFirstChild(Survivor).Value
				Transform(v.Character, Survivor, SurvivorSkin, true)
			end)
		end
	end

	-- Cutscene playback (if exists)
	if Cutscene and Cutscene:FindFirstChild("Camera") then
		Cutscene = Cutscene:Clone()
		Cutscene.Parent = workspace
		task.wait(0.5)
		local Cam = Cutscene.Camera
		game.ReplicatedStorage.Camera:FireAllClients(Cam, false)

		if Cutscene:FindFirstChild("WaitTime") then
			game.ReplicatedStorage.Killer:FireAllClients("Cutscene", Killer.Killer.Value, Killer.Name, Cutscene.WaitTime.Value + 3)
			game.ReplicatedStorage.Killer:FireAllClients("Timer", Cutscene.WaitTime.Value)
			task.wait(Cutscene.WaitTime.Value)
		else
			game.ReplicatedStorage.Killer:FireAllClients("Cutscene", Killer.Killer.Value, Killer.Name)
			game.ReplicatedStorage.Killer:FireAllClients("Timer", 5)
			task.wait(5)
		end

		-- Send role instructions
		game.ReplicatedStorage.Instructions:FireClient(Killer, "Killer")
		for _, v in pairs(InRound) do
			game.ReplicatedStorage.Instructions:FireClient(v, "Survivor")
		end

		game.ReplicatedStorage.Camera:FireAllClients(nil)
		Cutscene:Destroy()
	end

	task.wait(4)

	-- Spawn all players
	if Killer then
		local Spawn = map.KillerSpawns:GetChildren()[math.random(1, #map.KillerSpawns:GetChildren())]
		local root = Killer.Character:WaitForChild("HumanoidRootPart")
		root.CFrame = Spawn.CFrame + Vector3.new(0, 3, 0)
	end

	for _, v in pairs(InRound) do
		task.spawn(function()
			local Spawn = map.Spawns:GetChildren()[math.random(1, #map.Spawns:GetChildren())]
			local root = v.Character:WaitForChild("HumanoidRootPart")
			root.CFrame = Spawn.CFrame + Vector3.new(0, 3, 0)
		end)
	end

	-- Initialize round systems (objectives, etc.)
	RI.Initiate(InRound, Killer)

	if Testing then task.wait(10) end

	-- Round monitoring (Last Man Standing)
	local RoundEnded = false
	local LMSSound = nil
	task.spawn(function()
		repeat task.wait(0.1) until Killer and #InRound > 0
		local LMS = false
		repeat
			if not LMS and #InRound == 1 and Killer then
				task.wait(1)
				LMS = true
				game.ReplicatedStorage.LMS.Value = true
				LMSSound = GetLMS.Initiate(Killer, InRound[1])
				Round = LMSSound.TimeLength / LMSSound.PlaybackSpeed
				Status.Value = "Round Ends: " .. InitiateNumber(Round)
				LMSSound:Play()
				Highlight:FireClient(Killer, InRound[1], 2)
				Highlight:FireClient(InRound[1], Killer, 3, "Red")
				task.wait(1)
			end
			Round -= 1
			Status.Value = "Round Ends: " .. InitiateNumber(Round)
			task.wait(1)
		until Round < 1 or not Killer or #InRound == 0
		RoundEnded = true
	end)

	repeat task.wait(0.1) until RoundEnded
	game.ReplicatedStorage.LMS.Value = false
	OnGoingRound = false
	if LMSSound then LMSSound:Stop() end

	-- Round results and rewards
	if #InRound == 0 and Killer then
		Money.Initiate(Killer, 60, "Won as Killer.")
	end

	for _, v in pairs(InRound) do
		Money.Initiate(v, 40, "Won as survivor.")
		v:LoadCharacter()
		v.Character.HumanoidRootPart.CFrame = workspace.SpawnLocation.CFrame * CFrame.new(0, 3, 0)
	end

	if Killer then
		Killer:LoadCharacter()
		Killer.Character.HumanoidRootPart.CFrame = workspace.SpawnLocation.CFrame * CFrame.new(0, 3, 0)
	end

	if map then map:Destroy() end
end
