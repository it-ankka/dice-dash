module main

import os
import gg {Rect}
import gx
import math
import time
import rand
import lib {Entity, Pos, Direction, UserInput}

const (
	canvas_width  = 1000
	canvas_height  = 700
	game_width   = 20
	game_height  = 14
	tile_size    = canvas_width / game_width
	lanes = 4
	player_speed = tile_size / 5
	enemy_speed = tile_size / 4
	dot_size = tile_size / 8
	tick_rate_ms = 16
	colors = [gx.blue, gx.light_red, gx.yellow, gx.orange, gx.green, gx.purple]
	enemy_spawn_interval_default = 1500
	dice_size = tile_size - 2
	horizontal_lanes_start = game_height / 2 - lanes / 2
	horizontal_lanes_end = horizontal_lanes_start + lanes
	vertical_lanes_start = game_width / 2 - lanes / 2
	vertical_lanes_end = vertical_lanes_start + lanes
	default_text_cfg = gx.TextCfg{
		color: gx.white
		size: tile_size
		align: .center
	}
)

fn inbounds (pos Pos) bool {
	return pos.x >= vertical_lanes_start
	&& pos.x < vertical_lanes_end
	&& pos.y >= horizontal_lanes_start
	&& pos.y < horizontal_lanes_end
}

// GAME
struct Game {
mut:
	gg         &gg.Context
	start_time 	i64
	last_tick  	i64
	die_imgs 	[]gg.Image
	spawn_marker_img gg.Image
	input_buffer     []UserInput
	input_buffer_last_frame     []UserInput
	score      	int
	level 		int
	player     	&Entity
	next_enemy 	&Entity
	enemies []	&Entity
	last_enemy_spawn i64
}

fn (mut game Game) reset() {
	game.score = 0
	game.level = 1
	game.enemies = []
	game.next_enemy = game.get_next_enemy()
	game.player = &Entity{
		pos: Pos{9, 6}
		dir: .right
		value: rand.intn(colors.len) or { 0 }
		movement: lib.MovementCfg{
			dist: 0
			speed_multiplier: 1
			speed: player_speed
		}
	}
	game.start_time = time.ticks()
	game.last_tick = time.ticks()
	game.last_enemy_spawn = time.ticks()
}

// Randomize spawn of next enemy
fn (mut game Game) get_next_enemy() &Entity {
	dirs := [Direction.up, Direction.down, Direction.left, Direction.right]
	enemy_dir := dirs[rand.intn(dirs.len) or { 0 }]
	lane := rand.intn(lanes) or { 0 }
	x, y := match enemy_dir {
		.up {
			vertical_lanes_start + lane, (game_height - 1)
		}
		.down {
			vertical_lanes_start + lane, 0
		}
		.left {
			(game_width - 1), horizontal_lanes_start + lane
		}
		.right {
			0, horizontal_lanes_start + lane
		}
		else {
			0, 0
		}
	}

	enemy_pos := Pos{x, y}

	// Randomize color
	value := rand.intn(colors.len) or { 0 }

	return &Entity{
		dir: enemy_dir
		pos: enemy_pos
		value: value
		movement: lib.MovementCfg{
			speed: enemy_speed
			speed_multiplier: 1
			dist: tile_size
			dir: enemy_dir
		}
	}
}

fn (mut game Game) spawn_enemy() {
	enemy_pos := game.next_enemy.pos
	enemy_dir := game.next_enemy.dir

	// Push all enemies in the same lane forward 
	mut enemies := match enemy_dir {
		.up{
			game.enemies.filter( it.pos.x == enemy_pos.x && it.pos.y >= horizontal_lanes_end )
		}
		.down {
			game.enemies.filter( it.pos.x == enemy_pos.x && it.pos.y < horizontal_lanes_start )
		}
		.left {
			game.enemies.filter( it.pos.y == enemy_pos.y && it.pos.x >= vertical_lanes_end )
		}
		.right {
			game.enemies.filter( it.pos.y == enemy_pos.y && it.pos.x < vertical_lanes_start )
		}
		else { game.enemies.filter(false) }
	}

	for mut e in enemies {
			e.pos += enemy_dir.move_delta()
			e.set_move_def(tile_size)
			// Reset game if no longer outside of player's zone
			if inbounds(e.pos) {
				println("GAME OVER")
				game.reset()
			}
	}
	// Spawn enemy
	game.enemies << game.next_enemy
	game.next_enemy = game.get_next_enemy()
}

fn (game Game) key_pressed(input UserInput) bool {
	return input in game.input_buffer && !(input in game.input_buffer_last_frame)
}

fn (game Game) last_game_input() UserInput {
	game_inputs := [UserInput.up, UserInput.down, UserInput.left, UserInput.right, UserInput.action]
	for input in game.input_buffer.reverse() {
		if input in game_inputs {
			return input
		}
	}
	return UserInput.@none
}

