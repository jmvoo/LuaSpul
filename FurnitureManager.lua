
----Variables----
local players = game:GetService("Players")
local LocalPlayer = players.LocalPlayer
local humanoid = LocalPlayer.Character:WaitForChild("Humanoid")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local RemoteFunctions = ReplicatedStorage.RemoteFunctions:WaitForChild("FurnitureFunctions")

local furniture = ReplicatedStorage.Houses:WaitForChild("Furniture")
local SpawnFurnitureFunction = RemoteFunctions.SpawnFurnitureFunction

local ownedPlotValue 
local ownedPlot 
local CanPlaceFurniture
local SelectedToDeleteFurniture

local camera = workspace.CurrentCamera
local gui = script.Parent.Shops:WaitForChild("Furniture")

local isSaved = false
local hoveredInstance = nil
local selectedFurniture = nil
local furnitureToSpawn = nil
local canPlace = false
local rotation = 0

local mainGui = LocalPlayer.PlayerGui:WaitForChild("MainGui")
local furniturePlacementMenu = mainGui.FurniturePlacementMenu

----Raycast----
local function MouseRaycast(blacklist)
	local MousePosition = UserInputService:GetMouseLocation()        
	local mouseRay = camera:ViewportPointToRay(MousePosition.x, MousePosition.Y)    
	local raycastParams = RaycastParams.new()

	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = blacklist

	local raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)

	return raycastResult
end

----Remove the placeHolder----
local function RemovePlaceHolderFurniture()
	if furnitureToSpawn then
		furnitureToSpawn:Destroy()
		furnitureToSpawn = nil
		rotation = 0
	end
end

humanoid.Died:connect(function()
	RemovePlaceHolderFurniture()
end)

furniturePlacementMenu.Menu.CancelPlacement.Activated:connect(function()
	RemovePlaceHolderFurniture()
	furniturePlacementMenu.Visible = false
	furniturePlacementMenu.Menu.Visible = false
	furniturePlacementMenu.MenuPhone.Visible = false
end)

furniturePlacementMenu.MenuPhone.CancelPlacement.Activated:connect(function()
	RemovePlaceHolderFurniture()
	furniturePlacementMenu.Visible = false
	furniturePlacementMenu.Menu.Visible = false
	furniturePlacementMenu.MenuPhone.Visible = false
end)

local succes = false
furniturePlacementMenu.Menu.RemoveAllFurniture.Activated:connect(function()
	_G.confirmPrompt("Are you sure you want to remove all your furniture? This can't be reverted!", function()
		local furnitureModels = workspace.HousePlots[ownedPlot].StarterHome.Furniture
		mainGui.SoundEffects.DeleteFurniture:Play()

		for i, object in ipairs(furnitureModels:GetDescendants()) do
			if object:IsA("BasePart") then
				local furnitureObject = object.Parent
				RemoteFunctions.DeleteAllFunction:InvokeServer(furnitureObject)
			end
		end
	end)	
end)

local ButtonTable = mainGui.Shops.Furniture.OrderMenu.ScrollingFrame
local FurnitureTable = mainGui.Shops.Furniture.ScrollingFrame

local function onButtonActivated(button)
	local read = button.Name
	for _,b in pairs(FurnitureTable:GetChildren()) do
		if b:IsA("Frame") then
			if b:HasTag(button.Name) then
				b.Visible = true
			else
				b.Visible = false
			end
		end
	end
end

for _,v in pairs(ButtonTable:GetChildren()) do
	if v:IsA("GuiButton") then
		v.Activated:Connect(function()
			onButtonActivated(v)
		end)
	end
end

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.X then
		RemovePlaceHolderFurniture()
		furniturePlacementMenu.Visible = false
		furniturePlacementMenu.Menu.Visible = false
		furniturePlacementMenu.MenuPhone.Visible = false
	end
end)

UserInputService.InputBegan:Connect(function(input)
	ownedPlotValue = players.LocalPlayer.PlotID.Value
	ownedPlot = "Plot" .. ownedPlotValue
	CanPlaceFurniture = workspace.HousePlots[ownedPlot]:WaitForChild("StarterHome"):WaitForChild("CanPlaceFurniture").Name

	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
		game.ReplicatedStorage.RemoteFunctions.DataFunctions.SavePlayerData:FireServer()
		RemoteFunctions.SaveFurnitureFunction:InvokeServer(true)
	end
end)

