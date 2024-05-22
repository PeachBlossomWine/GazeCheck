_addon.name = 'Gaze_check'
_addon.author = 'smd111/Kenshi - Modified by K'
_addon.command = 'gazecheck'
_addon.commands = {'gaze'}
_addon.version = '5.16'

require 'luau'
require('vectors')
packets = require('packets')

defaults = {
	ap = false,
	auto_gaze = true,
	auto_perm_gaze = true,
	weak_control = false,
}

__weakened = false

gaol_zones = S{279,298}
settings = config.load(defaults)

gaze_attacks = {[284]="Cold Stare",[292]="Blank Gaze",[370]="Baleful Gaze",[386]="Awful Eye",[411]="Baleful Gaze",[438]="Hex Eye",[439]="Petro Gaze",
[502]="Mortal Ray",[550]="Hypnosis",[551]="Mind Break",[577]="Jettatura",[586]="Blank Gaze",[589]="Mortal Ray",[648]="Petro Eyes",[653]="Chaotic Eye",
[785]="Light of Penance",[1111]="Numbing Glare",[1113]="Tormentful Glare",[1138]="Hypnosis",[1139]="Mind Break",[1174]="Petro Eyes",
[1184]="Petro Eyes",[1322]="Gerjis' Grip",[1359]="Chthonian Ray",[1360]="Apocalyptic Ray",[1563]="Cold Stare",[1603]="Baleful Gaze",[1680]="Predatory Glare",
[1694]="Vile Belch",[1695]="Hypnic Lamp",[1713]="Yawn",[1716]="Frigid Shuffle",[1759]="Hypnotic Sway",[1762]="Belly Dance",[1862]="Awful Eye",[1883]="Mortal Ray",
[1950]="Belly Dance",[1978]="Abominable Belch",[2111]="Eternal Damnation",[2155]="Torpefying Charge",[2209]="Blink of Peril",[2424]="Terror Eye",[2465]="Bill Toss",
[2466]="Washtub",[2570]="Afflicting Gaze",[2534]="Minax Glare",[2602]="Mortal Blast",[2610]="Vacant Gaze",[2768]="Deathly Glare",[2814]="Yawn",[2817]="Frigid Shuffle",
[2828]="Jettatura",[3031]="Sylvan Slumber",[3032]="Crushing Gaze",[3358]="Blank Gaze",[3760]="Beguiling Gaze",[3898]="Chaotic Eye",[3916]="Jettatura",
--[1115]="Torpid Glare",
[4096]="Pain Sync",
[4192]="Fatal Allure",
[277]="Dread Spikes",
[3968]="Petrifaction",
--[3975]="Petrifying Dance",[3977]="Venomous Dance",[3978]="Raqs Baladi",
[3975]="Petrifactive Dance",[3977]="Poisonous Dance",[3978]="Luxurious Dance",

}

perm_gaze_attacks = {[3980]="Fettering Tackle",[3981]="Extirpate",[2156]="Grim Glower",[2392]="Oppressive Glare",[2776]="Shah Mat",[4121]="Repulsor",} --[3026]="Incinerating Lahar",
--,[3980]="Fettering Tackle"
--,[3981]="Extirpate"
perm_gaze_control = {["Tonberry"]={skills=T{3980, 3981},delay=3,ender=T{4}},["Peiste"]={skills=T{2156, 2392},delay=3,ender=T{4}},["Caturae"]={skills=T{2776},delay=6,ender=T{4,6}},["Quadav"]={skills=T{4121},delay=2,ender=T{4}},["Goblin"]={skills=T{4121},delay=2,ender=T{4}},["Orc"]={skills=T{4121},delay=2,ender=T{4}},}


gaze,perm_gaze,test_mode,trigered_actor,perm_trigered_actor,mob_type = false,false,false,0,0,""

