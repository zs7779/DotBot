require(GetScriptDirectory() ..  "/utils")

function TableCat(tA, tB)
	for _, b in ipairs(tB) do
		table.insert(tA, b);
	end
	return tA;
end
function GetBaseParts(item)
	if item == nil then return {}; end
	local bassParts = {};
	local parts = GetItemComponents(item);
	if #parts == 0 then
		bassParts = {item};
		return bassParts;
	else
		for _, part in ipairs(parts[1]) do
			TableCat(bassParts,GetBaseParts(part));
		end
	end
	return bassParts;
end
function GetParts(item)
	if item == nil then return {}; end
	local parts = GetItemComponents(item);
	if #parts == 0 then
		return {item};
	else
		parts = parts[1];
		table.sort(parts, function(a,b) return a:find("boots") or b:find("recipe") end);
		return parts;
	end
end
function HasUsefulPart(trash, list) -- trash is item object
	if not trash:CanBeDisassembled() or list == nil or #list == 0 then return nil; end
	trash = trash:GetName();
	if ItemIsInList(trash, list) then return trash; end
	for _, trashPart in ipairs(GetParts(trash)) do -- but trashPart is string? wtf?
		if ItemIsInList(trashPart, list) then return trashPart; end
	end
	return nil;
end
function ItemIsInList(item, list)
	for _, thing in ipairs(list) do
		if item == thing then return true; end
	end
	return false;
end

function GetItemGuide(itemLists, itemGuide)
	if itemLists == nil then return; end
	for listName, list in pairs(itemLists) do
		itemGuide[listName] = {};
		local totalCost = 0;
		for _, item in ipairs(list) do
			local cost = totalCost;
			totalCost = totalCost + GetItemCost(item);
			table.insert(itemGuide[listName], {['cost']=cost, ['item']=item, ['worth']=totalCost});
		end
	end
	return itemGuide
end

local itemParts = {};
local trashBin = {};

function PurchaseItem(I, itemGuide)
	if I == nil or not I:IsHero() or I:IsIllusion() then return; end
	if #itemGuide == 0 and (itemParts == nil or #itemParts == 0) then
		I:SetNextItemPurchaseValue(0);
		return;
	end

	local courier;
	if GetNumCouriers() > 0 then
		courier = GetCourier(0);
	end

	if itemParts == nil or #itemParts == 0 then
		for _, wantItem in ipairs(itemGuide) do
			-- print(I:GetUnitName(),wantItem['cost'],wantItem['item'])
			if I:GetNetWorth() > wantItem['cost'] and -- <- get first item you should have but don't
			   not utils.HaveItem(wantItem['item'], I, courier) then -- <- this is assuming I can only see my items on courier
			    itemParts = GetParts(wantItem['item']);
			    break;
			end
		end
	end

	if itemParts == nil or #itemParts == 0 then return; end

-- for unwantedly combined item: bloodstone -> mana boot, 2 options
-- 1. disassemble as soon as seeing unwanted item
-- 2. disassemble when needed
	for slot = 0,16 do
		local trashH = I:GetItemInSlot(slot);
		if trashH ~= nil then
			local trashName = trashH:GetName();
			if not ItemIsInList(trashName, itemGuide) and -- not on itemGuide
			   not HasUsefulPart(trashH, itemParts) then -- its parts also not the item I currently want?
				table.insert(trashBin, trashName);
			end
		end
	end

	local idx = 1;
	local checkList = {[I]={},['courier']={}};
	while idx <= #itemParts do
		local part = itemParts[idx];
		-- print(idx,part)
		local partHandle, unitHandle, slot = utils.HaveItem(part, I, courier, checkList);
		if partHandle then -- If already have this part, remove
			if unitHandle == I then
				table.insert(checkList[I], slot);
			else
				table.insert(checkList['courier'], slot);
			end
			unitHandle:ActionImmediate_SetItemCombineLock(partHandle, false); -- make sure the part is not locked
			table.remove(itemParts, idx);
		else
			-- if not found, check if it has its own parts
			local parts = GetParts(part);
			if #parts > 1 then
				table.remove(itemParts, idx); -- <- adding to table in the loop may cause problem?
				TableCat(itemParts,parts);
			else
				idx = idx + 1;
			end
		end
	end

	-- now itemParts are all base parts I don't have
	-- check if it's part of any trash
	local item;
	if utils.HaveItem("item_tpscroll", I, courier) or
	   utils.HaveItem("item_travel_boots", I, courier) or
	   utils.HaveItem("item_travel_boots_2", I, courier) then
		item = itemParts[1];
	else
		item = "item_tpscroll";
	end
	-- print(I:GetUnitName(),item)
	if item == "item_energy_booster" and
	   not ItemIsInList("item_arcane_boots", itemGuide) then
		local manaBoot, unitHandle = utils.HaveItem("item_arcane_boots", I, courier);
		if manaBoot ~= nil then
			unitHandle:ActionImmediate_DisassembleItem(manaBoot);
			local booster, unitHandle = utils.HaveItem("item_energy_booster", I, courier);
			unitHandle:ActionImmediate_SetItemCombineLock(booster, false);
			table.remove(itemParts, 1);
			return;
		end
	end
	
	if item == nil then
		I:SetNextItemPurchaseValue(0);
		return;
	end
	
