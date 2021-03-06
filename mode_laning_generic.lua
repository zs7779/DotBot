utils = require(GetScriptDirectory().."/utils");
enums = require(GetScriptDirectory().."/enums");
require(GetScriptDirectory().."/CDOTA_utils");

update_time = 15;
-- Called every ~300ms, and needs to return a floating-point value between 0 and 1 that indicates how much this mode wants to be the active mode.
function GetDesire()
    local this_bot = GetBot();
    local time = DotaTime();
    if not this_bot.is_initialized then
        this_bot:InitializeBot();
    end
    if not this_bot:IsAlive() then
        return 0;
    end

    local this_bot_level = this_bot:GetLevel();
    local lane_front = GetLaneFrontLocation(this_bot:GetTeam(), this_bot:GetAssignedLane(), 0);
    local this_bot_tower, _ = utils.GetLaneTower(this_bot:GetTeam(), this_bot:GetAssignedLane());
    
    if time > update_time then
        -- print(this_bot:GetUnitName().." Tower "..GetUnitToLocationDistance(this_bot_tower, lane_front));
        update_time = update_time + 30;
    end

    if time < 0 then
        return enums.mode_desire.laning;
    end
    if this_bot_level < 7 then
        -- Time < 5 minutes or level < 7
        -- if lane is not too far from tower
        -- and if laning enemy is not too strong
        -- if GetUnitToLocationDistance(this_bot_tower, lane_front) < 5000 then
            local lane_danger = 0;
            lane_danger = this_bot_tower:EstimateEnemiesDamageToTarget(1600, this_bot);
            if lane_danger < enums.stupidity * this_bot:GetHealth() then
                this_bot.help = false;
                if this_bot.pull_state then
                    return 0;
                else
                    return enums.mode_desire.laning;
                end
            elseif this_bot.position <= 3 then
                this_bot.help = true;
                return enums.mode_desire.laning;
            elseif this_bot.position >= 4 then
                local friend_need_help = this_bot:FriendNeedHelpNearby(1200);
                if friend_need_help ~= nil then
                    print(friend_need_help:GetUnitName().." need help")
                    return enums.mode_desire.laning;
                end
                -- todo: 4 position always in else??
            end
        -- end
    end
    -- GetAssignedLane() 
    -- vector GetLaneFrontLocation( nTeam, nLane, fDeltaFromFront ) 
    -- GetUnitToLocationDistance( hUnit, vLocation ) 
    return 0;	
end