// Draw the game
fn (game Game) draw() {
	game.gg.begin()

	// Draw player area
	game.gg.draw_rect_filled(
		vertical_lanes_start * tile_size,
		horizontal_lanes_start * tile_size,
		lanes * tile_size,
		lanes * tile_size,
		gx.light_gray
	)

	// Draw grid
	for x := 0; x < game_width; x++ {
		for y := 0; y < game_height; y++ {
			dot_pos := Pos{x, y}
			color := match true {
				(dot_pos.x < vertical_lanes_end && dot_pos.x >= vertical_lanes_start && !inbounds(dot_pos)) ||
				(dot_pos.y < horizontal_lanes_end && dot_pos.y >= horizontal_lanes_start && !inbounds(dot_pos)) {
					gx.rgba(255,255,0,100)
				}
				else {
					gx.rgba(50,50,50,100)
				}
			}
			game.gg.draw_rect_filled(
				x * tile_size + tile_size / 2 - dot_size / 2,
				y * tile_size + tile_size / 2 - dot_size / 2,
				dot_size,
				dot_size,
				color
			)
		}
	}


	// Draw enemies
	for enemy in game.enemies {
			padding := ( tile_size - dice_size ) / 2
			enemy_x := enemy.pos.x * tile_size - enemy.movement.dist * enemy.movement.dir.move_delta().x + padding
			enemy_y := enemy.pos.y * tile_size - enemy.movement.dist * enemy.movement.dir.move_delta().y + padding
			game.gg.draw_image(
				enemy_x,
				enemy_y,
				dice_size,
				dice_size,
				game.die_imgs[enemy.value]
			)
	}

	// Draw next enemy spawn marker
	next_enemy_x := game.next_enemy.pos.x * tile_size
	next_enemy_y := game.next_enemy.pos.y * tile_size
	game.gg.draw_image(next_enemy_x, next_enemy_y, tile_size, tile_size, game.spawn_marker_img)

	// Draw player
	movement_move_delta := game.player.movement.dir.move_delta()
	player_x := game.player.pos.x * tile_size - movement_move_delta.x * game.player.movement.dist
	player_y := game.player.pos.y * tile_size - movement_move_delta.y * game.player.movement.dist
	game.gg.draw_image(player_x, player_y, tile_size, tile_size, game.die_imgs[game.player.value])

	// Draw arrow to indicate player direction
	x1, y1, x2, y2, x3, y3 := game.player.get_arrow_coords()

	a_x := player_x + tile_size * f32(x1)
	a_y := player_y + tile_size * f32(y1)
	b_x := player_x + tile_size * f32(x2)
	b_y := player_y + tile_size * f32(y2)
	c_x := player_x + tile_size * f32(x3)
	c_y := player_y + tile_size * f32(y3)

	game.gg.draw_triangle_filled(a_x, a_y, b_x, b_y, c_x, c_y, gx.red)
	game.gg.draw_triangle_empty(a_x, a_y, b_x, b_y, c_x, c_y, gx.dark_red)

	offset := tile_size / 2
	// Draw score and level
	for i, c in '$game.score'.runes() {
		game.gg.draw_text(i * tile_size + offset, 0, c.str(), default_text_cfg)
	}
	for i, c in 'SCORE'.runes() {
		game.gg.draw_text(i * tile_size + offset, tile_size, c.str(), default_text_cfg)
	}
	for i, c in '$game.level'.runes().reverse() {
		game.gg.draw_text(canvas_width - (i * tile_size + offset), 0, c.str(), default_text_cfg)
	}
	for i, c in 'LEVEL'.runes().reverse() {
		game.gg.draw_text(canvas_width - (i * tile_size + offset), tile_size, c.str(), default_text_cfg)
	}

	game.gg.end()
}