----Add the place holder----
local function addPlaceHolderFurniture(name)

	local furnitureExists = furniture:FindFirstChild(name, true)
	if furnitureExists then
		RemovePlaceHolderFurniture()
		furnitureToSpawn = furnitureExists:Clone()
		furnitureToSpawn.Parent = workspace


		for i, object in ipairs(furnitureToSpawn:GetDescendants()) do
			if object:IsA("BasePart") then
				if object.Name == "BoundingBox" then
					object.Material = Enum.Material.ForceField
					object.Transparency = 0.3
				end

				furniturePlacementMenu.Visible = true
				if UserInputService.TouchEnabled == true then
					furniturePlacementMenu.MenuPhone.Visible = true
				elseif UserInputService.TouchEnabled == false then
					furniturePlacementMenu.Menu.Visible = true
				end
				object.CollisionGroup = "PlaceHolder"
				object:AddTag("CameraIgnore")
			end
		end
	else
		warn	(name .. " does not exist")
	end	
end

----Color the placeholder----
local function ColorPlaceHolderFurniture(color)
	for i, object in ipairs(furnitureToSpawn:GetDescendants()) do
		if object:IsA("BasePart") then
			object.Color = color
		end
	end
end

local function isTouchingAnyModel(model)
	ownedPlotValue = players.LocalPlayer.PlotID.Value
	ownedPlot = "Plot" .. ownedPlotValue
	local models = workspace.HousePlots[ownedPlot]:WaitForChild("StarterHome"):WaitForChild("Furniture"):GetDescendants() -- You might adjust this to a specific subset of models

	for _, descendant in ipairs(models) do
		if descendant:IsA("Model") and descendant ~= model then
			local touchingParts = model.BoundingBox:GetTouchingParts()

			for _, part in pairs(touchingParts) do
				if part:IsDescendantOf(descendant) and descendant.Config:FindFirstChild("CanBePlacedOn") then
					return true
				end
			end
		end
	end

	return false
end


local function isColliding(model)
	local isColliding = false
	local CollisionCubes = workspace.HousePlots.CollisionCubes

	local IsTouchingModel = isTouchingAnyModel(model)
	if IsTouchingModel == true then
		isColliding = false
		return isColliding
	else

		-- must have a touch interest for the :GetTouchingParts() method to work
		local touch = model.BoundingBox.Touched:Connect(function() end)
		local touching = model.BoundingBox:GetTouchingParts()

		-- if intersecting with something that isn't part of the model then can't place
		for i = 1, #touching do
			if (not touching[i]:IsDescendantOf(model)) then
				if (not touching[i]:IsDescendantOf(CollisionCubes)) then
					isColliding = true
					break
				end
			end
		end

		-- cleanup and return
		touch:Disconnect()
		return isColliding
	end
end

for i, furniture in pairs(furniture:GetDescendants()) do
	if CollectionService:HasTag(furniture, "FurnitureModel") then
		local frame = gui.ScrollingFrame.FurnitureTemplate:Clone()
		local config = furniture:WaitForChild("Config")
		local SortingTag = config.Sorting.Value
		frame.Name = furniture.Name
		frame.FurnitureImage.Image = config.Image.Texture
		frame.Visible = true
		frame.Price.Text = config.Price.Value
		frame.ItemName.Text = config.Parent.Name
		frame.LayoutOrder = config.Price.Value
		frame.Parent = gui.ScrollingFrame
		frame:AddTag(SortingTag)
		frame:AddTag("All")

		frame.BuyButton.Activated:Connect(function()
			--local allowedToSpawn = RemoteFunctions.RequestFurnitureFunction:InvokeServer(furniture.Name)
			--if allowedToSpawn then

			frame.Title.Value = config.Parent.Name
			_G.confirmPrompt("Buy '" .. frame.Title.Value .. "' for " .. config.Price.Value  .. "?", function()	
				if LocalPlayer.Stats.Money.Value >= config.Price.Value then
					addPlaceHolderFurniture(furniture.Name)
					mainGui.Shops.Visible = false
				else
					_G.makeMessage("You don't have enough money to buy ".. config.Parent.Name .. ".", function()	
						wait(3.5)
					end)
				end
			end)
		end)
	end
end


