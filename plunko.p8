pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

consts = {
	top_of_buckets = 104,
	num_buckets = 10,
	num_peg_rows = 9,
}


game_mode = {
	drop = 1,
	upgrade = 2,
}

state = {
	debug_text = "",
	timers = {},
	money = 10,
	buckets = {},
	special_coins = {
		red = 0,
	},
	fallings_coins = {},
	coin_cost = 1,
	earnings_text = "",
	disable_button_drop = false,
	mode = game_mode.drop,
}

function _init()
	state.buckets = {}
	drop_button = new_drop_button()
	start_x = 64 - (8 * (consts.num_buckets / 2 + 1)) + 1
	bucket_value = flr(consts.num_buckets / 2)
	for i = 1, consts.num_buckets do
		add(state.buckets, new_bucket(bucket_value, start_x + i * 8))
		if i < consts.num_buckets / 2 then
			bucket_value -= 1
		elseif i > consts.num_buckets / 2 then
			bucket_value += 1
		end
	end
	upgrades = new_upgrades()
end

function _update()
	update_timers()
	for coin in all(state.fallings_coins) do
		coin.update()
	end

	if state.mode == game_mode.drop then
		update_board()
		drop_button:update()
	elseif state.mode == game_mode.upgrade then
		upgrades:update()
	end
end

