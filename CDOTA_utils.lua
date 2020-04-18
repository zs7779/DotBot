-- Extend helper functions to CDOTA_Bot_Script class, which is the class of the Bot objects

local debug = true;

function CDOTA_Bot_Script:InitializeBot()
    if debug then
        print(self:GetUnitName());
    end

    self.is_initialized = false;
    self:GetPlayerPosition();
    self:GetAbilities();
    self.is_initialized = true;

    if debug then
        print("Initialized");
    end
end

-- Get Bot position in game as a number between 1-5, 1 being carry, 5 being hard support
function CDOTA_Bot_Script:GetPlayerPosition()
    if self.position == nil then
        for position = 1, 5 do
            if self == GetTeamMember(position) then
                self.position = position;
                break;
            end
        end    
    end

    if debug then
        print("Position", self.position);
    end
	return self.position;
end

function CDOTA_Bot_Script:GetAbilities()
    -- save a list of abilities to self
    local abilities = {};
    if self.abilities_slots == nil then
        for i = 0, 23 do
            local ability = self:GetAbilityInSlot(i);
            if ability ~= nil and not ability:IsTalent() and not ability:IsItem() and not ability:IsHidden() and not ability:IsPassive() then
                abilities[#abilities+1] = i;
            end
        end
        self.abilities_slots = abilities;
    end

    if debug then
        print("Abilities")
        for i = 1, #abilities do
            local ability = self:GetAbilityInSlot(self.abilities_slots[i]);
            print(self.abilities_slots[i], ability:GetName());
        end
    end
	return self.abilities_slots;
end

function CDOTA_Bot_Script:GetComboMana()
    local mana_cost = 0;
    if self.abilities_slots ~= nil then
        for i = 1, #self.abilities_slots do
            local ability = self:GetAbilityInSlot(self.abilities_slots[i]);
            mana_cost = mana_cost + ability:GetManaCost();
        end
    end
    return mana_cost;
end

function CDOTA_Bot_Script:EstimateFriendsDisableTime(distance)
    -- estimate total disable time among friends within distance, I'm guessing 0 means just myself
    local stun_factor, slow_factor = 1.0, 0.5;
    local distance = distance or 0;
    local nearby_friends = self:GetNearbyHeroes(distance, false, BOT_MODE_NONE);
    local stun_time, slow_time = 0, 0;
    for i = 1, #nearby_friends do
        if nearby_friends[i]:IsAlive() then
            stun_time = stun_time + nearby_friends[i]:GetStunDuration(true);
            slow_time = slow_time + nearby_friends[i]:GetSlowDuration(true);
        end
    end
    return stun_factor * (stun_time + slow_factor * slow_time);
end

function CDOTA_Bot_Script:EstimatePower(disable_time)
    -- mean to be a rough estimate, better than GetOffensivePower, probably worse than GetEstimatedDamageToTarget
    -- still considering if the factors should be args. it would complicate the
    -- power immediately drops after cast stun, problem!
    local physical_factor, magic_factor, free_attacks = 0.65, 0.75, 3;
    local physical_damage = 0;
    local magic_damage = 0;
    local pure_damage = 0;
    local mana_cost = 1;
    if self.abilities_slots ~= nil then
        for i = 1, #self.abilities_slots do
            local ability = self:GetAbilityInSlot(self.abilities_slots[i]);
            if ability:IsFullyCastable() then
                mana_cost = mana_cost + ability:GetManaCost();

                local ability_damage_type = ability:GetDamageType();
                local ability_damage = ability:GetAbilityDamage();
                
                if ability_damage_type == DAMAGE_TYPE_PHYSICAL then
                    physical_damage = physical_damage + ability_damage;
                elseif ability_damage_type == DAMAGE_TYPE_MAGICAL then
                    magic_damage = magic_damage + ability_damage;
                else
                    pure_damage = pure_damage + ability_damage;
                end
            end
        end
    end
    local total_power = (physical_factor * physical_damage + magic_factor * magic_damage + pure_damage) * (math.min(self:GetMana(), mana_cost) / mana_cost);
    local disable_time = disable_time or self:EstimateFriendsDisableTime();
    local num_attacks = math.max((disable_time + free_attacks) / (self:GetSecondsPerAttack()+0.01), free_attacks);
    total_power = total_power + self:GetAttackDamage() * num_attacks;
    return total_power;    
end

function CDOTA_Bot_Script:EstimateFriendsPower(distance)
    local distance = distance or 0;
    local nearby_friends = self:GetNearbyHeroes(distance, false, BOT_MODE_NONE);
    local disable_time = self:EstimateFriendsDisableTime(distance);
    local power = 0;
    for i = 1, #nearby_friends do
        if nearby_friends[i]:IsAlive() then
            -- power = power + nearby_friends[i]:EstimatePower(disable_time);
            power = power + nearby_friends[i]:GetOffensivePower();
        end
    end
    return power;
end

function CDOTA_Bot_Script:EstimateFriendsDamageToTarget(distance, target)
    local distance = distance or 0;
    local nearby_friends = self:GetNearbyHeroes(distance, false, BOT_MODE_NONE);
    local disable_time = self:EstimateFriendsDisableTime(distance);
    local damage = 0;
    for i = 1, #nearby_friends do
        if nearby_friends[i]:IsAlive() then
            -- power = power + nearby_friends[i]:EstimatePower(disable_time);
            damage = damage + nearby_friends[i]:GetEstimatedDamageToTarget(true, target, disable_time, DAMAGE_TYPE_ALL);
        end
    end
    return damage;
end

function CDOTA_Bot_Script:EstimateEnimiesPower(distance)
    -- Need to add something so it doesnt count illusion twice
    local distance = distance or 0;
    local nearby_enemies = self:GetNearbyHeroes(distance, true, BOT_MODE_NONE);
    -- local disable_time = self:EstimateFriendsDisableTime(distance);
    local power = 0;
    if nearby_enemies == nil then
        return power;
    end
    for i = 1, #nearby_enemies do
        if nearby_enemies[i]:IsAlive() then
            -- power = power + nearby_friends[i]:EstimatePower(disable_time);
            power = power + nearby_enemies[i]:GetRawOffensivePower();
        end
    end
    return power;
end

function CDOTA_Bot_Script:FindWeakestEnemy(distance)
    local distance = distance or 150;
    local nearby_enemies = self:GetNearbyHeroes(distance, true, BOT_MODE_NONE);
    local smallest_health = 1000000;
    local weakest_enemy = nil;
    for i = 1, #nearby_enemies do
        if nearby_enemies[i]:IsAlive() and nearby_enemies[i]:CanBeSeen() then
            local enemy_health = nearby_enemies[i]:GetHealth();
            if enemy_health < smallest_health then
                smallest_health = enemy_health;
                weakest_enemy = nearby_enemies[i];
            end
        end
    end
    return weakest_enemy;
end

function CDOTA_Bot_Script:GetFriendsTarget(distance)
    local distance = distance or 0;
    local nearby_friends = self:GetNearbyHeroes(distance, false, BOT_MODE_NONE);
    for i = 1, #nearby_friends do
        if nearby_friends[i]:IsAlive() and nearby_friends[i]:GetActiveMode() == BOT_MODE_ATTACK then
            return nearby_friends[i]:GetTarget();
        end
    end
    return nil;
end

function CDOTA_Bot_Script:DecideRoamRune(runes, rune_spawned)
    local min_distance = 1000000;
    local nearest_rune = nil;
    for _, rune in pairs(runes) do
        if not rune_spawned or GetRuneStatus(rune) ~= RUNE_STATUS_MISSING then
            local rune_location = GetRuneSpawnLocation(rune);
            local rune_distance = GetUnitToLocationDistance(self, rune_location);
            if rune_distance < min_distance and rune_distance < 3500 then
                min_distance = rune_distance;
                nearest_rune = rune;
            end
        end
    end
    self.rune = nearest_rune;
end

function CDOTA_Bot_Script:PickUpRune()
    if self.rune ~= nil then
        self:Action_PickUpRune(self.rune);
        self.rune = nil;
    end
end

function CDOTA_Bot_Script.AllRunesUnavailable(runes)
    for _, rune in pairs(runes) do
        if GetRuneStatus(rune) ~= RUNE_STATUS_MISSING or
            GetUnitToLocationDistance(self, GetRuneSpawnLocation(rune)) < 3500 then
                return true;
            end
    end
    return false;
end
function CDOTA_Bot_Script.IhaveShowed()
end