local AgreePlacementButton = LocalPlayer.PlayerGui.MainGui.FurniturePlacementMenu.MenuPhone.AgreePlacement
AgreePlacementButton.Activated:Connect(function()
	if furnitureToSpawn then
		if canPlace then
			local placedFurniture = SpawnFurnitureFunction:InvokeServer(furnitureToSpawn.Name, furnitureToSpawn.PrimaryPart.CFrame)
			if placedFurniture then
				RemovePlaceHolderFurniture()

				local config = placedFurniture:FindFirstChild("Config")
				ReplicatedStorage.Houses.Functions.FurnitureItemBought:FireServer(config)
				mainGui.SoundEffects.AddMoney:Play()
				wait(0.1)
				mainGui.Shops.Visible = true
				furniturePlacementMenu.Visible = false
				furniturePlacementMenu.Menu.Visible = false
				furniturePlacementMenu.MenuPhone.Visible = false
			end
		end
	end
end)

local IsOnButton = false
local stepSize = 1.0447
local LastPositionX
local LastPositionY
local LastPositionZ
local LastModel
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.Touch then
		if UserInputService.TouchEnabled == true then
			ownedPlotValue = players.LocalPlayer.PlotID.Value
			ownedPlot = "Plot" .. ownedPlotValue
			local pos = input.Position
			local guisAtPosition = LocalPlayer:WaitForChild("PlayerGui"):GetGuiObjectsAtPosition(pos.X, pos.Y)
			CanPlaceFurniture = workspace.HousePlots[ownedPlot]:WaitForChild("StarterHome"):WaitForChild("CanPlaceFurniture").Name
			local result = MouseRaycast({furnitureToSpawn})
			IsOnButton = false
			for _, TheGui in ipairs(guisAtPosition) do
				if TheGui:IsA("TextButton") or TheGui:IsA("ImageButton") then
					IsOnButton = true
					break
				end
			end
			if result and result.Instance then
				if furnitureToSpawn then
					if IsOnButton ~= true then
						hoveredInstance = nil
						if result.Instance:FindFirstAncestor(CanPlaceFurniture) and result.Instance:FindFirstAncestor(ownedPlot) and result.Instance:FindFirstAncestor(furnitureToSpawn.Config.CanPlaceOn.Value) and not isColliding(furnitureToSpawn) then
							canPlace = true
							ColorPlaceHolderFurniture(Color3.new(0.14902, 1, 0.431373))
						else
							canPlace = false
							ColorPlaceHolderFurniture(Color3.new(1, 0.321569, 0.321569))
						end

						local x = result.Position.X
						local y = result.Position.Y
						local z = result.Position.Z

						-- Apply rotation
						local cframe = CFrame.new(x,y,z) * CFrame.Angles(0, math.rad(rotation), 0)
						furnitureToSpawn:SetPrimaryPartCFrame(cframe)
						LastPositionX = x
						LastPositionY = y
						LastPositionZ = z
					end
				elseif LocalPlayer.Character:FindFirstChild("DeleteTool1") then	
					local model = result.Instance:FindFirstAncestorOfClass("Model")
					if model and model.Parent == workspace.HousePlots[ownedPlot].StarterHome.Furniture and model:FindFirstAncestor(ownedPlot) and LocalPlayer.Character:FindFirstChild("DeleteTool1") then
						SelectedToDeleteFurniture = model
						RemoteFunctions.DeleteFurnitureFunction:InvokeServer(model)
						mainGui.SoundEffects.AddMoney:Play()
					else
						SelectedToDeleteFurniture = nil
					end
				end
			else
				hoveredInstance = nil
			end
		end
	end
end)

furniturePlacementMenu.MenuPhone.RotateFurniture.Activated:connect(function()
	rotation += 90
	local NewPos = CFrame.new(LastPositionX,LastPositionY,LastPositionZ) * CFrame.Angles(0, math.rad(rotation), 0)
	furnitureToSpawn:SetPrimaryPartCFrame(NewPos)
end)




----Places the furniture----
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if furnitureToSpawn then
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if canPlace then
				local placedFurniture = SpawnFurnitureFunction:InvokeServer(furnitureToSpawn.Name, furnitureToSpawn.PrimaryPart.CFrame)
				if placedFurniture then
					RemovePlaceHolderFurniture()

					local config = placedFurniture:FindFirstChild("Config")
					ReplicatedStorage.Houses.Functions.FurnitureItemBought:FireServer(config)
					mainGui.SoundEffects.AddMoney:Play()
					mainGui.SoundEffects.FurniturePlacement:Play()
					wait(0.1)
					mainGui.Shops.Visible = true
					furniturePlacementMenu.Visible = false
					furniturePlacementMenu.Menu.Visible = false
					furniturePlacementMenu.MenuPhone.Visible = false
				end
			end
		elseif input.KeyCode == Enum.KeyCode.R then
			rotation += 90
		end
	elseif hoveredInstance and input.UserInputType == Enum.UserInputType.MouseButton1 then
		local model = hoveredInstance:FindFirstAncestorOfClass("Model")
		if model and model.Parent == workspace.HousePlots[ownedPlot].StarterHome.Furniture and model:FindFirstAncestor(ownedPlot) and LocalPlayer.Character:FindFirstChild("DeleteTool1") then
			SelectedToDeleteFurniture = model
			RemoteFunctions.DeleteFurnitureFunction:InvokeServer(model)
			mainGui.SoundEffects.DeleteFurniture:Play()
		else
			SelectedToDeleteFurniture = nil
		end
	end