function Print_Settings()
    print('Gaze_check: auto_gaze = '..(settings.auto_gaze and ('on'):text_color(0,255,0) or ('off'):text_color(255,255,255))..
        ' / auto_perm_gaze = '..(settings.auto_perm_gaze and ('on'):text_color(0,255,0) or ('off'):text_color(255,255,255))..
        '\n            ap = '..(settings.ap and ('on'):text_color(0,255,0) or ('off'):text_color(255,255,255))..
        ' / test_mode = '..(test_mode and ('on'):text_color(0,255,0) or ('off'):text_color(255,255,255)))
end

windower.register_event('load',function ()
    Print_Settings()
	zone_info = windower.ffxi.get_info()
	if gaol_zones:contains(zone_info.zone) then
		if haveBuff('SJ Restriction') then
			settings.auto_gaze = true
			windower.add_to_chat(262,'[GazeCheck] Entered/zoned in Sheol: Gaol - Enable AutoGaze')
		else
			settings.auto_gaze = false
			windower.add_to_chat(262,'[GazeCheck] Entered/zoned in A/B/C farming - DISABLE AutoGaze')
		end
	end
end)

function pet_check(index)
    local actor = windower.ffxi.get_mob_by_id(index)
    if actor and actor.index > 1024 then
        return true
    end
    return false
end
function check_target_id(packet) --checks to see if player is one of the targets
    for i,v in pairs(packet) do
        if string.match(i, 'Target %d+ ID') then
            if windower.ffxi.get_player().id == v then
                return true
            end
        end
    end
    return false
end
function check_facing(packet)
    local key_indices = {'p0','p1','p2','p3','p4','p5','a10','a11','a12','a13','a14','a15','a20','a21','a22','a23','a24','a25'}
    local party = windower.ffxi.get_party()
    local actor = windower.ffxi.get_mob_by_id(packet['Actor'])
    local player = windower.ffxi.get_mob_by_target('me')
    local dir = actor and {actor=(V{player.x, player.y} - V{actor.x, actor.y}),player=(V{actor.x, actor.y} - V{player.x, player.y})}
    local heading = {actor=(V{}.from_radian(actor.facing)),player=(V{}.from_radian(player.facing))}
    local angle = {actor=(V{}.angle(dir.actor, heading.actor):degree():abs()),player=(V{}.angle(dir.player, heading.player):degree():abs())}
    for i,v in pairs(packet) do
        if string.match(i, 'Target %d+ ID') then
            local index = windower.ffxi.get_mob_by_id(v).index
            for k = 1, 18 do
                local member = party[key_indices[k]]
                if member and member.mob and (member.mob.id == v or member.mob.pet_index == index) or actor.id == v then
                    for ind, val in pairs(packet) do  
                        if angle.player < 90 and angle.actor < 90 then
                            return true     
                        elseif string.match(ind, 'Target %d+ Action %d+ Param') then --Turn on gazes than don't need the mob to face you to apply
                            if T{1694, 1695, 1713, 1716, 1762, 1950, 1978, 2155, 2814, 2817,3031}:contains(val) and angle.player < 90 then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end
function permGazeTrue()
    perm_gaze = true
end
function check_target_action(packet)
    for i,v in pairs(packet) do
        if string.match(i, 'Target %d+ Action %d+ Param') then
		--windower.add_to_chat(7,"Mob ability/spell ID = "..tostring(v))
            if settings.auto_gaze and gaze_attacks[v] then
				--windower.add_to_chat(7,"Mob ability/spell ID = "..tostring(v))
                return true
            elseif settings.auto_perm_gaze and perm_gaze_attacks[v] then
				windower.add_to_chat(7,"Mob ability/spell ID = "..tostring(v))
                for mob,tbl in pairs(perm_gaze_control) do
                    if tbl.skills:contains(v) then
                        mob_type = mob
                        coroutine.schedule(permGazeTrue, tbl.delay)
                        break
                    end
                end
                return true
            elseif test_mode then
                windower.add_to_chat(7,"Mob ability ID = "..tostring(v))
            end
        end
    end
    return false
