pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

game_mode = {
	play = 1,
	menu = 2,
	game_over = 3
}

state = {
	current_level = 1,
	total_levels = 4,
	bullet = nil,
	player_paddle = nil,
	mode = game_mode.menu,
	debug_text = "",
	play_final_sound = true,
	current_lives = 3,
	total_lives = 3,
	speed_multiplier = 0.01,
	menu_button_selection = 0,
	shake_frames = 0,
	reset_game = nil
}

function _init()
	state.player_paddle = make_paddle(true)
	state.bullet = make_bullet(8, 64, 3, 0.5) -- starting position and velocity
	menu = make_menu()
	state.reset_game = function()
		state.current_level = 1
		state.bullet.reset()
		state.player_paddle.reset()
		state.mode = game_mode.play
		state.current_lives = state.total_lives
		state.play_final_sound = true
		state.shake_frames = 0
		reload()
	end
end

function _update()
	if state.mode == game_mode.play then
		update_play()
	elseif state.mode == game_mode.menu then
		update_menu()
	elseif state.mode == game_mode.game_over then
		if btnp(❎) then
			state.mode = game_mode.menu -- this is already set in the init function, so no need to set it again
		end
	end
end

function update_play()

	state.player_paddle.update()
	state.bullet.update()

	check_map_collision()
	if is_level_complete() then
		state.current_level += 1
		if state.current_level > state.total_levels then
			state.mode = game_mode.game_over
			return
		end

		sfx(1)

		-- state.bullet = make_bullet(64, 64, -3, 0) -- reset bullet
		-- state.player_paddle = make_paddle(true) -- reset paddle
		state.bullet.reset()
		state.player_paddle.reset()
	end
end

function update_menu()
	menu.update()
end

function _draw()
	cls(2)
	shake_screen()
	if state.mode == game_mode.menu then
		menu.draw()
	elseif state.mode == game_mode.play then
		draw_level(state.current_level)
		state.player_paddle.draw()
		state.bullet.draw()
		draw_hud()
	elseif state.mode == game_mode.game_over then
		if state.current_level > state.total_levels then
			glow_text("you win!", 11, 7)
			if state.play_final_sound then
				sfx(3)
				state.play_final_sound = false
			end
		else
			glow_text("game over", 8, 7)

			if state.play_final_sound then
				sfx(2)
				state.play_final_sound = false
			end
		end

		-- play again
		local play_again_text = "press ❎ to play again"
		print(play_again_text, 64 - #play_again_text * 2, 120, 7)
	end
	print(state.debug_text, 0, 0, 7)
end
-->8
-- utils

function shake_screen()
	if state.shake_frames > 0 then
		local shake_x = rnd(2) - 1
		local shake_y = rnd(2) - 1
		camera(shake_x, shake_y)
		state.shake_frames -= 1
	else
		camera(0, 0) -- reset camera after shaking
	end
end

-- centers text in the middle of the screen
function glow_text(text, glow_color, text_color)
	local x = 64 - #text * 2
	local y = 64 - 4

	for d in all({{-1,0},{1,0},{0,-1},{0,1}}) do
		print(text, x + d[1], y + d[2], glow_color)
	end
	-- print(text, x + 1, y + 1, glow_color) -- glow effect
	print(text, x, y, text_color) -- main text
end


function make_point(x, y)
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
			return make_point(self.x, self.y)
		end
	}
end

function make_vector(x, y)
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
      return make_vector(self.x, self.y)
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

function draw_level(level_num)
	local level_offset_x = (level_num - 1) * 16
	map(level_offset_x, 0, 0, 0, 16, 16) -- draw the level map
end

