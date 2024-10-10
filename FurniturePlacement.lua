local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remoteFunctions = ReplicatedStorage.RemoteFunctions:WaitForChild("FurnitureFunctions")
local PhysicsService = game:GetService("PhysicsService")
local players = game:GetService("Players")
local ReplicatedFurniture = ReplicatedStorage.Houses:WaitForChild("Furniture")
local tweenService = game:GetService("TweenService")
local moneyAddedFunction = game.ReplicatedStorage.Houses.Functions.MoneyAdded


local furniture = {}


function furniture.fromSerialization(player, data)

	local ownedPlotValue = player:WaitForChild("PlotID").Value
	local ownedPlot = "Plot" .. ownedPlotValue
	local canvasCF = workspace.HousePlots[ownedPlot]:WaitForChild("StarterHome").CanPlaceFurniture.Floors.Floor1.CFrame
	data = data or {}

	for cf, name in pairs(data) do
		local model = ReplicatedFurniture:FindFirstChild(name)
		if (model) then
			local components = {}
			for num in string.gmatch(cf, "[^%s,]+") do
				components[#components+1] = tonumber(num)
			end

			furniture.Spawn(player, model, canvasCF * CFrame.new(unpack(components)), true)
		end
	end
	return
end

----Gives the player the player collisiongroup----
players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		furniture.fromSerialization(player, furniture.SaveToDataStore(player, false))
		for i, object in ipairs(character:GetDescendants()) do
			if object:IsA("BasePart") then
				object.CollisionGroup = "Player"
			end
		end
	end)
end)

function furniture.Delete(player, model)
	local Price = model.Config.Price.Value / 2
	player.Stats.Money.Value += Price
	moneyAddedFunction:FireClient(player, Price, true)
	model:Destroy()
end
remoteFunctions.DeleteFurnitureFunction.OnServerInvoke = furniture.Delete

function furniture.RemoveAll(player, furnitureObject)
	if furnitureObject ~= nil then
		local BackMoney = furnitureObject.Config.	Price.Value / 2
		player.Stats.Money.Value += BackMoney
		moneyAddedFunction:FireClient(player, BackMoney, true)
		furnitureObject:Destroy()
	end
end
remoteFunctions.DeleteAllFunction.OnServerInvoke = furniture.RemoveAll


----Spawns the furniture on the place where the placeolder is located----
function furniture.Spawn(player, name, cframe, loading)
	local allowedToSpawn = furniture.CheckSpawn(player, name, loading)
	local allowedToSpawn = true

	if allowedToSpawn or loading then
		local Name2 = tostring(name)

		local newFurniture
		local ownedPlotValue = players[player.Name].PlotID.Value
		local ownedPlot = "Plot" .. ownedPlotValue
		newFurniture = ReplicatedStorage.Houses.Furniture:FindFirstChild(Name2, true):Clone()

		local ownerValue = Instance.new("IntValue")
		ownerValue.Name = "Owner"
		ownerValue.Value = player.UserId
		ownerValue.Parent = newFurniture.Config

		newFurniture.BasePart.CFrame = cframe
		newFurniture.Parent = workspace.HousePlots[ownedPlot].StarterHome.Furniture
		for _,v in pairs(newFurniture:GetDescendants()) do if v.ClassName == "Script" then
				v.Enabled = true
			end
		end

				for i, object in ipairs(newFurniture:GetDescendants()) do
					if object:IsA "BasePart" then
						object.CollisionGroup = "Default"
					end
				end
				if not loading then
					---This saves the furniture when it saved but is slow, so i turned it off--
					--furniture.SaveToDataStore(player, true)
				end
				return newFurniture
			else
				warn("Furniture not exist")
				return false


	end
end

remoteFunctions.SpawnFurnitureFunction.OnServerInvoke = furniture.Spawn

----Does nothing yet----
function furniture.CheckSpawn(player, name, loading)
	local furnitureExist = ReplicatedStorage.Houses.Furniture:FindFirstChild(name, true)
	if loading then
		return true
	end
	if furnitureExist then
		if furnitureExist.Config.Price.Value <= player.Stats.Money.Value then
			return true
		else 
			warn("Player cannot afford")
		end
	else
		warn("That furniture does not exist")
	end
	return false
end
remoteFunctions.RequestFurnitureFunction.OnServerInvoke = furniture.CheckSpawn

function furniture.SaveData(player)
	local ownedPlotValue = player.PlotID.Value
	local  ownedPlot = "Plot" .. ownedPlotValue
	local SavedFurnitureTable = {}
	local furnitureToSave = workspace.HousePlots[ownedPlot].StarterHome.Furniture:GetChildren()
	local cfi = workspace.HousePlots[ownedPlot].StarterHome.CanPlaceFurniture.Floors.Floor1.CFrame:Inverse()

	for i = 1, #furnitureToSave do
		local objectSpaceCF = cfi * furnitureToSave[i].PrimaryPart.CFrame
		SavedFurnitureTable[tostring(objectSpaceCF)] = furnitureToSave[i].Name 
	end
	return SavedFurnitureTable
end

local LargerHome = game:GetService("DataStoreService"):GetDataStore("LargerHome")
local StarterHome = game:GetService("DataStoreService"):GetDataStore("StarterHome")
local FlatHome = game:GetService("DataStoreService"):GetDataStore("FlatHome")
local ThreeFloorHome = game:GetService("DataStoreService"):GetDataStore("ThreeFloorHome")
local TwoFloorHome = game:GetService("DataStoreService"):GetDataStore("TwoFloorHome")

local DataStores = {LargerHome, StarterHome, ThreeFloorHome, TwoFloorHome, FlatHome}

function furniture.SaveToDataStore(player, saving)
	local usedHouse = player:WaitForChild("HouseType").Value
	local key = "player_"..player.UserId
	local UsedDataStore

	for i, House  in ipairs(DataStores) do
		if House.Name == usedHouse then
			UsedDataStore = House
		end
	end

	local success, result = pcall(function()
		if (saving) then
			local dataToSave = furniture.SaveData(player)
			print(dataToSave)
			if (dataToSave) then
				-- save the data
				UsedDataStore:SetAsync(key, dataToSave)
			else
				-- clear the data
				UsedDataStore:SetAsync(key, {})
			end
		elseif (not saving) then
			-- load the data
			return UsedDataStore:GetAsync(key)
		end
	end)

	if (success) then
		-- return true if we had success or the loaded data
		return saving or result
	else
		-- show us the error if something went wrong
		warn(result)
	end
end
remoteFunctions.SaveFurnitureFunction.OnServerInvoke = furniture.SaveToDataStore
remoteFunctions.LoadHouse.Event:Connect(function(player, saving)
	furniture.fromSerialization(player, furniture.SaveToDataStore(player, saving))
end)  