end
function NotDead()
    local player = windower.ffxi.get_player()
    if player.status ~= 2 and player.status ~= 3 then
       return true
    end
    return false
end
windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)
    if id == 0x00E and settings.auto_perm_gaze and perm_gaze then
        local packet = packets.parse('incoming', data)
        if packet.Index == perm_trigered_actor then
            local gaze_table = perm_gaze_control[mob_type]
            if gaze_table and (gaze_table.ender:contains(data:unpack('b8', 43)) or (packet['Status'] == 2 or packet['Status'] == 3)) then
                gaze,perm_gaze,perm_trigered_actor,mob_type = false,false,0,""
                if NotDead() then
                    windower.ffxi.turn:schedule(1,(getAngle()+180):radian())
                end
            elseif test_mode then
                windower.add_to_chat(7,"Perm Gaze end data = "..tostring(data:unpack('b8', 43)))
            end
        end
    end
    if id == 0x028 then
        local packet = packets.parse('incoming', data)
        if windower.ffxi.get_player().in_combat and windower.ffxi.get_mob_by_target('t') then
            if packet['Category'] == 7 and not pet_check(packet['Actor']) and (check_target_id(packet) or check_facing(packet)) and check_target_action(packet) then
                gaze = true
                trigered_actor = packet['Actor']
                if NotDead() then -- Turn around here
                    windower.ffxi.turn((getAngle(packet['Actor'])+180):radian()+math.pi)
					-- if haveBuff('Weakness') then
						-- __weakened = true
					-- --	move_from_to()
					-- end
                end
			-- elseif packet['Category'] == 4 and not pet_check(packet['Actor']) and check_facing(packet) and check_target_action(packet) then
                -- gaze = true
                -- trigered_actor = packet['Actor']
                -- if NotDead() then -- Turn around here
                    -- windower.ffxi.turn((getAngle(packet['Actor'])+180):radian()+math.pi)
                -- end
            elseif packet['Category'] == 11 and packet['Actor'] == trigered_actor and gaze then
                if settings.auto_gaze and gaze_attacks[packet['Param']] and not perm_gaze then
                    gaze = false
                    if NotDead() then   
                        windower.ffxi.turn:schedule(1,(getAngle()+180):radian())
                    end
                elseif settings.auto_perm_gaze and perm_gaze_attacks[packet['Param']] then
                    perm_trigered_actor = windower.ffxi.get_mob_by_id(packet['Actor']).index
                end
                trigered_actor = 0
            end
        end
    end
end)

function move_from_to()
	local min_distance = 13
	local t = windower.ffxi.get_mob_by_target('t') or nil
	local p = windower.ffxi.get_player()
	--if (S{'RUN','PLD'}:contains(p.main_job) or not t or not p.in_combat) then return end
	
	if __weakened and not (S{'RUN','PLD'}:contains(p.main_job)) then
		if p.target_locked then
			windower.send_command("wait 1; input /lockon")
		end
		coroutine.sleep(2.5)
		windower.ffxi.run(true)
		while math.sqrt(windower.ffxi.get_mob_by_index(t.index).distance) <= min_distance do
			p_2 = windower.ffxi.get_mob_by_index(p.index)
			coroutine.sleep(0.15)
		end
		windower.ffxi.run(false)
	elseif not (S{'RUN','PLD'}:contains(p.main_job)) then
		if not p.target_locked then
			windower.send_command("wait 1; input /lockon")
		end
		coroutine.sleep(2.5)
		windower.ffxi.run(true)
		while math.sqrt(windower.ffxi.get_mob_by_index(t.index).distance) >= 6 do
			p_2 = windower.ffxi.get_mob_by_index(p.index)
			coroutine.sleep(0.15)
		end
		windower.ffxi.run(false)
	end
end
function test()
windower.ffxi.turn:schedule(1,(getAngle()+180):radian())
end