end)

----Looks if furniture can be placed there and colors the placeholder----
RunService.RenderStepped:Connect(function()
	if UserInputService.TouchEnabled == false then
		ownedPlotValue = players.LocalPlayer:WaitForChild("PlotID").Value
		ownedPlot = "Plot" .. ownedPlotValue
		CanPlaceFurniture = workspace.HousePlots[ownedPlot]:WaitForChild("StarterHome"):WaitForChild("CanPlaceFurniture").Name
		local result = MouseRaycast({furnitureToSpawn})
		if result and result.Instance then
			if furnitureToSpawn then
				hoveredInstance = nil
				if furnitureToSpawn.Config:FindFirstChild("CanPlaceOn").Value == "Furniture" then
					if result.Instance:FindFirstAncestor(ownedPlot) and not isColliding(furnitureToSpawn) and result.Instance:FindFirstAncestor(furnitureToSpawn.Config.CanPlaceOn.Value) then
						canPlace = true
						ColorPlaceHolderFurniture(Color3.new(0.14902, 1, 0.431373))
					else
						canPlace = false
						ColorPlaceHolderFurniture(Color3.new(1, 0.321569, 0.321569))
					end

					local x = result.Position.X
					local y = result.Position.Y
					local z = result.Position.Z


					-- Apply rotation
					local cframe = CFrame.new(x,y,z) * CFrame.Angles(0, math.rad(rotation), 0)
					furnitureToSpawn:SetPrimaryPartCFrame(cframe)
				else
					if result.Instance:FindFirstAncestor(CanPlaceFurniture) and result.Instance:FindFirstAncestor(ownedPlot) and result.Instance:FindFirstAncestor(furnitureToSpawn.Config.CanPlaceOn.Value) and not isColliding(furnitureToSpawn) then
						canPlace = true
						ColorPlaceHolderFurniture(Color3.new(0.14902, 1, 0.431373))
					else
						canPlace = false
						ColorPlaceHolderFurniture(Color3.new(1, 0.321569, 0.321569))
					end

					local x = result.Position.X
					local y = result.Position.Y
					local z = result.Position.Z


					-- Apply rotation
					local cframe = CFrame.new(x,y,z) * CFrame.Angles(0, math.rad(rotation), 0)
					furnitureToSpawn:SetPrimaryPartCFrame(cframe)
				end
			else
				hoveredInstance = result.Instance
				local model = hoveredInstance:FindFirstAncestorOfClass("Model")
				if LastModel ~= nil and LastModel ~= hoveredInstance and model ~= nil then
					if LastModel and LastModel.Parent == workspace.HousePlots[ownedPlot].StarterHome.Furniture and model:FindFirstAncestor(ownedPlot) and LocalPlayer.Character:FindFirstChild("DeleteTool1") then
						if LocalPlayer.Character:FindFirstChild("DeleteTool1") then
							for i, object in ipairs(LastModel:GetDescendants()) do
								if object.Name =="BoundingBox" then
									object.Transparency = 1

									--LocalPlayer.Character:FindFirstChild("DeleteTool1").Unequipped:Connect(function()
									--	for i, object in ipairs(LastModel:GetDescendants()) do
									--		if object.Name =="BoundingBox" then
									--			object.Transparency = 1
									--		end
									--	end
									--end)
								end
							end
						end
					end
				end		
				if model and model.Parent == workspace.HousePlots[ownedPlot].StarterHome.Furniture and model:FindFirstAncestor(ownedPlot) and LocalPlayer.Character:FindFirstChild("DeleteTool1") then
					LastModel = model
					for i, object in ipairs(model:GetDescendants()) do
						if object.Name =="BoundingBox" then
							object.Transparency = 0.5
							object.Color = Color3.new(1, 0.321569, 0.321569)
						end
					end
				end
			end
		else
			hoveredInstance = nil
		end
	end
end)


