-- Variables
local Status = game.ReplicatedStorage:WaitForChild("Status")
local Timer = game.ReplicatedStorage:WaitForChild("Timer")

-- Round Variables
local ActualRound = 240
local ActualIntermission = 30

-- Changeable Variables
local Round = 240
local Intermission = 30

local OnGoingRound = false

-- Timer Function
game.ReplicatedStorage.Timer.Event:Connect(function(type)
	if OnGoingRound then
		if type and type == "add" then
			Round+= 35 -- adds timer when the killer kills.
		else
			Round -= 2 -- removes a bit of the timer when a survivor finishing a bit of a generator.
		end
	end
end)

-- Client tells the server the player loaded.
game.ReplicatedStorage.Loaded.OnServerEvent:Connect(function(plr)
	plr.Loaded.Value = true
end)

local Testing = false

-- If testing is set to true, it checks if its on studio because sometimes I forget to set it to false.
if Testing == true then Testing = game:GetService("RunService"):IsStudio() end

-- Function to check if a player is loaded or to return a table of everyone who is loaded.
function LoadedCheck(type,player)
	if type and type == "Everyone" then
		local heh = {}
		for i,v in pairs(game.Players:GetPlayers()) do
			if v:FindFirstChild("Loaded") and v.Loaded.Value == true and v.Character and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
				table.insert(heh,v)
				if Testing then
					table.insert(heh,v)
				end
			end
		end
		return heh
	elseif player then
		local val = false
		if player:FindFirstChild("Loaded") and player.Loaded.Value == true then
			if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
				val = true
			end
		end
		return val
	end
end

-- returns in a 0:00 format.
function InitiateNumber(num)
	local Minutes = math.floor(num/60)
	local Seconds = math.floor(num%60)
	if Seconds < 10 then
		Seconds = "0"..Seconds
	end
	return Minutes..":"..Seconds
end

-- Players
local InRound = {}
local Killer = nil

-- Module to give money
local Money = require(game.ReplicatedStorage:WaitForChild("Money"))

-- Handler for if a player dies.
game.Players.PlayerAdded:Connect(function(plr)
	local function Do()
		local char = plr.Character or plr.CharacterAdded:Wait()
		
		local hum = char:WaitForChild("Humanoid")
		local Health = char:WaitForChild("Health")
		if Health then
			Health.Disabled = true
		end
		hum.Died:Connect(function()
			for i = #InRound, 1, -1 do
				if InRound[i] == plr then
					table.remove(InRound, i)
					break
				end
			end
			
			if Killer == plr then
				Killer = nil
			end
		end)
	end
	Do()
	
	plr.CharacterAdded:Connect(Do)
end)

-- For if a player leaves.
game.Players.PlayerRemoving:Connect(function(plr)
	local WasInRound = false
	local char = plr.Character
	local hum
	if char then
		hum = char:FindFirstChild("Humanoid")
	end
	for i = #InRound, 1, -1 do
		if InRound[i] == plr then
			table.remove(InRound, i)
			WasInRound = true
			break
		end
	end

	if Killer and Killer == plr then
		Killer = nil
	elseif WasInRound and hum then
		if hum.Health < hum.MaxHealth and Killer then
			game.ReplicatedStorage.Timer:Fire("add")
			Money.Initiate(Killer,15,"Survivor rage quit.")
		end
	end
end)

-- Killer = player character, killa = player killer value or survivor value, s = player is survivor

game.ReplicatedStorage:WaitForChild("Transform")
local Transform = require(game.ReplicatedStorage.Transform)
Transform = Transform.Initiate

local RI = game.ReplicatedStorage:WaitForChild("RoundInitiation")
RI = require(RI)

local GetLMS = game.ReplicatedStorage:WaitForChild("GetLMS")
GetLMS = require(GetLMS)

local Highlight = game.ReplicatedStorage:WaitForChild("HighlightClient")

local MusicStart = game.ReplicatedStorage:WaitForChild("MusicStart")
MusicStart = require(MusicStart)