function _draw()
	cls(1)

	if state.mode == game_mode.drop then
		draw_board()
		drop_button:draw()
		for coin in all(state.fallings_coins) do
			coin.draw()
		end
		draw_pegs()
		for b in all(state.buckets) do
			b.draw()
		end
		print(state.earnings_text, 126 - #state.earnings_text * 4, 9, 11)
	elseif state.mode == game_mode.upgrade then
		upgrades:draw()
		-- cprint("coins: " .. state.money, 120, 7)
		-- cprint("red coins: " .. state.special_coins.red, 120, 7)
	end
	print(state.debug_text, 0, 0, 7)

end

function draw_board()
	local coins_str = "" .. state.money
	print(coins_str, 126 - #coins_str * 4, 2, 7)
end

function update_board()
	local can_drop_coin = not is_button_drop_disabled()
	if btnp(🅾️) then
		state.mode = game_mode.upgrade
	elseif btnp(❎) and can_drop_coin then
		if state.special_coins.red > 0 then
			state.special_coins.red -= 1
			add(state.fallings_coins, new_coin(coin_types.red))  -- red coin
		else
			add(state.fallings_coins, new_coin(coin_types.gold))  -- gold coin
		end
		state.money -= state.coin_cost
	end
end

function is_button_drop_disabled()
	return state.disable_button_drop or state.money < state.coin_cost
end

function new_drop_button()
	return {
		update = function(self)
			if self.waiting_to_reset then
				-- do nothing
				return
			end

			local disabled = is_button_drop_disabled()
			if btnp(❎) and not disabled then
				state.disable_button_drop = true
				sfx(2)
				wait_then_do(1000, function()
					state.disable_button_drop = false
				end)
			end
		end,

		draw = function(self)
			local start_x = 44
			local start_y = 20

			local disabled = is_button_drop_disabled()
			local color = (not disabled and 12 or 13)

			-- rectfill(start_x, start_y, start_x + 40, start_y + 10, color)
			-- -- draw sides to make it look rounded on corners
			-- line(start_x - 1, start_y + 1, start_x - 1, start_y + 9, color)
			-- line(start_x + 41, start_y + 1, start_x + 41, start_y + 9, color)
			rounded_button_filled(start_x, start_y, start_x + 40, start_y + 10, "press ❎", color)

			-- print("press ❎", start_x + 5, start_y + 3, 7)
		end,
	}	
end

-->8
-- utils
-- center print text
-- Helper function to split strings
function split(str, delimiter)
    local result = {}
    local current = ""
    for i = 1, #str do
        local char = sub(str, i, i)
        if char == delimiter then
            if #current > 0 then
                add(result, current)
                current = ""
            end
        else
            current = current .. char
        end
    end
    if #current > 0 then
        add(result, current)
    end
    return result
end

function cprint(text, y, color)
	color = color or 7
	print(text, 64 - #text * 2, y, color)
end

function rounded_button_filled(top_x, top_y, bottom_x, bottom_y, text, color)
	local width = bottom_x - top_x
	local height = bottom_y - top_y
	rectfill(top_x, top_y, bottom_x, bottom_y, color)
	line(top_x - 1, top_y + 1, top_x - 1, bottom_y - 1, color)
	line(bottom_x + 1, top_y + 1, bottom_x + 1, bottom_y - 1, color)
	print(text, top_x + (width / 2) - (#text * 2), top_y + (height / 2) - 2, 7)
end

function rounded_button(top_x, top_y, bottom_x, bottom_y, text, color)
	local width = bottom_x - top_x
	local height = bottom_y - top_y
	-- rect(top_x, top_y, bottom_x, bottom_y, color)
	line(top_x, top_y, bottom_x, top_y, color)
	line(top_x, bottom_y, bottom_x, bottom_y, color)
	line(top_x - 1, top_y + 1, top_x - 1, bottom_y - 1, color)
	line(bottom_x + 1, top_y + 1, bottom_x + 1, bottom_y - 1, color)
	print(text, top_x + (width / 2) - (#text * 2), top_y + (height / 2) - 2, color)
end


function new_point(x, y)
	return {
		x = x or 0,
		y = y or 0,
		
		-- add another point to this one
		add = function(self, other)
			self.x += other.x
			self.y += other.y
			return self
		end,

		add_vector = function(self, vector)
			self.x += vector.x
			self.y += vector.y
			return self
		end,
		
		-- set new values
		set = function(self, x, y)
			self.x = x
			self.y = y
			return self
		end,
		
		-- create a copy
		copy = function(self)
			return new_point(self.x, self.y)
		end
	}
end

function new_vector(x, y)
  return {
    x = x or 0,
    y = y or 0,
    
    -- add another vector to this one
    add = function(self, other)
      self.x += other.x
      self.y += other.y
      return self
    end,
    
    -- multiply by a scalar
    mult = function(self, scalar)
      self.x *= scalar
      self.y *= scalar
      return self
    end,
    
    -- get the length/magnitude
    mag = function(self)
      return sqrt(self.x * self.x + self.y * self.y)
    end,
    
    -- normalize to unit vector
    normalize = function(self)
      local m = self:mag()
      if m > 0 then
        self.x /= m
        self.y /= m
      end
      return self
    end,
    
    -- create a copy
    copy = function(self)
      return new_vector(self.x, self.y)
    end,
    
    -- set new values
    set = function(self, x, y)
      self.x = x
      self.y = y
      return self
    end,

	 -- set with polar coordinates
	 set_polar = function(self, angle, length)
		 self.x = cos(angle) * length
		 self.y = sin(angle) * length
		 return self
	 end,

	 angle = function(self)
		 return atan2(self.y, self.x)
	 end,
  }
end

function draw_pegs(x, y)
	for row=1,consts.num_peg_rows do
		local num_pegs = row
		local y = 32 + (row-1)*8
		local total_width = (num_pegs-1)*8
		local start_x = 64 - total_width/2
		for i=0,num_pegs-1 do
			local x = start_x + (i-1)*8 + 3
			spr(17, x, y)
		end
	end
end

function wait_then_do(milliseconds, callback)
	add(state.timers, {
		start_time = t(),
		delay = milliseconds / 1000,
		callback = callback,
	})
end

function update_timers()
	for timer in all(state.timers) do
		if t() - timer.start_time >= timer.delay then
			timer.callback()
			del(state.timers, timer)  -- remove the timer after it has executed
		end
	end
end
-->8
-- coin

coin_state = {
	initial_drop = 1,
	dropping = 2,
}

coin_types = {
	gold = 1,
	red = 2,
}

function new_coin(level)
	local coin = {}

	coin.pos = new_point(62, 25)
	coin.state = coin_state.initial_drop
	coin.speed = 0.7
	coin.level = level or 1
	coin.value_multiplier = 1
	coin.target_x = 0
	coin.target_y = 0

	coin.pick_target = function()
		if coin.pos.y > consts.top_of_buckets - 6 then
			coin.target_x = coin.pos.x
			coin.target_y = consts.top_of_buckets
			return
		end

		local dir = rnd()  -- 1 or 2
		if dir > 0.5 then
			coin.target_x = coin.pos.x - 4
		else
			coin.target_x = coin.pos.x + 4
		end
		coin.target_y = coin.pos.y + 8
		sfx(0)
	end

	coin.update_initial_drop = function()
		coin.pos.y += coin.speed
		coin.pos.y = min(coin.pos.y, 29)  -- prevent going above 32
		if coin.pos.y == 29 then
			coin.state = coin_state.dropping
			coin.pick_target()
		end
	end

	coin.update_dropping = function()
		if coin.pos.y == consts.top_of_buckets then
			coin.enter_bucket()
			-- coin.pos = new_point(-200, -200)  -- reset position
			return
		end

		if coin.pos.x < coin.target_x then
			coin.pos.x += coin.speed * 2
			coin.pos.x = min(coin.pos.x, coin.target_x)
		else
			coin.pos.x -= coin.speed * 2
			coin.pos.x = max(coin.pos.x, coin.target_x)
		end
		coin.pos.y += coin.speed
		coin.pos.y = min(coin.pos.y, coin.target_y)


		if coin.pos.x == coin.target_x and coin.pos.y == coin.target_y then
			coin.pick_target()  -- pick a new target for the next drop
		end
	end

	coin.enter_bucket = function()
		for bucket in all(state.buckets) do
			if coin.pos.x >= bucket.pos.x and coin.pos.x <= bucket.pos.x + 8 then
				-- coin.value = bucket.value
				local money_earned = coin.value_multiplier * bucket.value
				state.money += money_earned
				bucket.state = bucket_state.full
				state.earnings_text = "+" .. money_earned

				sfx(1)
				wait_then_do(1000, function()
					bucket.state = bucket_state.empty
				end)
				del(state.fallings_coins, coin)
				return true
			end
		end
	end

	coin.update = function(self)
		if coin.state == coin_state.initial_drop then
			coin.update_initial_drop()
		elseif coin.state == coin_state.dropping then
			coin.update_dropping()
		end	
	end

	coin.draw = function(self)
		spr(18, coin.pos.x, coin.pos.y)
	end

	return coin
end
-->8
-- bucket
bucket_state = {
	empty = 1,
	full = 2,
}

new_bucket = function(value, x)
	local bucket = {}
	bucket.value = value
	bucket.pos = new_point(x, consts.top_of_buckets)
	bucket.state = bucket_state.empty

	bucket.update = function()
	end

	bucket.draw = function(self)
		if bucket.state == bucket_state.empty then
			spr(1, bucket.pos.x, bucket.pos.y)
		else
			if flr(rnd(2)) == 0 then
				spr(1, bucket.pos.x, bucket.pos.y)
			else
				spr(16, bucket.pos.x, bucket.pos.y)
			end
		end
		print(bucket.value, bucket.pos.x + 2, bucket.pos.y + 8, 7)
	end

	return bucket
end
-->8
-- upgrades
selected_option = 1
function new_upgrades()
	local padding = 4
	local top_of_desc = 70
	local num_columns = 2
	local upgrade_texts = {
		{ title = "buckets", description = "increase the value of each of the buckets", on_press = function()
			for b in all(state.buckets) do
				b.value += 1
			end
			state.money -= 1
		end},
		-- { title = "red coins", description = "unlock red coins (costs 1 coin)", on_press = function()
		-- 	if state.money >= 1 then
		-- 		state.special_coins.red += 1
		-- 		state.money -= 1
		-- 	end
		-- end, id = 2 },
		{ title = "coin cost", description = "increase how much it costs to drop a coin", on_press = function() end },
		{ title = "coin value", description = "increase how much each coin is worth (increases cost to drop)", on_press = function()
		end },
		-- { title = "red coins", description = "unlock red coins (costs 1 coin)", on_press = function()
		-- 	if state.money >= 1 then
		-- 		state.special_coins.red += 1
		-- 		state.money -= 1
		-- 	end
		-- end },
		{ title = "bucket speed", description = "increase how quickly buckets fill up", on_press = function() end },
		{ title = "coin speed", description = "increase how quickly coins fall", on_press = function() end },
		{ title = "drop delay", description = "shorten the delay between coin drops", on_press = function() end },
	}
	local upgrade_options = {}
	for i = 1, #upgrade_texts do
		local column = ((i - 1) % num_columns) + 1
		local row = flr((i - 1) / num_columns) + 1
		local pair = upgrade_texts[i]
		local x = padding + 8 + (column - 1) * 54
		local y = padding + 16 + (row - 1) * 14
		add(upgrade_options, new_upgrade_option(x, y, pair.title, pair.description, pair.on_press, i))
		-- 	local pair = upgrade_texts[i]
		-- 	local x = padding + 8 + (j - 1) * 54
		-- 	local y = padding + 16 + ((i - 1) * 14)
		-- 	add(upgrade_options, new_upgrade_option(x, y, pair.title, pair.description))
		-- end
		-- add(upgrade_options, new_upgrade_option(8, 16 + (#upgrade_options * 12), pair.title, pair.description))
	end

	return {
		update = function(self)
			if btnp(🅾️) then
				state.mode = game_mode.drop
			end

			if btnp(❎) then
				local option = upgrade_options[selected_option]
				if option then
					option:on_press()
				end
			end

			local row = flr((selected_option - 1) / num_columns) + 1
			local col = ((selected_option - 1) % num_columns) + 1
			local num_rows = ceil(#upgrade_options / num_columns)

			if btnp(⬅️) then
				if col > 1 then
					selected_option -= 1
				end
			elseif btnp(➡️) then
				if col < num_columns and selected_option < #upgrade_options then
					selected_option += 1
				end
			elseif btnp(⬆️) then
				if row > 1 then
					selected_option -= num_columns
				end
			elseif btnp(⬇️) then
				if row < num_rows and selected_option + num_columns <= #upgrade_options then
					selected_option += num_columns
				end
			end
		end,

		draw_description = function(self)
			local option = upgrade_options[selected_option]
			local desc = option.description
			local max_len = 26  -- shorter lines work better on PICO-8
			local lines = {}
			local current_line = ""
			
			-- Split by words
			for word in all(split(desc, " ")) do
				if #current_line + #word + 1 <= max_len then
						if #current_line > 0 then
							current_line = current_line .. " " .. word
						else
							current_line = word
						end
				else
						add(lines, current_line)
						current_line = word
				end
			end
			
			if #current_line > 0 then
				add(lines, current_line)
			end
			
			-- Draw lines
			for i = 1, #lines do
				print(lines[i], padding * 2 + 2, top_of_desc + 3 + (i-1) * 8, 7)
			end
		end,

		draw = function(self)
			rectfill(padding, padding, 127 - padding, 127 - padding, 1)
			rect(padding, padding, 127 - padding, 127 - padding, 12)
			cprint("- upgrades -", 8, 7)
			for option in all(upgrade_options) do
				option:draw()
			end
			rounded_button(padding * 2, top_of_desc, 127 - padding * 2, 110, "", 7)
			self.draw_description(self)
			cprint("press 🅾️ to return", 115, 7)
		end,
	}
end

options_unlocked = {1, 2, 3, 4}

function new_upgrade_option(x, y, title, description, on_press, id)
	return {
		title = title,
		description = description,

		on_press = function()
			if not options_unlocked[id] then
				return
			end
			on_press()
			sfx(3)
		end,

		-- update = function(self)
		-- 	on_press()
		-- 	sfx(3)
		-- end,

		draw = function(self)
			if not options_unlocked[id] then
				rounded_button(x, y, x + 48, y + 10, self.title, 13)
			elseif selected_option == id then
				rounded_button_filled(x, y, x + 48, y + 10, self.title, 12)
			else
				rounded_button(x, y, x + 48, y + 10, self.title, 7)
			end
		end,
	}
end

__gfx__
00000000c00000c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000c00000c00000700000770000000700000007070000007000000070000007770000777000000770000000000000000000000000000000000000000000
00700700c00000c00007700000007000000770000007770000070000000700000000070000707000007070000000000000000000000000000000000000000000
00077000c00000c00000700000070000000070000000070000007000000770000000700000777000000770009999888800000000000000000000000000000000
00077000c00000c00000700000777000000700000000070000077000000770000007000000777000000070000000000000000000000000000000000000000000
007007000ccccc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000070000000000aaa000005550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7000007000000000aaaaa00005050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7000007000000700aaaaa00055555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7000007000007070aaaaa00055555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000070000007000aaa000055555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777700000000000000000055555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000b0b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
990100002203000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
011000003805538055380550000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
011000001955500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505
