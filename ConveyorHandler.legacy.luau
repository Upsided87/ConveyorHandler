--Connected Discord-GitHub
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local RollPack = ReplicatedStorage.Events:WaitForChild("RollPack")

local PackDefinitions = require(ReplicatedStorage.Config.PackDefinitions)

local BaseService = require(ServerScriptService.Services.BaseService)
local ConveyorService = require(ServerScriptService.Services.ConveyorService)

local function GetFunctionalParts(base: Model): (BasePart?, BasePart?)
	local packConveyor = base:FindFirstChild("PackConveyor")
	if not packConveyor then
		warn("Debug: PackConveyor folder is missing in base model")
		return nil, nil
	end

	local functional = packConveyor:FindFirstChild("Functional")
	if not functional then
		warn("Debug: Functional folder is missing in PackConveyor folder")
		return nil, nil
	end

	local spawnPart = functional:FindFirstChild("SpawnPart") --Invisible part at the beginning of the conveyor
	local despawnPart = functional:FindFirstChild("DespawnPart") --Invisible part at the end of the conveyor

	if not spawnPart then 
		warn("Debug: SpawnPart missing")  
	elseif not spawnPart:IsA("BasePart")then
        warn("SpawnPart is not a BasePart")
		spawnPart = nil
	end
	if not despawnPart then 
		warn("Debug: DespawnPart missing")  
	elseif not despawnPart or not despawnPart:IsA("BasePart")then
		warn("DespawnPart is not a BasePart")
		despawnPart = nil
	end

	if not spawnPart or not despawnPart then  --If one of the parts is nil
		return nil, nil --then return nil for both because the other function needs both parts to work
	end
	return spawnPart, despawnPart 
end



