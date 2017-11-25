require( GetScriptDirectory().."/utils" ) 
item_purchase_generic = dofile( GetScriptDirectory().."/item_purchase_generic" )

local itemGuide = {};

function GetItemGuide(itemLists)
	if itemLists == nil then return; end
	for listName, list in pairs(itemLists) do
		itemGuide[listName] = {};
		local totalCost = 0;
		for _, item in ipairs(list) do
			totalCost = totalCost + GetItemCost(item);
			table.insert(itemGuide[listName], {['cost']=totalCost, ['item']=item});
		end
	end
end

function ItemPurchaseThink()
	local itemLists = {
		[1] = {
			"item_tango",
			"item_enchanted_mango",
			"item_flask",
			"item_clarity",
		},
		[2] = {
			"item_arcane_boots",
			"item_hood_of_defiance",
		},
		[3] = {
			"item_arcane_boots",
			"item_mekansm", -- 3 mek
			"item_pipe", -- 4 pipe
			"item_blink", -- 5
			"item_shivas_guard", -- *1 shivas
		},
		[4] = {
			"item_guardian_greaves", -- *3 bot2
			"item_pipe", -- 4 pipe
			"item_blink", -- 5
			"item_shivas_guard", -- *1 shivas
			"item_recipe_refresher", -- 6 refresher
			"item_ultimate_scepter",
		},
	};
	if GetGameState() < GAME_STATE_PRE_GAME then return; end
	if #itemGuide == 0 then
		GetItemGuide(itemLists);
	end
	item_purchase_generic.ItemPurchaseThink();

	local I = GetBot();
	if DotaTime() < 0 then
		item_purchase_generic.PurchaseItem(I, itemGuide[1]);
		return;
	end
	for list = 2,3 do
		if I:GetNetWorth() < itemGuide[list][#itemGuide[list]]['cost'] then
			item_purchase_generic.PurchaseItem(I, itemGuide[list]);
			return;
		end
	end
	item_purchase_generic.PurchaseItem(I, itemGuide[4]);
end