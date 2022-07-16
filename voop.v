module main

import os
import gg {Rect}
import gx
import time
import rand
import lib {Player, Enemy, Pos, Direction, UserInput}

const (
	canvas_width  = 700
	canvas_height  = 490
	game_width   = 20
	game_height  = 14
	lanes = 4
	dot_size = 4
	player_speed = 6
	tile_size    = canvas_width / game_width
	tick_rate_ms = 16
	colors = [gx.blue, gx.light_red, gx.yellow, gx.orange, gx.green, gx.purple]
	enemy_spawn_interval_ms = 1500
	dice_size = tile_size - 2
	horizontal_lanes_start = game_height / 2 - lanes / 2
	horizontal_lanes_end = horizontal_lanes_start + lanes
	vertical_lanes_start = game_width / 2 - lanes / 2
	vertical_lanes_end = vertical_lanes_start + lanes
)


// GAME
struct Game {
mut:
	gg         &gg.Context
	die_imgs 	[]gg.Image
	spawn_marker_img gg.Image
	input_buffer     []UserInput
	input_buffer_last_frame     []UserInput
	score      int
	player     Player
	start_time i64
	last_tick  i64
	next_enemy &Enemy
	enemies []&Enemy
	last_enemy_spawn i64
}

fn (mut game Game) reset() {
	game.score = 0
	game.enemies = []
	game.next_enemy = game.get_next_enemy()
	game.player.pos = Pos{9, 6}
	game.player.last_dir = .right
	game.player.value = rand.intn(colors.len) or { 0 }
	game.player.distance_to_target = 0
	game.start_time = time.ticks()
	game.last_tick = time.ticks()
	game.last_enemy_spawn = time.ticks()
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

	// Draw guide area
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
			game.gg.draw_rect_filled(
				x * tile_size + tile_size / 2 - dot_size / 2,
				y * tile_size + tile_size / 2 - dot_size / 2,
				dot_size,
				dot_size,
				gg.Color{50,50,50,100}
			)
		}
	}

	last_move_delta := game.player.last_dir.move_delta()
	player_x := game.player.pos.x * tile_size - last_move_delta.x * game.player.distance_to_target
	player_y := game.player.pos.y * tile_size - last_move_delta.y * game.player.distance_to_target

	// Draw enemies
	for enemy in game.enemies {
			enemy_x := enemy.pos.x * tile_size + ( tile_size - dice_size ) / 2
			enemy_y := enemy.pos.y * tile_size + ( tile_size - dice_size ) / 2
			game.gg.draw_image(
				enemy_x,
				enemy_y,
				dice_size,
				dice_size,
				game.die_imgs[enemy.value]
			)
	}

	next_enemy_x := game.next_enemy.pos.x * tile_size
	next_enemy_y := game.next_enemy.pos.y * tile_size
	game.gg.draw_image(next_enemy_x, next_enemy_y, tile_size, tile_size, game.spawn_marker_img)

	// Draw player
	game.gg.draw_image(player_x, player_y, tile_size, tile_size, game.die_imgs[game.player.value])

	// Draw arrow to indicate player direction
	x1, y1, x2, y2, x3, y3 := game.player.get_arrow_coords()
	game.gg.draw_triangle_filled(
		player_x + tile_size * f32(x1),
		player_y + tile_size * f32(y1),
		player_x + tile_size * f32(x2),
		player_y + tile_size * f32(y2),
		player_x + tile_size * f32(x3),
		player_y + tile_size * f32(y3),
		gx.red
	)
	game.gg.draw_triangle_empty(
		player_x + tile_size * f32(x1),
		player_y + tile_size * f32(y1),
		player_x + tile_size * f32(x2),
		player_y + tile_size * f32(y2),
		player_x + tile_size * f32(x3),
		player_y + tile_size * f32(y3),
		gx.dark_red
	)


	game.gg.end()
}

// Randomize spawn of next enemy
fn (mut game Game) get_next_enemy() &Enemy {
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

	return &Enemy{
		dir: enemy_dir
		pos: enemy_pos
		value: value
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

fn inbounds (pos Pos) bool {
	return pos.x >= vertical_lanes_start
	&& pos.x < vertical_lanes_end
	&& pos.y >= horizontal_lanes_start
	&& pos.y < horizontal_lanes_end
}

// Update loop
[live]
fn update(mut game Game) {
	
	input := game.last_game_input()
	delta_dir := input.to_dir().move_delta()

	now := time.ticks()
	if now -  game.last_tick >= tick_rate_ms {

		if now - game.last_enemy_spawn >= enemy_spawn_interval_ms {
			game.spawn_enemy()
			game.last_enemy_spawn = now
		}

		if game.key_pressed(UserInput.reset) {
			game.reset()
		}

		game.last_tick = now

		new_pos := game.player.pos + delta_dir

		new_pos_inbounds := inbounds(new_pos)

		// If player stationary and move key pressed, move
		if new_pos_inbounds && game.player.distance_to_target < 1 && input != .@none {
			if input == .action && game.key_pressed(.action) {
				// filter out enemies in the lane
				mut enemies_in_lane := match game.player.last_dir {
					.up{
						game.enemies.filter( it.pos.x == game.player.pos.x && it.pos.y < horizontal_lanes_start )
					}
					.down {
						game.enemies.filter( it.pos.x == game.player.pos.x && it.pos.y >= horizontal_lanes_end )
					}
					.left {
						game.enemies.filter( it.pos.y == game.player.pos.y && it.pos.x < vertical_lanes_start )
					}
					.right {
						game.enemies.filter( it.pos.y == game.player.pos.y && it.pos.x >= vertical_lanes_end )
					}
					else { game.enemies.filter(false) }
				}
				match game.player.last_dir {
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
					if enemy.value == game.player.value {
						mut destroyed_enemies := []&Enemy{}
						for e in enemies_in_lane {
							if e.value == game.player.value {
								destroyed_enemies << e
							} else {
								break
							}
						}
						game.enemies = game.enemies.filter(!(it in destroyed_enemies))
						game.player.value = ( game.player.value + rand.int_in_range(1, 4) or { 1 } ) % 6
					} else {
						// Swap with enemy
						game.player.value, enemy.value = enemy.value, game.player.value
					}
				}
			} else if input != .action {
				game.player.distance_to_target = tile_size
				game.player.pos = new_pos
				game.player.last_dir = input.to_dir()
			}
		} else if game.player.distance_to_target > 0 {
			game.player.distance_to_target -= player_speed

			if game.player.distance_to_target < 0 {
				game.player.distance_to_target = 0
			}
		} else if input.to_dir() != .@none {
			game.player.last_dir = input.to_dir()
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
		.space, .right_alt	{ UserInput.action }
		.r 				{ UserInput.reset }
		else 			{ UserInput.@none }
	}

	if input == .@none {
		return
	}

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
	}

	game.reset()

	game.gg = gg.new_context(
		init_fn: init_images
		bg_color: gx.black
		frame_fn: update
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