local function SpawnPack(packId: string, base: Model): boolean
	local packConveyor = base:FindFirstChild("PackConveyor")
	if not packConveyor then
		warn("Debug: PackConveyor folder is missing in base model")
		return false
	elseif not packConveyor:IsA("Folder") then
		warn("Debug: PackConveyor is not a folder")
		return false 
	end

	local spawnPart, despawnPart = GetFunctionalParts(base)
	if not spawnPart or not despawnPart then
		return false
	end

	local packDefinition = PackDefinitions[packId]
	if not packDefinition then
		warn("Debug: Pack definition missing for", packId)
		return false
	end

	local packModelName = packDefinition.ModelName 
	if not packModelName then
		warn("Debug: ModelName missing for", packId)
		return false
	elseif typeof(packModelName) ~= "string" then
		warn("Debug: ModelName of "..packId.." is not a string")
		return false
	end

	local packTemplate = ReplicatedStorage.Models.Packs:FindFirstChild(packModelName)
	if not packTemplate then
		warn("Debug: Pack template missing for "..packId.." in ReplicatedStorage.Models.Packs or the model doesn't have the name : "..packModelName)
		return false
	elseif not packTemplate:IsA("Model") then
		warn("Debug: packTemplate of "..packId.." is not a Model")
		return false
	end

	local packModel = packTemplate:Clone()
	if not packModel then 
		warn("Debug: Error during :Clone() of "..packId.." packTemplate")
		return false
	end

	packModel:SetAttribute("conveyorPack", true) --SetAttribute conveyorPack on the packModel to differentiate the conveyor packs from the regular packs 

	local packPart = packModel:FindFirstChild("mainPart")
	if not packPart then 
		warn("Debug: mainPart is missing in "..packModel.Name)
		return false
	elseif not packPart:IsA("BasePart") then
		warn("Debug: packPart is not a basePlate")
		packModel:Destroy()
		return false
	end

	packPart.Anchored = true
	packPart.CanCollide = false

	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.Parent = packPart
	proximityPrompt.MaxActivationDistance = 20
	proximityPrompt.ActionText = "Buy"
	proximityPrompt.Enabled = false

	local highlight = Instance.new("Highlight")
	highlight.Parent = packPart
	highlight.Enabled = false
	highlight.FillTransparency = 1

	packModel.Parent = packConveyor
	packModel:PivotTo(spawnPart:GetPivot())
	packModel:SetAttribute("isOnConveyor", true) --Set the attribute isOnConveyor to true to know that this is the active pack on the conveyor

	local cfValue = Instance.new("CFrameValue") --Use CFrameValue to store the packModel position and orientation because TweenService doesn't work on Models
	cfValue.Value = packModel:GetPivot()

	local configuration = TweenInfo.new( 
		1,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)

	local goal = {
		Value = spawnPart:GetPivot():Lerp(despawnPart:GetPivot(), 0.5) --Use Linear Interpolation to get the middle (which is 0.5 because it's the middle between 0 and 1) of spawnPart and despawnPart and so the conveyor middle 
	}

	local tween = TweenService:Create(cfValue, configuration, goal)

	cfValue:GetPropertyChangedSignal("Value"):Connect(function() --At each value change of cfValue by TweenService
		packModel:PivotTo(cfValue.Value) --Change the position of the packModel to the new value
	end)

	tween:Play()

	local playbackState = tween.Completed:Wait()
	cfValue:Destroy()

	if playbackState ~= Enum.PlaybackState.Completed then
		packModel:Destroy()
		return false
	end

	proximityPrompt:SetAttribute("buyPackPrompt", true)
	proximityPrompt.Enabled = true
	highlight.Enabled = true

	return true
end



local function GetPackModel(base: Model): Model | boolean | nil
	local packConveyor = base:FindFirstChild("PackConveyor")
	if not packConveyor then
		warn("Debug: PackConveyor folder is missing in base model")
		return false
	elseif not packConveyor:IsA("Folder") then
		warn("Debug: PackConveyor is not a folder")
		return false
	end

	local packModel = nil

	for _, content in packConveyor:GetChildren() do
		if content:GetAttribute("isOnConveyor") then
			if packModel then --If we already found a pack before 
				warn("Debug: Multiple packs detected on conveyor")
				return false --then we return false because there can be only one active pack at a time
			else 
				packModel = content
			end
		end
	end

	return packModel
end



local function DestroyPack(base: Model): boolean
	local packConveyor = base:FindFirstChild("PackConveyor")
	if not packConveyor then
		warn("Debug: PackConveyor folder is missing in base model")
		return false
	elseif not packConveyor:IsA("Folder") then
		warn("Debug: PackConveyor is not a folder")
		return false 
	end

	local packModel = GetPackModel(base)
	if not packModel then
		warn("Debug: No pack model found")
		return false
	end

	packModel:Destroy()
	return true
end



local function DespawnPack(base: Model): boolean
	local packConveyor = base:FindFirstChild("PackConveyor")
	if not packConveyor then
		warn("Debug: PackConveyor folder is missing in base model")
		return false
	elseif not packConveyor:IsA("Folder") then
		warn("Debug: PackConveyor is not a folder")
		return false 
	end

	local spawnPart, despawnPart = GetFunctionalParts(base)
	if not spawnPart or not despawnPart then
		warn("Debug: Error during FunctionalParts recuperation")
		return false
	elseif not spawnPart:IsA("BasePart") or not despawnPart:IsA("BasePart") then
		warn("Debug: spawn or despawn part is not a BasePlate")
		return false
	end

	local packModel = GetPackModel(base)
	if not packModel then
		warn("Debug: No pack found to despawn")
		return false 
	elseif not packModel:IsA("Model") then
		warn("Debug: packModel is not a Model")
		return false
	end

	local packPart = packModel:FindFirstChild("mainPart")
	if not packPart then 
		warn("Debug: mainPart is missing in "..packModel.Name)
		return false 
	elseif not packPart:IsA("BasePart") then
		warn("Debug: packPart is not a BasePart")
		return false
	end


	local proximityPrompt = packPart:FindFirstChild("ProximityPrompt")
	local highlight = packPart:FindFirstChild("Highlight")

	if not proximityPrompt then 
		warn("Debug: ProximityPrompt is not in the conveyor current pack model")
	elseif not proximityPrompt:IsA("ProximityPrompt") then
		warn("Debug: proximityPrompt is not a ProximityPrompt")
		return false 
	else 
		proximityPrompt.Enabled = false --Disable the proximityprompt so the player can't buy the pack anymore because he rolled it 
	end

	if not highlight then 
		warn("Debug: Highlight is not in the conveyor current pack model")
	elseif not highlight:IsA("Highlight") then
		warn("Debug: highlight is not a Highlight")
		return false 
	else 
		highlight.Enabled = false
	end

	local cfValue = Instance.new("CFrameValue")
	cfValue.Value = packModel:GetPivot()

	local configuration = TweenInfo.new(
		1,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		0,
		false,
		0
	)

	local goal = {
		Value = despawnPart:GetPivot()
	}

	local tween = TweenService:Create(cfValue, configuration, goal)

	cfValue:GetPropertyChangedSignal("Value"):Connect(function()
		packModel:PivotTo(cfValue.Value)
	end)

	packModel:SetAttribute("isOnConveyor", nil) --Remove the attribute isOnConveyor because the pack isn't the active pack anymore 

	tween.Completed:Once(function()
		cfValue:Destroy()
		packModel:Destroy()
	end)

	tween:Play()
	return true
end



local isInCooldown = {} --[player : boolean] prevent the player from rolling when his conveyor is already rolling
local isBuying = {} --[player : boolean] prevent the player from buying a pack when he's already buying one

RollPack.OnServerEvent:Connect(function(player, button)

	-- Vérifications :
	if isInCooldown[player] then
		warn("Debug: Player is in cooldown :", player.Name)
		return
	elseif isBuying[player] then 
		warn("Debug: You can't roll a pack while buying another one")
		return
	end
	isInCooldown[player] = true

	local base = BaseService.GetPlayerBase(player)
	if not base then --If the player doesn't have a base 
		warn("Debug: Player base missing :", player.Name)
		isInCooldown[player] = nil
		return --stop the function because that mean he can't roll 
	end

	local packModel = GetPackModel(base)
	if packModel == false then
		isInCooldown[player] = nil
		return
	end

	local packConveyor = base:FindFirstChild("PackConveyor")
	if not packConveyor then
		warn("Debug: PackConveyor missing in base :", base.Name)
		isInCooldown[player] = nil
		return
	end

	local rollStand = packConveyor:FindFirstChild("RollStand")
	if not rollStand then
		warn("Debug: RollStand missing")
		isInCooldown[player] = nil
		return
	end

	local rollButton = rollStand:FindFirstChild("rollButton")
	if not rollButton then
		warn("Debug: rollButton missing")
		isInCooldown[player] = nil
		return
	end

	if button ~= rollButton then --If the button pressed is different then the button in the player base 
		warn("Debug: Invalid button received :", button, "Expected :", rollButton)
		isInCooldown[player] = nil
		return --stop the function because a player shouldn't roll a pack on an other player conveyor
	end

	local character = player.Character
	if not character then
		warn("Debug: Character missing :", player.Name)
		isInCooldown[player] = nil
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		warn("Debug: HumanoidRootPart missing")
		isInCooldown[player] = nil
		return
	end

	if not (rollStand:IsA("Model") or rollStand:IsA("BasePart")) then
		warn("Debug: RollStand is not a Model or BasePart")
		isInCooldown[player] = nil
		return
	end

	local distance = (rootPart.Position - rollStand:GetPivot().Position).Magnitude --Calculate the distance between the rollStand and the player

	if distance > 10 then --If the distance is >10 
		warn("Debug: Player too far from RollStand :", distance)
		isInCooldown[player] = nil
		return --stop the function. This is to prevent the player to roll the pack on his conveyor from too far away
	end

	if not packModel then -- Si il n'y a pas de pack sur le convoyeur

		local packId = ConveyorService.GenerateOffer(player)
		if not packId then
			warn("Debug: GenerateOffer failed")
			isInCooldown[player] = nil
			return
		elseif not SpawnPack(packId, base) then
			warn("Debug: SpawnPack failed :", packId)
			isInCooldown[player] = nil
			return
		end

		isInCooldown[player] = nil
		return
	else

		local currentOffer = ConveyorService.GenerateOffer(player)
		if not currentOffer then
			warn("Debug: GenerateOffer failed")
			isInCooldown[player] = nil
			return
		elseif not DespawnPack(base) then
			warn("Debug: DespawnPack failed")
			isInCooldown[player] = nil
			return
		elseif not SpawnPack(currentOffer, base) then
			warn("Debug: SpawnPack failed :", currentOffer)
			isInCooldown[player] = nil
			return
		end

		isInCooldown[player] = nil
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if isInCooldown[player] or isBuying[player] then --Prevent the player from buying a pack when he's rolling or when he's already buying one so he can't buy the same pack twice
		return
	end

	local base = BaseService.GetPlayerBase(player)
	if not base then
		warn("Debug: Player base missing in BuyPack")
		return
	end

	local packModel = GetPackModel(base)
	if not packModel then 
		return 	
	end

	-- Vérifications
	if not prompt:GetAttribute("buyPackPrompt") then --If this is not a buyPackPrompt then 
		return --stop the function. We have to verify this because ProximityPromptService.PromptTriggered is Triggered by any prompt except we only want buyPackPrompt
	elseif not prompt:IsDescendantOf(base) then  --If the prompt isn't located in the player base 
		warn("This ProximityPrompt is not a part of "..player.Name.." base")
		return --stop the function because a player shoudn't buy a pack from an other conveyor than his own 
	elseif prompt.Parent.Parent ~= packModel then --Same if the prompt is not the current buyable prompt on his conveyor
		warn("This prompt is not in the current buyable pack")
		return
	end

	isBuying[player] = true

	-- Achat
	if ConveyorService.BuyOffer(player) then
		if not DestroyPack(base) then
			warn("Debug: BuyOffer succeeded but DestroyPack failed")
			isBuying[player] = nil
			return
		end

		isBuying[player] = nil
	else
		isBuying[player] = nil
		warn("Debug: BuyOffer failed :", player.Name)
	end
end)

