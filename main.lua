-- BashNBounce
-- ANXvariable

log.info("Loading ".._ENV["!guid"]..".")

mods["LuaENVY-ENVY"].auto()
mods["ReturnsAPI-ReturnsAPI"].auto{
    namespace = "bashnbounce",
    mp = true
}

local PATH = _ENV["!plugins_mod_folder_path"]
local NAMESPACE = "anx"

local bash_handle_step = function(actor, data)
end

local bounce_handle_step = function(actor, data)
	if not actor.free and actor.actor_state_current_id == -1 then
		actor.moveUp = 1
	end
end

local _survivor_bounce_find_target = function(actor, distance, angle)
	local direction = 270 + (45 * actor.image_xscale)
	local p = actor:find_characters_circle(actor.x, actor.y, distance, false, actor.team, false)
	--Util.print(p)
	--Util.print(Global.__find_allies_list)
	local potential_targets = List.wrap(p)
	--potential_targets:print()
	local potential_target_num = potential_targets:size()
	local target = -4
	local i = 0

	for i = 0, potential_target_num do
		if potential_target_num > 0 and i ~= potential_target_num then
			local entry = potential_targets:get(i)
			--Util.print(potential_target_num, entry, i)
			if math.abs(entry:angle_difference(entry:point_direction(actor.x, actor.y, entry.x, entry.y), direction)) < angle then
				local d = entry:distance_to_object(actor)
				if d < distance and actor:collision_line_advanced_bullet(actor.x, actor.y - 11, entry.x, entry.y, false, true) == entry then
					distance = d
					target = entry
				end
			end
		end
	end

	return target
end

local actor_phy_set_pSpeed_vector = function(actor, speed, direction)
	actor.pVspeed = speed * -math.sin(math.rad(direction))
	actor.pHspeed = speed * math.cos(math.rad(direction))
end

local alarm_ai_inherit_items = function(src, dest, flags)
	local src_item_stack = src.inventory_item_stack
	local i = Global.count_item - 1

	while i > 0 do
		if Util.bool(src_item_stack:get(i)) and (Item.wrap(i).loot_tags & flags == 0) then
			for j = 0, 2 do
				local s = src:item_count(i, 0)
				local d = dest:item_count(i, 0)
				if s > d then
					dest:item_give(Item.wrap(i), s - d, j)
				elseif s < d then
					dest:item_take(Item.wrap(i), d - s, j)
				end
			end
		end

		i = i - 1
	end
end

-- ========== Main ==========

