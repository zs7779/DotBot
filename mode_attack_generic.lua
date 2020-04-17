utils = require(GetScriptDirectory().."/utils");
mode_utils = require(GetScriptDirectory().."/mode_utils");
require(GetScriptDirectory().."/CDOTA_utils");

update_time = 0;
passiveness = 0.6;

function GetDesire()
    local this_bot = GetBot();
    local time = DotaTime();
    local this_bot_level = this_bot:GetLevel();
    if not this_bot.is_initialized then
        this_bot:InitializeBot();
    end
    if not this_bot:IsAlive() then
        return 0;
    end

    if time > update_time then
        print(this_bot:GetUnitName().." Power "..this_bot:EstimatePower().." Disable "..this_bot:EstimateFriendsDisableTime(0));
        update_time = update_time + 30;
        if passiveness < mode_utils.passiveness_factor then
            passiveness = passiveness + 0.025;
        end
    end

    local current_target = this_bot:GetFriendsTarget(1200);
    if current_target ~= nil and current_target:IsAlive() and current_target:CanBeSeen() then
        return mode_utils.mode_desire.attack;
        -- { {location, time_since_seen}, ...} GetHeroLastSeenInfo( nPlayerID ) 
    end
    -- Assault
    -- Kill
    local weakest_enemy = this_bot:FindWeakestEnemy(1200);
    if weakest_enemy ~= nil and this_bot:EstimateFriendsPower(1200) > passiveness * weakest_enemy:GetHealth() then
        this_bot:SetTarget(weakest_enemy);
        print("Target "..weakest_enemy:GetUnitName().." Health "..weakest_enemy:GetHealth().." Power "..this_bot:EstimateFriendsPower(1200));
        return mode_utils.mode_desire.attack;
    end
    return 0;	
end

function OnEnd()
    local this_bot = GetBot();
    this_bot:SetTarget(nil);
end