function haveBuff(...)
	local args = S{...}:map(string.lower)
	local player = windower.ffxi.get_player()
	if (player ~= nil) and (player.buffs ~= nil) then
		for _,bid in pairs(player.buffs) do
			local buff = res.buffs[bid]
			if args:contains(buff.en:lower()) then
				return true
			end
		end
	end
	return false
end

function getAngle(index)
    local P = windower.ffxi.get_mob_by_target('me') --get player
    local M = index and windower.ffxi.get_mob_by_id(index) or windower.ffxi.get_mob_by_target('t') --get target
    local delta = {Y = (P.y - M.y),X = (P.x - M.x)} --subtracts target pos from player pos
    local angleInDegrees = (math.atan2( delta.Y, delta.X) * 180 / math.pi)*-1 
    local mult = 10^0
    return math.floor(angleInDegrees * mult + 0.5) / mult
end


function isMonster()
	local mob_in_question = windower.ffxi.get_mob_by_target('t')
	if mob_in_question and mob_in_question.is_npc and mob_in_question.spawn_type == 16 and mob_in_question.valid_target then
		return true
    else
        return false
	end
end

function handle_lose_buff(buff_id)
	if buff_id == 1 then
		__weakened = false
		if gaze and perm_gaze then
			--move_from_to()
		end
		gaze = false
		perm_gaze = false
	end
end	

windower.register_event('prerender', function()
    local player = windower.ffxi.get_player()
    if not windower.ffxi.get_info().logged_in or not player then -- stops prender if not loged in yet
        return
    end
    if (player.in_combat and settings.ap and isMonster() and NotDead()) and not gaze and not perm_gaze then
		windower.ffxi.turn((getAngle()+180):radian())--gets angle to the target
    end
end)

function haveBuff(...)
	local args = S{...}:map(string.lower)
	local player = windower.ffxi.get_player()
	if (player ~= nil) and (player.buffs ~= nil) then
		for _,bid in pairs(player.buffs) do
			local buff = res.buffs[bid]
			if args:contains(buff.en:lower()) then
				return true
			end
		end
	end
	return false
end

windower.register_event('lose buff', handle_lose_buff)

windower.register_event('addon command', function(input, ...)

	local cmd
	if input ~= nil then
		cmd = string.lower(input)
	end
	
	local args = {...}
	local cmd2 = args[1]
	
	if cmd == 'ap' then
		if cmd2 == 'on' then
			settings.ap = true
		elseif cmd2 == 'off' then
			settings.ap = false
		end
	elseif cmd == 'ag' then
		if cmd2 == 'on' then
			settings.auto_gaze = true
		elseif cmd2 == 'off' then
			settings.auto_gaze = false
		end
	elseif cmd == 'weak' then
		if cmd2 == 'on' then
			settings.weak_control = true
		elseif cmd2 == 'off' then
			settings.weak_control = false
		end
	elseif cmd == 'testw' then
			__weakened = true
			move_from_to()
	elseif cmd == 'testu' then
			__weakened = false
			move_from_to()
	elseif cmd == 'test' then
		test()
	end
	
    if cmd then
        Print_Settings()
        config.save(settings, 'all')
    end
end)

windower.register_event('zone change', function(new_id, old_id)
	zone_info = windower.ffxi.get_info()
	coroutine.sleep(10)
	if gaol_zones:contains(zone_info.zone) then
	
		if haveBuff('SJ Restriction') then
			settings.auto_gaze = true
			Print_Settings()
			windower.add_to_chat(262,'[GazeCheck] Entered/zoned in Sheol: Gaol - Enable AutoGaze')
		else
			settings.auto_gaze = false
			Print_Settings()
			windower.add_to_chat(262,'[GazeCheck] Entered/zoned in A/B/C farming - DISABLE AutoGaze')
		end
	end 
	
	if gaol_zones:contains(old_id) and not gaol_zones:contains(new_id) then
		Print_Settings()
		settings.auto_gaze = true
		windower.add_to_chat(262,'[GazeCheck] Exiting Sheol: Gaol zones.')
	end
	
end)