function draw_hud()
	-- display level at top
	local level_text = "lvl " .. state.current_level
	print(level_text, 64 - #level_text * 2, 0, 7)

	-- display lives at bottom
	-- print("lives", 0, 120, 7)
	-- state.debug_text = "lives: " .. state.current_lives
	for i = 1, state.current_lives do
		spr(7, 118 - (i - 1) * 8, 120) -- draw heart sprite
	end
end

function check_map_collision()
  local bullet_bounds = state.bullet.get_bounds()
  
  -- check the four corners of the ball's bounding box
  local corners = {
    {x = bullet_bounds.left, y = bullet_bounds.top},     -- top-left
    {x = bullet_bounds.right, y = bullet_bounds.top},    -- top-right
    {x = bullet_bounds.left, y = bullet_bounds.bottom},  -- bottom-left
    {x = bullet_bounds.right, y = bullet_bounds.bottom}  -- bottom-right
  }
  
  local level_offset_x = (state.current_level - 1) * 16
  
  for corner in all(corners) do
    local map_x = flr(corner.x / 8)
    local map_y = flr(corner.y / 8)
    
    -- make sure we're within map bounds
    if map_x >= 0 and map_x < 16 and map_y >= 0 and map_y < 16 then
      local tile = mget(level_offset_x + map_x, map_y)
      
      if tile == 3 then  -- hit a brick
        -- destroy the brick
        mset(level_offset_x + map_x, map_y, 0)
		  sfx(0)
        
        -- calculate overlap distances from each side of the tile
        local tile_left = map_x * 8
        local tile_right = tile_left + 8
        local tile_top = map_y * 8
        local tile_bottom = tile_top + 8
        
        local overlap_left = abs(tile_left - bullet_bounds.right)
        local overlap_right = abs(tile_right - bullet_bounds.left)
        local overlap_top = abs(tile_top - bullet_bounds.bottom)
        local overlap_bottom = abs(tile_bottom - bullet_bounds.top)

        -- find the smallest overlap (that's the side that was hit)
        local min_overlap = mmin({overlap_left, overlap_right, overlap_top, overlap_bottom})

      --   state.debug_text = "" .. flr(overlap_left) .. ", " .. flr(overlap_right) .. ", " .. flr(overlap_top) .. ", " .. flr(overlap_bottom).. ", " .. flr(min_overlap)

        if min_overlap == overlap_left or min_overlap == overlap_right then
          -- hit from left or right side - flip X velocity
          state.bullet.vel.x = -state.bullet.vel.x
        else
         --  hit from top or bottom - flip Y velocity
          state.bullet.vel.y = -state.bullet.vel.y
        end
        
      --   -- push ball out of the tile to prevent getting stuck
      --   if min_overlap == overlap_left then
      --     state.bullet.pos.x = tile_left - state.bullet.radius - 1
      --   elseif min_overlap == overlap_right then
      --     state.bullet.pos.x = tile_right + state.bullet.radius + 1
      --   elseif min_overlap == overlap_top then
      --     state.bullet.pos.y = tile_top - state.bullet.radius - 1
      --   elseif min_overlap == overlap_bottom then
      --     state.bullet.pos.y = tile_bottom + state.bullet.radius + 1
      --   end
        
        return -- exit after first collision to avoid multiple bounces per frame
      end
    end
  end
end

function is_level_complete()
  -- check if all bricks in the current level are destroyed
  local level_offset_x = (state.current_level - 1) * 16
  for x = 0, 15 do
	 for y = 0, 15 do
		if mget(level_offset_x + x, y) == 3 then
		  return false -- found an undestroyed brick
		end
	 end
  end
  return true -- all bricks destroyed
end

function mmin(arr)
	local min_val = arr[1]
	for i=2,#arr do
		if arr[i] < min_val then
			min_val = arr[i]
		end
	end
	return min_val
end

-->8
-- paddle

function make_paddle(is_left)
	local paddle = {}
	paddle.width = 4
	paddle.height = 24
	-- paddle.y = 64 - paddle.height / 2 -- center vertically
	paddle.speed = 6
	if is_left then paddle.x = 0 else paddle.x = 128 - paddle.width end

	paddle.reset = function()
		paddle.y = 64 - paddle.height / 2 -- reset to center
	end

	paddle.reset()

	paddle.get_bounds = function()
		return {
			left = paddle.x,
			right = paddle.x + paddle.width,
			top = paddle.y,
			bottom = paddle.y + paddle.height,
			mid_x = paddle.x + paddle.width / 2,
			mid_y = paddle.y + paddle.height / 2, 
		}
	end

	paddle.update = function()
		if btn(⬆️) then
			paddle.y -= paddle.speed
		elseif btn(⬇️) then
			paddle.y += paddle.speed
		end

		local bounds = paddle.get_bounds()
		-- keep within screen bounds
		if bounds.top < 0 then
			paddle.y = 0
		elseif bounds.bottom > 128 then
			paddle.y = 128 - paddle.height
		end
	end

	paddle.draw = function()
		rectfill(paddle.x, paddle.y, paddle.x + paddle.width  - 1, paddle.y + paddle.height, 7)
		line(paddle.x + paddle.width, paddle.y + 1, paddle.x + paddle.width, paddle.y + paddle.height - 2, 7)
		-- print("paddle.y: "..paddle.y, 0, 0, 7)
	end
	
	return paddle
end
-->8
-- pong bullet

bullet_mode = {
	free = 1,
	paddle = 2,
}

function make_bullet(start_x, start_y, vel_x, vel_y)
	local bullet = {}
	-- bullet.pos = make_point(start_x, start_y)
	-- bullet.vel = make_vector(vel_x, vel_y)
	bullet.radius = 3
	-- bullet.mode = bullet_mode.paddle

	bullet.reset = function()
		-- state.debug_text = ""..sx .. ", " .. sy .. " with vel " .. vx .. ", " .. vy
		bullet.pos = make_point(start_x, start_y)
		bullet.vel = make_vector(vel_x, vel_y)
		bullet.mode = bullet_mode.paddle -- reset mode to paddle
	end
	
	bullet.reset()
	
	bullet.destroy = function()
		-- reset bullet to paddle mode
		bullet.mode = bullet_mode.paddle
		bullet.pos:set(start_x, start_y)
		bullet.vel:set(vel_x, vel_y)
		state.shake_frames = 20
		sfx(5)
	end

	bullet.get_bounds = function()
		return {
			left = bullet.pos.x - bullet.radius,
			right = bullet.pos.x + bullet.radius,
			top = bullet.pos.y - bullet.radius,
			bottom = bullet.pos.y + bullet.radius,
			mid_x = bullet.pos.x,
			mid_y = bullet.pos.y,
		}
	end

	bullet.bounce = function()
		bullet.vel:mult(1 + state.speed_multiplier)
	end

	bullet.update = function()
		if bullet.mode == bullet_mode.free then
			update_free()
		elseif bullet.mode == bullet_mode.paddle then
			update_paddle()
		end
	end

	function update_free()
		bullet.pos:add_vector(bullet.vel)

		
		-- handle collision with the paddle
		local player_paddle_bounds = state.player_paddle.get_bounds()
		local bullet_bounds = state.bullet.get_bounds()

		-- Check for collision with the top and bottom of the screen
		local bullet_bounds = bullet.get_bounds()
		if bullet_bounds.top < 0 or bullet_bounds.bottom > 128 then
			-- Reverse the vertical velocity
			bullet.vel.y = -bullet.vel.y
			-- Keep the bullet within bounds
			if bullet_bounds.top < 0 then
				bullet.pos.y = bullet.radius
			elseif bullet_bounds.bottom > 128 then
				bullet.pos.y = 128 - bullet.radius
			end
		end
		
		-- if the bullet's left edge is within the paddle's right edge
		if bullet_bounds.left <= player_paddle_bounds.right
			and bullet_bounds.bottom >= player_paddle_bounds.top
			and bullet_bounds.top <= player_paddle_bounds.bottom then

			-- calculate offset from paddle center
			-- this determines how "high" or "low" the bullet is in relation to the size of the paddle
			local offset = (bullet_bounds.mid_y - player_paddle_bounds.mid_y) / (player_paddle_bounds.bottom - player_paddle_bounds.top)
			-- clamp offset to [-1,1]
			offset = -mid(-1, offset, 1) * 0.22
			if offset == 0 then offset += (rnd(10) - 5) / 100 end
			state.bullet.vel:set_polar(offset, state.bullet.vel:mag())

			-- keep the bullet just outside the paddle
			state.bullet.pos.x = player_paddle_bounds.right + state.bullet.radius + 1
			state.bullet.bounce()
		end
		bullet_bounds = state.bullet.get_bounds()

		if bullet_bounds.left < 0 then
			if state.current_lives > 1 then
				state.current_lives -= 1
				state.bullet.destroy() -- reset bullet
			else
				state.mode = game_mode.game_over -- no lives left, go to game over
				sfx(5)
			end
		end

		if bullet_bounds.right > 128 then
			bullet.pos.x = 128 - bullet.radius
			bullet.vel.x = -bullet.vel.x
		end
	end

	function update_paddle()
		paddle_bounds = state.player_paddle.get_bounds()
		bullet.pos.y = paddle_bounds.mid_y

		if btn(❎) then
			bullet.mode = bullet_mode.free
			bullet.vel:set_polar(0, 3) -- reset to free mode with initial speed
		end
	end
	
	bullet.draw = function()
		circfill(bullet.pos.x, bullet.pos.y, bullet.radius, 7)
		spr(1, bullet.pos.x - bullet.radius, bullet.pos.y - bullet.radius)
	end
	
	return bullet
end
-->8
-- menu screen
function make_menu()
	local menu = {}

	menu.buttons = {
		make_menu_button("easy", 74, function()
			state.reset_game() -- reset game state

			-- easy difficulty
			state.speed_multiplier = 0.01
			state.current_lives = 3
			state.total_lives = 3
		end, 0),
		make_menu_button("normal", 89, function()
			state.reset_game() -- reset game state

			-- normal difficulty
			state.speed_multiplier = 0.015
			state.current_lives = 2
			state.total_lives = 2
		end, 1),
		make_menu_button("hard", 104, function()
			state.reset_game() -- reset game state

			-- hard difficulty
			state.speed_multiplier = 0.02
			state.current_lives = 1
			state.total_lives = 1
		end, 2),
	}

	menu.update = function()
		for button in all(menu.buttons) do
			button.update()
		end

		if btnp(⬆️) then
			state.menu_button_selection = (state.menu_button_selection - 1 + 3) % 3
		elseif btnp(⬇️) then
			state.menu_button_selection = (state.menu_button_selection + 1) % 3
		end
	end

	menu.draw = function()
		map(0, 16, 0, 0, 16, 16) -- draw the menu background
		for button in all(menu.buttons) do
			button.draw()
		end

		local play_text = "press ❎ to start"
		print(play_text, 64 - #play_text * 2, 120, 7)
	end

	return menu

end

function make_menu_button(text, y, action, id)
	local button = {}
	button.text = text
	button.y = y
	button.action = action
	button.width = 80
	button.height = 9
	button.x = 64 - button.width / 2 -- center horizontally


	button.draw = function()
		-- draw main rectangle
		rectfill(button.x+1, button.y, button.x + button.width - 2, button.y + button.height - 1, 15)
		-- draw sides to make it look rounded on corners
		line(button.x, button.y + 1, button.x, button.y + button.height - 2, 15)
		line(button.x + button.width - 1, button.y + 1, button.x + button.width - 1, button.y + button.height - 2, 15)

		-- draw text in the middle
		local text_x = (button.x + button.width / 2) - (#button.text * 2)
		local text_y = button.y + (button.height - 5) / 2

		print(button.text, text_x, text_y, 7)

		if state.menu_button_selection == id then
			spr(1, button.x - 12, button.y + 1, 1, 1, false, false, 0, 0) -- draw selection arrow
		end
	end

	button.update = function()
		if btnp(❎) and state.menu_button_selection == id then
			button.action()
		end
	end

	return button
end


__gfx__
0000000000fff000000070000000000000ff00000000000007700770077007700000000000000000000000000000000000000000000000000000000000000000
000000000fffff00000700000eeeeee00f00f0000000070070077007788778870000000000000000000000000000000000000000000000000000000000000000
00700700fffffff0000700000e0000e0f0000f000000007070000007788888870000000000000000000000000000000000000000000000000000000000000000
00077000fffffff0000700000e0000e0f0000f007777777770000007788888870000007777777000000000000000000000000000000000000000000000000000
00077000fffffff0000700000e0000e00f00f0000000007007000070078888700000777777777700000000000000000000000000000000000000000000000000
007007000fffff00000700000e0000e000ff00000000070000700700007887000007777700077700000000000000000000000000000000000000000000000000
0000000000fff000000700000eeeeee0000000000000000000077000000770000077770000007700000000000000000000000000000000000000000000000000
00000000000000000000700000000000000000000000000000000000000000000777700000007700000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000777000000007700000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000007770000000077700000000007770000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000007770000000777000000000077777000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000007770000077777000000000077077000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000007770007777700000777770077777700000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000777777777000077777770077777700000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000777777700000077770777000077700000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000777000000000077770777000077700000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000077000007770077700777000077700000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000077000007770007770077000077700000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000077700000777007770000000077000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000077700000777000000000007777000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000007700000000000000000077777000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000077700000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000303030303030303000000000000030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000003000000000000000000000000000000000000000000000000000303030303030303000000000000000303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000003030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000003000000000000000000000000000303030303030300000000000000000000000000000000000000000000000303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000003000000000000000000000000000000000000000000000000000303030303030303000000000000000000000000030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000003000000000000000000000000000303030303030300000000000303030303030303000000000000000000000000000303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000303030303030000000000000000000003030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000303030303030000000000000000000303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000008090a0b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000018191a1b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000028292a2b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0006000010050180502c0500100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c00000c3500e350103501135013350153501733018330183301833018330183300030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
913200001805214052110521105211052110521105211802108020f8020f8020f8020f80200802008020080200802008020080200802008020080200802008020080200802008020080200802008020080200802
001000002b0502a0502b0502d0502b0502d0502f0502f0502f0502f0502f0502f0503205037050370503705037050370503705037050370003700037000370000000000000000000000000000000000000000000
03280101244501f450244501f4502445028450244501f45026450234501f4501d4501f45023450264502345024450214501c450184501c450214502445021450234501f4501a4501745013450174501a45017450
000300000e0500d0500a0500805005050040500405002050010500105000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 01424344