// Update loop
[live]
fn update(mut game Game) {
	
	input := game.last_game_input()
	delta_dir := input.to_dir().move_delta()

	now := time.ticks()
	if now -  game.last_tick >= tick_rate_ms {
		mut enemies := game.enemies
		mut player := game.player
		enemy_spawn_interval := enemy_spawn_interval_default * math.pow(0.9, game.level - 1)

		// Spawn enemy
		if now - game.last_enemy_spawn >= enemy_spawn_interval {
			game.spawn_enemy()
			game.last_enemy_spawn = now
		}

		// Update move movements
		for mut enemy in enemies.filter(it.movement.dist > 0) {
			enemy.update_move()
		}

		if game.key_pressed(UserInput.reset) {
			game.reset()
		}

		game.last_tick = now

		new_pos := player.pos + delta_dir

		new_pos_inbounds := inbounds(new_pos)

		// If player stationary and input pressed
		if new_pos_inbounds && player.movement.dist < 1 && input != .@none {
			// Switch action
			if input == .action && game.key_pressed(.action) {
				// filter out enemies in the lane
				mut enemies_in_lane := match player.dir {
					.up{
						enemies.filter( it.pos.x == player.pos.x && it.pos.y < horizontal_lanes_start )
					}
					.down {
						enemies.filter( it.pos.x == player.pos.x && it.pos.y >= horizontal_lanes_end )
					}
					.left {
						enemies.filter( it.pos.y == player.pos.y && it.pos.x < vertical_lanes_start )
					}
					.right {
						enemies.filter( it.pos.y == player.pos.y && it.pos.x >= vertical_lanes_end )
					}
					else { enemies.filter(false) }
				}
				match player.dir {
					.up{ enemies_in_lane.sort(a.pos.y > b.pos.y) }
					.down { enemies_in_lane.sort(a.pos.y < b.pos.y) }
					.left { enemies_in_lane.sort(a.pos.x > b.pos.x) }
					.right { enemies_in_lane.sort(a.pos.x < b.pos.x) }
					else { }
				}

				// If enemies in lane
				if enemies_in_lane.len > 0 {
					mut enemy := enemies_in_lane[0]
					// Destroy line of enemies with the same value
					if enemy.value == player.value {
						mut destroyed_enemies := []&Entity{}
						for e in enemies_in_lane {
							if e.value == player.value {
								destroyed_enemies << e
							} else {
								break
							}
						}
						game.enemies = enemies.filter(!(it in destroyed_enemies))
						game.score += destroyed_enemies.len * 100 * destroyed_enemies.len
						game.level = game.score / 1000 + 1

						distance := math.max(
							math.abs(player.pos.x - enemy.pos.x), 
							math.abs(player.pos.y - enemy.pos.y)) * tile_size  + 1
						original_pos := player.pos

						player.pos = enemy.pos

						player.set_move(lib.MovementCfg{
							dist: distance, 
							destination: original_pos
							dir: player.dir, 
							speed_multiplier: 3
							on_finish: lib.OnFinish.destroy
						})
					} else {
						// Swap with enemy
						player.value, enemy.value = enemy.value, player.value
						distance := math.max(
							math.abs(player.pos.x - enemy.pos.x), 
							math.abs(player.pos.y - enemy.pos.y)) * tile_size  + 1
							player.set_move(lib.MovementCfg{ 
								dist: distance,
								dir: player.dir.reverse(),
								speed_multiplier: 4
							})
							enemy.set_move(lib.MovementCfg{ 
								dist: distance, 
								dir: enemy.dir.reverse(), 
								speed_multiplier: 4 
							})
					}
				}
			} else if input.to_dir() != .@none {
				// Move action
				player.pos = new_pos
				player.dir = input.to_dir()
				player.set_move_def(tile_size)
			}
		} else if player.movement.dist > 0 {
			// Update movement position if player is mid-move
			player.update_move()
		} else if input.to_dir() != .@none {
			player.dir = input.to_dir()
		}
		game.input_buffer_last_frame = game.input_buffer
		game.draw()
	}
}



fn set_input_status(status bool, key gg.KeyCode, mod gg.Modifier, mut game Game) {
	input := match key {
		.w, .up 		{ UserInput.up }
		.s, .down 	 	{ UserInput.down }
		.a, .left 		{ UserInput.left }
		.d, .right 		{ UserInput.right }
		.space, .j		{ UserInput.action }
		.r 				{ UserInput.reset }
		else 			{ UserInput.@none }
	}

	// return if invalid input
	if input == .@none { return }

	if !(input in game.input_buffer) && status == true {
		game.input_buffer << input
	} else if input in game.input_buffer && status == false {
		game.input_buffer = game.input_buffer.filter(it != input)
	}
}

// Initialization
fn init_images(mut game Game) {
	game.die_imgs = [
		game.gg.create_image(os.resource_abs_path('resources/images/die1.png'))
		game.gg.create_image(os.resource_abs_path('resources/images/die2.png'))
		game.gg.create_image(os.resource_abs_path('resources/images/die3.png'))
		game.gg.create_image(os.resource_abs_path('resources/images/die4.png'))
		game.gg.create_image(os.resource_abs_path('resources/images/die5.png'))
		game.gg.create_image(os.resource_abs_path('resources/images/die6.png'))
	]
	game.spawn_marker_img = game.gg.create_image(os.resource_abs_path('resources/images/spawn_marker.png'))
}

// events
fn on_keydown(key gg.KeyCode, mod gg.Modifier, mut game Game) {
	set_input_status(true, key, mod, mut game)
}

fn on_keyup(key gg.KeyCode, mod gg.Modifier, mut game Game) {
	set_input_status(false, key, mod, mut game)
}


// Setup and game start
fn main() {
	mut game := Game{
		gg: 0
		next_enemy: 0
		player: 0
	}

	font_path := os.resource_abs_path('resources/fonts/ShareTechMono.ttf')
	game.reset()

	game.gg = gg.new_context(
		init_fn: init_images
		bg_color: gx.black
		frame_fn: update
		font_path: font_path
		font_size: 56
		keydown_fn: on_keydown
		keyup_fn: on_keyup
		user_data: &game
		width: canvas_width
		height: canvas_height
		create_window: true
		resizable: false
		window_title: 'VOOP'
	)

	game.gg.run()
}