-- -----*****TODO: if dont have slot, sell an item not on guide!!! after 10 min sell all tango, if don't want regen sell salve, clarity..

	local itemCost = GetItemCost(item);
	if I:GetGold() > itemCost+50 then
		if not I:HaveSlot() and
			(I:DistanceFromSecretShop() == 0 or
 			 I:DistanceFromSideShop() == 0 or
 			 I:DistanceFromFountain() == 0) then
			SellItem(I, trashBin);
		end

		-- if item is in secret shop or in nearby side shop

		if I.purchaseResult == nil then I.purchaseResult = 0; end
		if I.purchaseResult == 66 or I.purchaseResult == 67 or I.purchaseResult == 62 or  -- NOT_AT_SIDE_SHOP=66 NOT_AT_HOME_SHOP=67 NOT_AT_SECRET=62
		   IsItemPurchasedFromSecretShop(item) and I:DistanceFromSecretShop() < 2000 then
			if I:DistanceFromSecretShop() == 0 then -- at shop
				I.purchaseResult = I:ActionImmediate_PurchaseItem(item);
			elseif courier ~= nil and courier:DistanceFromSecretShop() == 0 and courier:HaveSlot() then
				I.purchaseResult = courier:ActionImmediate_PurchaseItem(item);
			else -- walk if have slot else dunkey
				I.secretShopMode = true;
			end
		elseif IsItemPurchasedFromSideShop(item) and I:DistanceFromSideShop() < 2000 then
			if I:DistanceFromSideShop() == 0 then
				I.purchaseResult = I:ActionImmediate_PurchaseItem(item);
			elseif courier ~= nil and courier:DistanceFromSideShop() == 0 and courier:HaveSlot() then
				I.purchaseResult = courier:ActionImmediate_PurchaseItem(item);
			else -- walk
				I.sideShopMode = true;
			end
		elseif I.purchaseResult ~= 66 and I.purchaseResult ~= 67 and I.purchaseResult ~= 62 then -- PURCHASE_ITEM_NOT_AT_SIDE_SHOP=66 PURCHASE_ITEM_NOT_AT_HOME_SHOP=67
			if I:DistanceFromFountain() == 0 then
				I.purchaseResult = I:ActionImmediate_PurchaseItem(item);
			elseif courier ~= nil and courier:DistanceFromSecretShop() == 0 and courier:HaveSlot() then
				I.purchaseResult = courier:ActionImmediate_PurchaseItem(item);
			else
				I.purchaseResult = I:ActionImmediate_PurchaseItem(item);
			end
		end
		if I.purchaseResult == PURCHASE_ITEM_SUCCESS then
			table.remove(itemParts, 1);
			I.purchaseResult = 0;
			I.secretShopMode = nil;
			I.sideShopMode = nil;
			return;
		end
	end
	I:SetNextItemPurchaseValue(itemCost);
end

function SellItem(I, trash)
	local consumableGoods = {
		"item_tango",
		"item_faerie_fire",
		"item_flask",
		"item_clarity"
	};
	for slot = 0,16 do
		local item = I:GetItemInSlot(slot);
		if item ~= nil then
			for _, good in ipairs(consumableGoods) do
				if item:GetName() == good then
					I:ActionImmediate_SellItem(item);
					return;
				end
			end
			if item:GetName() == trash[1] then
				I:ActionImmediate_SellItem(item);
				table.remove(trash, 1);
				return; -- sell just one, see if space available
			end
		end
	end
end

function BuySupportItem(I)
	local detectionItems = {
		"item_gem",
		"item_ward_sentry"
	};
	if GetNumCouriers() == 0 and
	   I:GetGold() >= GetItemCost("item_courier") then
		local purchaseResult = I:ActionImmediate_PurchaseItem("item_courier");
	end
	
	if GetItemStockCount("item_ward_observer") >= 0 and
	   I:GetGold() > GetItemCost("item_ward_observer") then
	   purchaseResult = I:ActionImmediate_PurchaseItem("item_ward_observer");
	end
end

function ItemPurchaseThink()
	local I = GetBot();
	if I:GetPlayerPosition() == 5 then
		BuySupportItem(I);
	end
end

BotsInit = require( "game/botsinit" );
local item_purchase_generic = BotsInit.CreateGeneric();
item_purchase_generic.PurchaseItem = PurchaseItem;
item_purchase_generic.ItemPurchaseThink = ItemPurchaseThink;
item_purchase_generic.GetItemGuide = GetItemGuide;
return item_purchase_generic;