local initialize = function()
    hotload = true
    local bashnbounce = Survivor.new("bashnbounce")
    local oBuddy = Object.new("BashNBounceBuddy", Object.Parent.ACTOR)
	local oBashMissle = Object.new("BashMissile")
	local oReticle = Object.new("BounceReticle")

    -- Utility function for getting paths concisely
    local rapi_sprite = function(identifier, filename, image_number, x_origin, y_origin) 
        local sprite_path = path.combine(PATH, "Sprites",  filename)
        return Sprite.new(identifier, sprite_path, image_number, x_origin, y_origin)
    end
    local rapi_sound = function(id, filename)
        local sound_path = path.combine(PATH, "Sounds", filename)
        return Sound.new(id, sound_path)
    end

	local sBashMissile = rapi_sprite("bashMissile", "sMMWWHardKnuckle.png", 1, 16, 6)

    --local doubleTap = function(actor, button, window)
    --    actor.doubleTapTimer = (actor.doubleTapTimer or 1) - 1
    --    if actor:control(button, 1) then
    --        if actor.doubleTapTimer > 0 then
    --            return true
    --        else
    --            actor.doubleTapTimer = window
    --            return false
    --        end
    --    else
    --        return false
    --    end
    --end
    
    -- Load the common survivor sprites into a table
    local sprites = {
        idle		= rapi_sprite("bashIdle", "sBashIdle.png", 5, 13, 15),
        walk		= gm.constants.sHuntressWalk,
        jump		= gm.constants.sHuntressJump,
        jump_peak	= gm.constants.sHuntressJumpPeak,
        fall		= gm.constants.sHuntressFall,
        climb		= gm.constants.sHuntressClimb,
        climb_hurt	= gm.constants.sHuntressClimb,
        death		= gm.constants.sHuntressDeath,
        decoy		= gm.constants.sHuntressDecoy
    }
    
    --placeholder category, todo organize later
    local sBashNBounceSkills = gm.constants.sHuntressSkills
	local sBashNBouncePalette = Sprite.wrap(gm.constants.sHuntressPalette)
    --local spr_loadout = 
    --local spr_portrait = 
    --local spr_portrait_small = 
    --local spr_portrait_cropped = 
    --local spr_log = 
    
    -- Colour for the character's skill names on character select
    --bashnbounce:set_primary_color(Color.FUCHSIA)

    -- Assign sprites to various survivor fields
	bashnbounce.sprite_palette		= sBashNBouncePalette
    --bashnbounce.sprite_loadout = spr_loadout
    --bashnbounce.sprite_portrait = spr_portrait
    --bashnbounce.sprite_portrait_small = spr_portrait_small
    --bashnbounce.sprite_portrait_palette = spr_portrait_cropped
    bashnbounce.sprite_title		= sprites.walk
    bashnbounce.sprite_idle			= sprites.idle
    bashnbounce.sprite_credits		= sprites.idle
    
    --set animations

    bashnbounce.sprite_idle			= sprites.idle
    
    -- Offset for the Prophet's Cape
    bashnbounce.cape_offset			= Array.new({-1, -6, -1, -11}) 

    local bashnbounce_log = SurvivorLog.new_from_survivor(bashnbounce)

    --Survivor stats
    
    bashnbounce:set_stats_base({
    })

    bashnbounce:set_stats_level({
    })

    Callback.add(bashnbounce.on_init, function(actor)
        local data = Instance.get_data(actor)
		actor.sprite_idle_half		= Array.new({sprites.idle, gm.constants.sHuntressIdleHalf, 0})
		actor.sprite_walk_half		= Array.new({sprites.walk, gm.constants.sHuntressWalkHalf, 0, gm.constants.sHuntressWalkBack})
		actor.sprite_jump_half		= Array.new({sprites.jump, gm.constants.sHuntressJumpHalf, 0})
		actor.sprite_jump_peak_half	= Array.new({sprites.jump_peak, gm.constants.sHuntressJumpPeakHalf, 0})
		actor.sprite_fall_half		= Array.new({sprites.fall, gm.constants.sHuntressFallHalf, 0})
		actor:survivor_util_init_half_sprites()
        actor.sprite_idle			= sprites.idle
        actor.sprite_walk			= sprites.walk
        --actor.sprite_walk_last     = sprites.walk_last
        actor.sprite_jump			= sprites.jump
        actor.sprite_jump_peak		= sprites.jump_peak
        actor.sprite_fall			= sprites.fall
        actor.sprite_climb			= sprites.climb
        actor.sprite_death			= sprites.death
        actor.sprite_decoy			= sprites.decoy
        --actor.sprite_drone_idle    = sprites.drone_idle
        --actor.sprite_drone_shoot   = sprites.drone_shoot
        actor.sprite_climb_hurt		= sprites.climb_hurt
	    actor.sprite_palette		= sBashNBouncePalette
        local found = false

        for _, buddy in ipairs(Instance.find_all(Object.find("BashNBounceBuddy"))) do
            if buddy.parent == actor.value then
                found = true
                if data.buddy ~= buddy.value then data.buddy = buddy.value end
                break
            end
        end

        if not found then
			local buddy = oBuddy:create(actor.x, actor.y)
            data.buddy = buddy
            buddy.parent = actor
            buddy.m_id = actor.m_id
            actor:actor_team_set(buddy, actor.team)
            --data.buddy:actor_skin_skinnable_set_skin(actor.value)
			Alarm.add(1, function()
				if Instance.exists(data.buddy) and Net.host then
					data.buddy:teleport_nearby(data.buddy, actor.x, actor.y)
					--data.buddy.moveUp = 1
					data.buddy:actor_activity_set(data.buddy.value, 90)
				end
			end)
        end

		data.bash = true
		data.x_skill = 0
    end)

    Callback.add(bashnbounce.on_step, function(actor)
		local data = Instance.get_data(actor)

		if not data.bash then
			bounce_handle_step(actor, data)
		end
	end)

	oBuddy:set_sprite(gm.constants.sLoaderIdle)
    Callback.add(oBuddy.on_create, function(actor)
        local data = Instance.get_data(actor)
        --actor:init_actor_default()--is called already by custom object NPC event 15
		actor.persistent = true
        actor:init_ai_default()
		actor.is_local = actor.local_client_is_authority
		actor.sprite_idle_half		= Array.new({gm.constants.sHuntressIdle, gm.constants.sHuntressIdleHalf, 0})
		actor.sprite_walk_half		= Array.new({sprites.walk, gm.constants.sHuntressWalkHalf, 0, gm.constants.sHuntressWalkBack})
		actor.sprite_jump_half		= Array.new({sprites.jump, gm.constants.sHuntressJumpHalf, 0})
		actor.sprite_jump_peak_half	= Array.new({sprites.jump_peak, gm.constants.sHuntressJumpPeakHalf, 0})
		actor.sprite_fall_half		= Array.new({sprites.fall, gm.constants.sHuntressFallHalf, 0})
		actor:survivor_util_init_half_sprites()
		actor.sprite_spawn			= gm.constants.sLoaderIdle
        actor.sprite_idle			= gm.constants.sLoaderIdle
        actor.sprite_walk			= sprites.walk
        actor.sprite_jump			= sprites.jump
        actor.sprite_jump_peak		= sprites.jump_peak
        actor.sprite_fall			= sprites.fall
        actor.sprite_climb			= sprites.climb
        actor.sprite_death			= sprites.death
        actor.sprite_decoy			= sprites.decoy
        actor.sprite_climb_hurt		= sprites.climb_hurt
	    actor.sprite_palette		= sBashNBouncePalette
		actor.mask_index			= gm.constants.sPMask
		actor.image_speed = 0.2
        actor.can_jump = true
		actor.can_rope = false
		actor.sound_death = gm.constants.wLizardDeath
		actor.pHmax_base = 2.8
        actor.parent = -4
		actor.z_range = 80
		actor:set_default_skill(Skill.Slot.PRIMARY, Skill.find("bashnbounceZB"))
		actor.x_range = 540
		actor:set_default_skill(Skill.Slot.SECONDARY, Skill.find("bashnbounceXB"))
		actor:set_default_skill(Skill.Slot.UTILITY, Skill.find("bnbBuddyRecall"))
		actor.damage_base = 12
		actor.maxhp_base = 110
		actor.knockback_cap_base = 42
		actor.armor_base = 20
		actor.hp_regen_base = actor.maxhp_base * 0.0002
		actor.team = 1
		actor.tether_range_min = 120
		actor.tether_range_max = 960
		actor.invincible = 5
		actor:player_survivor_stats_level(3, 32, 0.002, 2)
		actor.is_character_enemy_targettable = true
		actor.destroy_on_death = false
		actor.despawn_time = math.huge
		--actor.ridable_collider = -4
		data.scepter = false
		data.bash = false
		data.name = {}
		data.name[true] = "Bash"
		data.name[false] = "Bounce"
		data.spawn_frame = Global._current_frame
		data.revivetimer = 300
		data.revivesprite = actor.sprite_idle
		data.alarm0 = 15
		data.x_skill = math.random(1, 180)
		actor:init_actor_late(true)
		actor:instance_sync()
    end)

	Callback.add(oBuddy.on_step, function(actor)
		if not Instance.exists(actor.parent) then actor:destroy() return end
		local data = Instance.get_data(actor)
		local state = actor.actor_state_current_id

		if not actor.dead then
			if not data.bash then
				bounce_handle_step(actor, data)
				if state == ActorState.find("bashnbounceXB").value then
					if data.x_skill > 0 then
						actor.x_skill = 1
						data.x_skill = data.x_skill - 1
					end
				end
			end

			if math.floor(data.alarm0) == 0 then
				Util.print(actor:point_distance(actor.x, actor.y, actor.parent.x, actor.parent.y))
				if Instance.exists(actor.parent)
				and (actor:point_distance(actor.x, actor.y, actor.parent.x, actor.parent.y) > actor.tether_range_max or math.abs(actor.parent.y - actor.y) > 540)
				and not actor:actor_state_is_climb_state(actor.parent.actor_state_current_id)
				and not actor:actor_state_is_climb_state(actor.actor_state_current_id)
				and not actor.parent.free
				and actor.parent.activity == 0
				and actor:skill_can_activate(Skill.Slot.UTILITY)
				and state == -1 then
					actor.c_skill = 1
					Alarm.add(1, function()
						if Instance.exists(actor) then
							actor.c_skill = 0
						end
					end)
				else
					actor:alarm_ai_default()
					actor.c_skill = 0
				end
				actor.despawn_time = math.huge
				local alarm = 15 + math.random(0, 10)
				if actor.ai_tick_rate then
					alarm = alarm * actor.ai_tick_rate
				end
				data.alarm0 = math.floor(alarm)
				alarm_ai_inherit_items(actor.parent, actor, Item.LootTag.ITEM_BLACKLIST_ENGI_TURRETS)
			end
			if actor.x > gm._mod_room_get_current_width() + 2 or actor.x < -2 or actor.y < -2 or actor.y > gm._mod_room_get_current_height() then
				actor:teleport_nearby(actor.value, actor.parent.x, actor.parent.y)
			end
			actor:update_nav_ai_default()
			actor:skill_system_update()
			--actor:step_actor()--is called already by custom object NPC step event
			actor:step_default()
			actor:step_ai_default()
			if data.alarm0 > -1 then
				data.alarm0 = data.alarm0 - 1
			end
		elseif data.revivetimer == 300 then
			data.revivetimer = data.revivetimer - 1
			--actor.is_character_enemy_targettable = false
			actor.intangible = true
			data.revivesprite = actor.sprite_index
			actor.sprite_index = actor.sprite_death
			actor.image_index = 0
			actor.image_speed = 0
			actor:sound_play(actor.sound_death, 1, 1)
		else
			actor:__step_actor_dead()
			if actor.is_update_enabled then
				actor:actor_phy_move()
			end
			actor.sprite_index = actor.sprite_death
			actor.image_index = 0
			data.revivetimer = data.revivetimer - 1
			if data.revivetimer <= 0 then
				data.revivetimer = 300
				actor:actor_no_targetting_remove(actor)
				actor:actor_set_dead(actor, false)
				actor.hp = actor.maxhp
				actor.invincible = 5
				--actor.is_character_enemy_targettable = true
				actor.intangible = false
				actor.sprite_index = data.revivesprite
				actor:skill_util_reset_activity_state()
			end
		end
		
		if actor:is_colliding(gm.constants.pGeyser) then
			if Global.time_stop == 0 and actor.activity ~= 90 and not actor.dead then
				for _, geyser in ipairs(actor:get_collisions(gm.constants.pGeyser)) do
					if Global._current_frame > geyser.sound_cd_frame then
						actor:sound_play_networked(gm.constants.wGeyser, 1, 1, geyser.x, geyser.y)
						geyser.sound_cd_frame = Global._current_frame + 20

						actor.jumping = true
						actor.force_jump_held = true
						actor.pVspeed = -geyser.jump_force
						actor.jump_count = 0
					end

					if Net.online then
						actor:net_send_instance_message(67, actor.value)
						actor.net_last_position_update = Global._current_frame
					end
				end
			end
		end
	end)

	Hook.add_post("gml_Object_oCustomObject_pNPC_Draw_0", function(self, other, result, args)
		if self:get_object() == oBuddy then
			self:custom_object_event_perform(8)
		end
	end)
	
	Callback.add(oBuddy.on_draw, function(actor)
		local parent = actor.parent
		if parent ~= Player.get_local() then return end
		local player_color = parent:player_get_color(parent)

		if Util.bool(actor.visible) and not Util.bool(actor:inside_view(actor.ghost_x, actor.ghost_y)) then
			local sprite_height = actor:sprite_get_height(actor.sprite_idle)
			local size = math.max((sprite_height / 2) + 2, 16)
			local draw_x = math.max(Global.___view_l_x + 16, math.min(Global.___view_l_x2 - 17, actor.ghost_x))
			local draw_y = math.max(Global.___view_l_y + 16, math.min(Global.___view_l_y2 - 17, actor.ghost_y))
			actor:draw_circle_color(draw_x, (draw_y - actor:sprite_get_yoffset(actor.sprite_idle)) + (sprite_height / 2), size, player_color, player_color, true)
			actor:actor_drawscript_call(actor, draw_x, draw_y, 10, -100)
		end
	end)

	Callback.add(oBuddy.on_destroy, function(actor)
		local data = Instance.get_data(actor)
		log.warning("Hey, it's me, "..data.name[data.bash].."!")
		log.warning("The game destroyed me for some reason!!!!")
		log.warning("(Ignore if not in a run)")
	end)

	oBashMissle:set_sprite(sBashMissile)
	oBashMissle:set_depth(-10)
	Callback.add(oBashMissle.on_create, function(knuckle)
		local data = Instance.get_data(knuckle)
		knuckle.parent = -4
		knuckle.team = 1
		--image speed
		data.lifetime = 0
		knuckle.speed = 12
		knuckle.climb = 0
		knuckle.damage_coefficient = 1
		knuckle.local_client_is_authority = true
	end)

	Callback.add(oBashMissle.on_step, function(knuckle)
		local data = Instance.get_data(knuckle)
		if not Instance.exists(knuckle.parent) or data.lifetime > 120 then knuckle:destroy() return end
		
        local actor_collisions = knuckle:get_collisions(gm.constants.pActorCollisionBase)
		for _, target in ipairs(actor_collisions) do
			if knuckle.parent:attack_collision_canhit(target) then
				if knuckle.local_client_is_authority then
					local attack = knuckle.parent:fire_direct(target, knuckle.damage_coefficient, knuckle.direction, knuckle.x, knuckle.y, gm.constants.sSparks13)
					attack.attack_info.climb = knuckle.climb
				end
				knuckle:destroy()
				return
			end
		end
		if knuckle:is_colliding(gm.constants.pEnvironmentShootable) then
			knuckle.parent:fire_explosion(knuckle.x, knuckle.y, 32, 32, 0, nil, nil, false)
		end
		if knuckle:is_colliding(gm.constants.pSolidBulletCollision) then
			knuckle:destroy()
			return
		end
		data.lifetime = data.lifetime + 1
	end)

	oReticle:set_sprite(gm.constants.sEfSniperCrosshair)
	Callback.add(oReticle.on_create, function(reticle)
		reticle.parent = -4
		reticle.target = -4
		reticle.team = 1
		reticle.image_speed = 0.3
	end)

	Callback.add(oReticle.on_step, function(reticle)
		if reticle.image_index >= reticle.image_number - 1 and reticle.image_speed > 0 then
			reticle.image_speed = 0
			reticle.image_index = reticle.image_number - 1
		end
		local target = reticle.target
		if Instance.exists(target) then
			reticle.x = target.x
			reticle.y = target.y
		end
	end)

    local bashnbounceZ	= bashnbounce:get_skills(0)[1]
    local bashnbounceX	= bashnbounce:get_skills(1)[1]
    local bashnbounceC	= bashnbounce:get_skills(2)[1]
    local bashnbounceV	= bashnbounce:get_skills(3)[1]

	local bashnbounceZB	= Skill.new("bashnbounceZB")
	local bashnbounceXB	= Skill.new("bashnbounceXB")

	local bnbBuddyRecall = Skill.new("bnbBuddyRecall")

    -- Configure icons for each skill
    bashnbounceZ.sprite = sBashNBounceSkills
    bashnbounceZ.subimage = 0
	bashnbounceZ.animation = gm.constants.sHuntressShoot1
    bashnbounceX.sprite = gm.constants.sDrifterSkills
    bashnbounceX.subimage = 9
	bashnbounceX.animation = gm.constants.sDrifterShoot3B
    bashnbounceC.sprite = gm.constants.sRobomandoSkills
    bashnbounceC.subimage = 3
    bashnbounceV.sprite = gm.constants.sDrifterSkills
    bashnbounceV.subimage = 11
	
    bashnbounceZB.sprite = gm.constants.sLoaderSkills
    bashnbounceZB.subimage = 8
	bashnbounceZB.animation = gm.constants.sLoaderShoot2B
    bashnbounceXB.sprite = gm.constants.sSniperSkills
    bashnbounceXB.subimage = 8
	bashnbounceXB.animation = gm.constants.sLoaderShoot2B

	bnbBuddyRecall.sprite = gm.constants.sHuntressSkills
	bnbBuddyRecall.subimage = 7
	bnbBuddyRecall.animation = gm.constants.sImpShoot2

    -- Configure damage and cooldown for each skill
    bashnbounceZ.damage = 1.8
    bashnbounceZ.cooldown = 0
    bashnbounceX.damage = 1
    bashnbounceX.cooldown = 360
    bashnbounceC.damage = 2
    bashnbounceC.cooldown = 240
    bashnbounceC.is_utility = true
    bashnbounceV.damage = 1
    bashnbounceV.cooldown = 30
    bashnbounceV.is_utility = true

    bashnbounceZB.damage = 2
    bashnbounceZB.cooldown = 0
	bashnbounceZB.is_primary = true
    bashnbounceXB.damage = 5
    bashnbounceXB.cooldown = 360

	bnbBuddyRecall.cooldown = 60
	bnbBuddyRecall.is_utility = true

    local statebashnbounceZ		= ActorState.new("bashnbounceZ")
    local statebashnbounceX		= ActorState.new("bashnbounceX")
    local statebashnbounceC		= ActorState.new("bashnbounceC")
    local statebashnbounceV		= ActorState.new("bashnbounceV")

    local statebashnbounceZB	= ActorState.new("bashnbounceZB")
    local statebashnbounceXB	= ActorState.new("bashnbounceXB")
	
    local statebnbBuddyRecall	= ActorState.new("bnbBuddyRecall")

    Callback.add(bashnbounceZ.on_activate, function(actor, skill, slot)
        actor:set_state(statebashnbounceZ)
    end)
    Callback.add(bashnbounceX.on_activate, function(actor, skill, slot)
        actor:set_state(statebashnbounceX)
    end)
    Callback.add(bashnbounceC.on_activate, function(actor, skill, slot)
        --actor:set_state(statebashnbounceC)
    end)
    Callback.add(bashnbounceV.on_activate, function(actor, skill, slot)
        --actor:set_state(statebashnbounceV)
		local data = Instance.get_data(actor)
		if Instance.exists(data.buddy) then
			local buddy = data.buddy
			local bData = Instance.get_data(buddy)

			local x, y = actor.x, actor.y
			actor.x = buddy.x
			actor.y = buddy.y
			buddy.x = x
			buddy.y = y
			data.bash = not data.bash
			bData.bash = not bData.bash

			if data.bash then
				actor:remove_skill_override(Skill.Slot.PRIMARY, bashnbounceZB, 0)
				actor:remove_skill_override(Skill.Slot.SECONDARY, bashnbounceXB, 0)
				actor.can_rope = true
				actor.sprite_idle = sprites.idle
			else
				actor:add_skill_override(Skill.Slot.PRIMARY, bashnbounceZB, 0)
				actor:add_skill_override(Skill.Slot.SECONDARY, bashnbounceXB, 0)
				actor.can_rope = false
				actor.sprite_idle = gm.constants.sLoaderIdle
			end
			if bData.bash then
				buddy:set_default_skill(Skill.Slot.PRIMARY, bashnbounceZ)
				buddy:set_default_skill(Skill.Slot.SECONDARY, bashnbounceX)
				buddy.can_rope = true
				buddy.sprite_idle = sprites.idle
			else
				buddy:set_default_skill(Skill.Slot.PRIMARY, bashnbounceZB)
				buddy:set_default_skill(Skill.Slot.SECONDARY, bashnbounceXB)
				buddy.can_rope = false
				buddy.sprite_idle = gm.constants.sLoaderIdle
			end
		else
			local buddy = oBuddy:create(actor.x, actor.y)
			local bData = Instance.get_data(buddy)
            data.buddy = buddy
            buddy.parent = actor
            buddy.m_id = actor.m_id
            actor:actor_team_set(buddy, actor.team)
            --data.buddy:actor_skin_skinnable_set_skin(actor.value)
			buddy:teleport_nearby(buddy, actor.x, actor.y)
			buddy:actor_activity_set(buddy.value, 90)
			bData.bash = not data.bash
			if bData.bash then
				data.buddy:set_default_skill(Skill.Slot.PRIMARY, bashnbounceZ)
				data.buddy:set_default_skill(Skill.Slot.SECONDARY, bashnbounceX)
			end
		end
    end)
    --Callback.add(bashnbounceV.on_can_activate, function(actor, skill, slot)
    --	return actor.visible
    --end)

    Callback.add(bashnbounceZB.on_activate, function(actor, skill, slot)
		if actor.free then
        	actor:set_state(statebashnbounceZB)
		end
    end)
    Callback.add(bashnbounceXB.on_activate, function(actor, skill, slot)
        actor:set_state(statebashnbounceXB)
    end)

	Callback.add(bnbBuddyRecall.on_activate, function(actor, skill, slot)
		actor.activity = 2
		actor.activity_type = 1
		actor:set_state(statebnbBuddyRecall)
	end)

	Callback.add(bnbBuddyRecall.on_can_activate, function(actor, skill, slot)
		return true
	end)

	Callback.add(statebashnbounceZ.on_enter, function(actor, tData)
		local data = Instance.get_data(actor)

		actor:skill_util_strafe_init()
		actor:skill_util_strafe_turn_init()
		actor.walk_speed_coeff = 1
		actor:_survivor_huntress_aim()
		actor.sprite_index2 = actor:actor_get_skill_animation(bashnbounceZ.value)
	end)

	Callback.add(statebashnbounceZ.on_step, function(actor, tData)
		local data = Instance.get_data(actor)

		actor:skill_util_step_strafe_sprites()
		if actor:is_local_player(actor) then
			if not actor:player_util_get_input_profile().huntress_auto_aim then
				actor:skill_util_strafe_turn_update()
				if actor.image_index2 < 4 or actor.image_index2 >= 6 then
					actor:skill_util_strafe_turn_turn_if_direction_changed(false)
				end
			end
		end
		actor.image_index2 = actor.image_index2 + math.min((0.29 / 1.5) * actor.attack_speed, 1)
		if actor.activity_var1 == 0 and math.floor(actor.image_index2) >= 4 then
			actor.activity_var1 = 1
			local attack_damage = bashnbounceZ.damage
			if not actor:skill_util_update_heaven_cracker(actor, attack_damage, image_xscale2) then
				local buff_shadow_clone = Buff.find("shadowClone", "ror")
				for i=0, actor:buff_count(buff_shadow_clone) do
					local authority = actor:is_authority()
					local knuckle = oBashMissle:create(actor.x + (28 * actor.image_xscale2), actor.y - (20 * i) - 4)
					knuckle.damage_coefficient = attack_damage
					knuckle.direction = 90 - (90 * actor.image_xscale2)
					knuckle.image_xscale = actor.image_xscale2
					knuckle.parent = actor
					knuckle.team = actor.team
					knuckle.local_client_is_authority = authority
				end
			end
			actor:sound_play(gm.constants.wHuntressShoot1, 1, (0.85 + (0.15 * math.random())) / 1.5)
		elseif actor.activity_var1 == 1 and actor.image_index >= 5 then
			actor.activity_var1 = 2
			actor.activity_flags = actor.activity_flags | 1
		end
		actor:skill_util_exit_state_on_anim_end()
	end)

	Callback.add(statebashnbounceZ.on_get_interrupt_priority, function(actor)
		if actor.image_index2 >= 5 then return ActorState.InterruptPriority.SKILL_INTERRUPT_PERIOD end
		return ActorState.InterruptPriority.SKILL
	end)

	Callback.add(statebashnbounceX.on_enter, function(actor, tData)
		local data = Instance.get_data(actor)

		actor.image_index = 0
		data.fired = 0
		data.loop = math.min(math.ceil(3 * actor.attack_speed), 12)
		actor.activity_type = 6
		actor:actor_script_attach(actor.value, 1, "drifter_spin", Script.bind(function()
			actor.pHmax = actor.pHmax * 1.5
			actor.pGravity2 = actor.pGravity2 * 0.5
			actor.pGravity1 = actor.pGravity2
		end))
	end)

	Callback.add(statebashnbounceX.on_step, function(actor, tData)
		local data = Instance.get_data(actor)
		actor:actor_animation_set(bashnbounceX.animation, 0.25, false)
		--Util.print(actor.pHmax_base, actor.pHmax)
		--Util.print(actor.pGravity2_base, actor.pGravity2)
		

		if actor.pVspeed > 1 then
			actor.pVspeed = 1
		end

		if data.fired ~= math.floor(actor.image_index) and (math.floor(actor.image_index) == 3 or math.floor(actor.image_index) == 5) then
			actor:sound_play(gm.constants.wMinerShoot4, 1, 3 + (0.2 * math.random()))
			if not free then
				local dust = Object.wrap(gm.constants.oMinerDust):create(actor.x, actor.y - 2)
				dust.image_xscale = (math.random(0, 1) * 2) - 1
			end
			data.fired = math.floor(actor.image_index)

			if actor:is_authority() then
				local buff_shadow_clone = Buff.find("shadowClone", "ror")
				for i=0, actor:buff_count(buff_shadow_clone) do
					local size = 16
					local attack = actor:fire_explosion(actor.x, actor.y, 117, 32, bashnbounceX.damage, -1, gm.constants.sSparks14)
					attack.attack_info.climb = i * 8 * 1.35
				end
			end
		end

		if math.floor(actor.image_index) == 7 then
			if data.loop > 0 then
				data.loop = data.loop - 1
				actor.image_index = 3
			else
				actor.image_index = 8
				actor.activity_type = 1
			end
		end

		actor:skill_util_exit_state_on_anim_end()
	end)

	Callback.add(statebashnbounceX.on_exit, function(actor, tData)
		actor:actor_script_remove(actor.value, 1, "drifter_spin")
	end)

	Callback.add(statebashnbounceZB.on_enter, function(actor, tData)
		local data = Instance.get_data(actor)

		actor.image_index = 0
		data.fired = 0
		data.speed_coeff = 0
	end)

	Callback.add(statebashnbounceZB.on_step, function(actor, tData)
		local data = Instance.get_data(actor)
		actor:actor_animation_set(bashnbounceZB.animation, 0.22, false)
		
		if actor.free then
			actor.moveUp = 0
			actor.moveUpHold = 0
			actor.moveUp_buffered = 0
			if actor.image_index >= 3 then
				actor.image_index = 3
				actor.image_speed = 0
				actor.pVspeed = math.max(math.min(25, actor.pVspeed * 1.2), 0)
				data.speed_coeff = actor.pVspeed
			end
		else
			if data.fired == 0 then
				data.fired = 1
				actor.image_index = 4
				actor:sound_play(gm.constants.wHANDShoot4_2, 1, 1)

				if actor:is_authority() then
					for i = 0, actor:buff_count(Buff.find("shadowClone", "ror")) do
						local attack = actor:fire_explosion(actor.x, actor.y, 156, 80, bashnbounceZB.damage + ((((data.speed_coeff / 2) ^ 2) * 2.37) / 100), -1, gm.constants.sSparks1)
						attack.attack_info.climb = i * 8 * 1.35
					end
				end
			end
			actor.pHspeed = 0
			if actor.moveUp > 0 and data.fired > 0 then
				actor:skill_util_reset_activity_state()
			end
		end

		actor:skill_util_exit_state_on_anim_end()
	end)

	Callback.add(statebashnbounceXB.on_enter, function(actor, tData)
		local data = Instance.get_data(actor)

		actor.image_index = 0
		data.fired = 0
		data.released = 0
		data.charge = 0
		local x = actor.x + (540 * actor.image_xscale)
		local y = actor.y - 11
		local target = _survivor_bounce_find_target(actor, 540, 46)
		if Instance.exists(target) then
			x = target.x
			y = target.y
		else
			local w = actor:collision_line_advanced(actor.x, y, x, y, gm.constants.pSolidBulletCollision, false, true)
			if Instance.exists(w) then
				--if actor.image_xscale > 0 then
				--	x = w.bbox_left
				--else
				--	x = w.bbox_right
				--end
				x = Global.collision_x
			end
		end
		local reticle = oReticle:create(x, y)
		reticle.target = target
		data.target = target
		data.reticle = reticle
		data.homing = true
		data.test = 0
	end)

	Callback.add(statebashnbounceXB.on_step, function(actor, tData)
		local data = Instance.get_data(actor)
		--Util.print(data.test, actor.image_index)
		--data.test = data.test + 1
		if actor.image_index <= 3 then actor:skill_util_fix_hspeed() end
		actor:actor_animation_set(bashnbounceXB.animation, 0.22, false)
		local solid_check_still_l	= actor:is_colliding(gm.constants.pSolidBulletCollision, actor.x - 7) and actor.pHspeed == 0
		local solid_check_still_r	= actor:is_colliding(gm.constants.pSolidBulletCollision, actor.x + 7) and actor.pHspeed == 0
		local solid_check_still_u	= actor:is_colliding(gm.constants.pSolidBulletCollision, nil, actor.y - 11) and actor.pVspeed == 0
		local solid_check_still_d	= actor:is_colliding(gm.constants.pSolidBulletCollision, nil, actor.y + 12) and actor.pVspeed == 0
		local solid_check_moving	= actor:is_colliding(gm.constants.pSolidBulletCollision, actor.x + 7 * Math.sign(actor.pHspeed), actor.y + 1 + 12 * Math.sign(actor.pVspeed))
		local free					= actor.free
		local has_landed			= solid_check_still_l or solid_check_still_r or solid_check_still_u or solid_check_still_d or solid_check_moving or not free
		--Util.print(solid_check_still_l)
		--Util.print(solid_check_still_r)
		--Util.print(solid_check_still_u)
		--Util.print(solid_check_still_d)
		--Util.print(has_landed)

		local release = false
        if Util.bool(actor.is_local) then
			if actor:get_object_index() == gm.constants.oP then
				release = not actor:control("skill2", 0)
			else
				release = not Util.bool(actor.x_skill)
			end
        elseif not actor:is_authority() then
            release = Util.bool(actor.activity_var2)
        end
		--Util.print(actor.is_local)

		if not release and data.released == 0 then
			if actor.image_index >= 0 then
				actor.image_index = 0
			end
			data.charge = math.min(data.charge + actor.attack_speed, 180)
		else
			if data.released == 0 and actor:is_authority() then
				if Net.host then
                    GM.server_message_send(0, 43, actor:get_object_index_self(), actor.m_id, 1, Math.sign(actor.image_xscale))
                else
                    GM.client_message_send(43, 1, Math.sign(actor.image_xscale))
                end
			end
			if actor.image_index < 3 then
				if not actor.free then
					actor.pVspeed = -actor.pVmax
					actor.free = true
				end
				actor.pVspeed = math.min(actor.pVspeed, 0)
			elseif not actor:is_colliding(data.reticle.target) and not has_landed and data.fired == 0 then
				actor.image_index = 3
				actor.image_speed = 0
				local direction = actor:point_direction(actor.x, actor.y, data.reticle.x, data.reticle.y)
				if data.homing then
					actor_phy_set_pSpeed_vector(actor, 18, direction)
					if actor:is_colliding(data.reticle) then
						data.homing = false
					end
				end
			else
				--Util.print("=")
				--Util.print(solid_check_still_l, data.fired)
				--Util.print(solid_check_still_r, data.fired)
				--Util.print(solid_check_still_u, data.fired)
				--Util.print(solid_check_still_d, data.fired)
				--Util.print(solid_check_moving, data.fired)
				--Util.print(has_landed, data.fired)
				if data.fired == 0 then
					data.fired = 1
					actor.image_index = 4
					actor:sound_play(gm.constants.wHANDShoot4_2, 1, 1)
					
					if actor:is_authority() then
						for i = 0, actor:buff_count(Buff.find("shadowClone", "ror")) do
							local attack = actor:fire_explosion(actor.x, actor.y, 156 + (data.charge / 3), 80 + (data.charge / 9), bashnbounceXB.damage + (data.charge / 60), -1, gm.constants.sSparks1)
							attack.attack_info.climb = i * 8 * 1.35
						end
					end
				end
				actor.pHspeed = 0
			end
			data.released = 1
		end

		actor:skill_util_exit_state_on_anim_end()
	end)

	Callback.add(statebashnbounceXB.on_exit, function(actor, tData)
		local data = Instance.get_data(actor)
		if Instance.exists(data.reticle) then data.reticle:destroy() end
		data.x_skill = math.random(1, 180)
	end)

	Callback.add(statebnbBuddyRecall.on_enter, function(actor, tData)
		actor.target = -4
		actor.interrupt_sound = actor:sound_play(gm.constants.wImpShoot2, 1, 1)
		actor.image_index = 0
		Instance.get_data(actor).fired = 0
	end)

	Callback.add(statebnbBuddyRecall.on_step, function(actor, tData)
		local data = Instance.get_data(actor)
		actor:skill_util_fix_hspeed()
		actor:actor_animation_set(bnbBuddyRecall.animation, 0.23, false)

		if data.fired == 0 and actor.image_index >= 2 then
			data.fired = 1
			if Instance.exists(actor.parent) and actor:is_authority() then
				actor:teleport_nearby(actor, actor.parent.x, actor.parent.y, gm.constants.pBlockFloor)
				actor.xprevious = actor.x
				actor.yprevious = actor.y
				actor.ghost_x = actor.x
				actor.ghost_y = actor.y
				actor.pHspeed = 0
				actor.pVspeed = 0
				actor:net_send_instance_message(47)
			end
		end

		actor:skill_util_exit_state_on_anim_end()
	end)

    Callback.add(Callback.ON_STAGE_START, function()
		if Net.host then
			for _, buddy in ipairs(Instance.find_all(Object.find("BashNBounceBuddy"))) do
				Alarm.add(1, function()
					if Instance.exists(buddy) then
						--Util.print("tp2")
						buddy:teleport_nearby(buddy, buddy.parent.x, buddy.parent.y)
					end
				end)
			end
		end
	end)

end

Initialize.add(initialize)

-- ** Uncomment the two lines below to re-call initialize() on hotload **
if hotload then initialize() end
