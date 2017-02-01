Utility = require( GetScriptDirectory().."/Utility" );
local GetRune = Utility.GetRune;
local Locations = Utility.Locations;

_G._savedEnv = getfenv()
module( "mode_rune_generic", package.seeall )

-- Called every ~300ms, and needs to return a floating-point value between 0 and 1 that indicates how much this mode wants to be the active mode.
function GetDesire()
	if (GetGameState( ) ~= GAME_STATE_GAME_IN_PROGRESS and GetGameState( ) ~= GAME_STATE_PRE_GAME) then return 0.0 end

	local time = DotaTime();
	local npcBot = GetBot();
	if time <= 1 then return 0.9 end
	if time < 18 and npcBot:GetAssignedLane() == 4 then return 0.0 end

	for rune = RUNE_POWERUP_1,RUNE_BOUNTY_4 do
		if GetUnitToLocationDistance(npcBot,GetRuneSpawnLocation( rune )) < 200 and GetRuneStatus(rune) == RUNE_STATUS_AVAILABLE then
			return 0.9;
		end
	end

	local runeTime = time%120;
	if runeTime < 20 or runeTime > 110 then
		return 0.8;
	end
	return 0;
end

-- Called when a mode takes control as the active mode.
function OnStart()
end

-- Called when a mode relinquishes control to another active mode.
function OnEnd()
end

-- Called every frame while this is the active mode. Responsible for issuing actions for the bot to take.
function Think()
	local npcBot = GetBot();
	local team = GetTeam();
	local time = DotaTime();
	
	if time <= 3 then
		if npcBot:GetAssignedLane() == 2 then GetRune(npcBot,RUNE_BOUNTY_2)
		elseif npcBot:GetAssignedLane() == 5 then GetRune(npcBot,RUNE_BOUNTY_1)
		elseif npcBot:GetAssignedLane() == 3 then npcBot:Action_MoveToLocation( Locations[team].TopShrine )
		elseif npcBot:GetAssignedLane() == 1 then npcBot:Action_MoveToLocation( Locations[team].BotShrine )
		elseif npcBot:GetAssignedLane() == 4 then npcBot:Action_MoveToLocation( Locations[team].MidBlock )
		end
	else
		for rune = RUNE_POWERUP_1,RUNE_BOUNTY_4 do
			if GetUnitToLocationDistance( npcBot, GetRuneSpawnLocation( rune ) ) < 2000 then
				GetRune(npcBot,rune);
			end
		end
	end

end

for k,v in pairs(mode_rune_generic) do _G._savedEnv[k] = v end