while true do
	game.Workspace:WaitForChild("Hitbox")
	for i,v in pairs(workspace.Hitbox:GetChildren()) do
		v:Destroy()
	end
	game.Workspace:WaitForChild("CollisionBoxes")
	for i,v in pairs(workspace.CollisionBoxes:GetChildren()) do
		v:Destroy()
	end
	for i,v in pairs(workspace.Generators:GetChildren()) do
		if v:IsA("BasePart") or v:IsA("Model") then
			v:Destroy()
		end
	end
	game.ReplicatedStorage.ObjectivesDone.Value = 0
	game.SoundService.Lobby:Play()
	Round = ActualRound
	Intermission = ActualIntermission
	InRound = {}
	Status.Value = "There needs to be atleast 2 people."
	Killer = nil
	
	if Testing then
		Intermission = 3
	end
	
	local map
	task.spawn(function()
		task.wait(Intermission/2)
		map = game.ServerStorage.Maps:GetChildren()[math.random(1,#game.ServerStorage.Maps:GetChildren())]:Clone()
		map.Parent = workspace
	end)
	
	repeat
		local done = LoadedCheck("Everyone")
		if #done < 2 then
			Status.Value = "There needs to be atleast 2 people."
			repeat task.wait(0.5) until #LoadedCheck("Everyone") > 1
		end
		Intermission -= 1
		Status.Value = "Round Begins: "..InitiateNumber(Intermission)
		task.wait(1)
	until Intermission == 0
	OnGoingRound = true
	game.SoundService.Lobby:Stop()
	
	local OldKillerMalice = 0
	
	
	
	for i,v in pairs(game.Players:GetPlayers()) do
		local Malice = v:FindFirstChild("leaderstats") and v.leaderstats:FindFirstChild("Malice")
		if Malice.Value > OldKillerMalice and LoadedCheck(nil,v) then
			OldKillerMalice = Malice.Value
			Killer = v
		end
	end
	
	local Cutscene
	
	local Killa
	local KillerSkin
	
	if Testing then
		Killer = nil
	end
	
	if Killer then
		
		local char = Killer.Character
		if not char then Killer = nil return end
		local hum = char:FindFirstChild("Humanoid")
		if not hum or hum.Health < 1 then Killer = nil return end
		
		
		Killer.leaderstats.Malice.Value = 1
		
		Killa = Killer.Killer.Value
		KillerSkin = Killer:FindFirstChild("Skins"):FindFirstChild(Killa).Value
		
		Transform(Killer.Character,Killa,KillerSkin,false)
		
		Cutscene = game.ServerStorage.Cutscenes:FindFirstChild(Killa):FindFirstChild(KillerSkin) or game.ServerStorage.Cutscenes:FindFirstChild(Killa):FindFirstChild("Default")
		if not Cutscene or not Cutscene:FindFirstChild("Camera") then
			game.ReplicatedStorage.Killer:FireAllClients("Cutscene",Killer.Killer.Value,Killer.Name)
		end
		
		game.ReplicatedStorage.RoundStart:FireClient(Killer)
		MusicStart.Initiate(char)
	end
	
	for i,v in pairs(game.Players:GetPlayers()) do
		if v ~= Killer and LoadedCheck(nil,v) then
			spawn(function()
				table.insert(InRound,v)
				if v:FindFirstChild("leaderstats") and v.leaderstats:FindFirstChild("Malice") and not v:GetAttribute("DisableBeingKiller") then
					v.leaderstats.Malice.Value += 1
				end
				game.ReplicatedStorage.RoundStart:FireClient(v)
				local Survivor = v.Survivor.Value
				local SurvivorSkin = v:FindFirstChild("Skins"):FindFirstChild(Survivor).Value
				Transform(v.Character,Survivor,SurvivorSkin,true)
			end)
		end
	end	
	
	if Cutscene and Cutscene:FindFirstChild("Camera") then
		Cutscene = Cutscene:Clone()
		Cutscene.Parent = workspace
		task.wait(0.5)
		Cutscene:WaitForChild("Camera")
		local Cam = Cutscene.Camera
		game.ReplicatedStorage.Camera:FireAllClients(Cam,false)
		if Cutscene:FindFirstChild("WaitTime") then
			game.ReplicatedStorage.Killer:FireAllClients("Cutscene",Killer.Killer.Value,Killer.Name,Cutscene.WaitTime.Value + 3)
			game.ReplicatedStorage.Killer:FireAllClients("Timer",Cutscene.WaitTime.Value)
			task.wait(Cutscene.WaitTime.Value)
		else
			game.ReplicatedStorage.Killer:FireAllClients("Cutscene",Killer.Killer.Value,Killer.Name)
			game.ReplicatedStorage.Killer:FireAllClients("Timer",5)
			task.wait(5)
		end
		game.ReplicatedStorage.Instructions:FireClient(Killer,"Killer")
		for i,v in pairs(InRound) do
			game.ReplicatedStorage.Instructions:FireClient(v,"Survivor")
		end
		game.ReplicatedStorage.Camera:FireAllClients(nil)
		Cutscene:Destroy()
	end
	
	task.wait(4)
	
	if Killer then
		local Spawn = map.KillerSpawns:GetChildren()[math.random(1,#map.KillerSpawns:GetChildren())]
		local root = Killer.Character:WaitForChild("HumanoidRootPart")
		root.CFrame = Spawn.CFrame + Vector3.new(0, 3, 0)
	end
	
	for i,v in pairs(InRound) do
		spawn(function()
			local Spawn = map.Spawns:GetChildren()[math.random(1,#map.Spawns:GetChildren())]
			local root = v.Character:WaitForChild("HumanoidRootPart")
			root.CFrame = Spawn.CFrame + Vector3.new(0, 3, 0)
		end)
	end
	
	RI.Initiate(InRound,Killer)
	
	if Testing then task.wait(10) end
	
	local RoundEnded = false
	local LMSSound = nil
	spawn(function()
		repeat task.wait(0.1) until Killer and #InRound > 0
		local LMS = false
		repeat
			if not LMS and #InRound == 1 and Killer then
				task.wait(1)
				LMS = true
				game.ReplicatedStorage.LMS.Value = true
				LMSSound = GetLMS.Initiate(Killer,InRound[1])
				Round = LMSSound.TimeLength / LMSSound.PlaybackSpeed
				Status.Value = "Round Ends:  "..InitiateNumber(Round)
				LMSSound:Play()
				
				-- Highlighted:Player Status:number Color:string
				
				print(Killer,InRound[1])
				Highlight:FireClient(Killer,InRound[1],2)
				Highlight:FireClient(InRound[1],Killer,3,"Red")
				task.wait(1)
			end
			Round -= 1
			Status.Value = "Round Ends:  "..InitiateNumber(Round)
			task.wait(1)
		until Round < 1 or not Killer or #InRound == 0
		RoundEnded = true
	end)
	
	repeat task.wait(0.1) until RoundEnded == true
	game.ReplicatedStorage.LMS.Value = false
	OnGoingRound = false
	if LMSSound then
		LMSSound:Stop()
	end
	
	if #InRound == 0 then
		if Killer then
			Money.Initiate(Killer,60,"Won as Killer.")
		end
	end
	
	for i,v in pairs(InRound) do
		Money.Initiate(v,40,"Won as survivor.")
		v:LoadCharacter()
		v.Character.HumanoidRootPart.CFrame = (workspace.SpawnLocation.CFrame * CFrame.new(0,3,0))
	end
	
	if Killer then
		Killer:LoadCharacter()
		Killer.Character.HumanoidRootPart.CFrame = (workspace.SpawnLocation.CFrame * CFrame.new(0,3,0))
	end
	
	if map then
		map:Destroy()
	end
end
