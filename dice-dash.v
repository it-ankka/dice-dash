module main

import audio_player as ap
import os
import gg {Rect}
import gx
import math
import time
import rand
import game {Entity, Particle, MovementCfg, Pos, Direction, UserInput, OnMoveFinish}

const (
	canvas_width  = 1000
	canvas_height  = 700
	game_width   = 20
	game_height  = 14
	sounds = {
		'die_shuffle': os.resource_abs_path('resources/audio/dieShuffle1.wav'),
		'die_throw1': os.resource_abs_path('resources/audio/dieThrow1.wav'),
		'die_throw2': os.resource_abs_path('resources/audio/dieThrow2.wav')
	}
	tile_size    = canvas_width / game_width
	lanes = 4
	player_speed = tile_size / 5
	enemy_speed = tile_size / 4
	dot_size = tile_size / 8
	tick_rate_ms = 16
	colors = [gx.blue, gx.pink, gx.purple, gx.orange, gx.green, gx.red]
	enemy_spawn_interval_default = 1500
	particle_lifespan = 250
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
	ap 			&ap.AudioPlayer
	player_switching bool
	start_time 	i64
	last_tick  	i64
	die_imgs 	[]gg.Image
	particles 	[]&Particle
	spawn_marker_img gg.Image
	input_buffer     []UserInput
	input_buffer_last_frame     []UserInput
	state 		GameState
	score      	int
	level 		int
	tick_rate 	int
	player     	&Entity
	next_enemy 	&Entity
	enemies []	&Entity
	last_enemy_spawn i64
}

fn (mut game Game) on_resize (e &gg.Event, __ voidptr) { 
	println("resized")
	println(e)
}

enum GameState {
	menu
	running
	paused
	game_over
}

fn (mut game Game) start() {
	game.reset()
	game.state = .running
}

fn (mut game Game) reset() {
	game.score = 0
	game.level = 1
	game.enemies = []
	game.particles = []
	game.next_enemy = game.get_next_enemy()
	for _ in 0..4 {
		game.spawn_enemy()
	}
	game.player = &Entity{
		pos: Pos{9, 6}
		dir: .right
		value: rand.intn(colors.len) or { 0 }
		movement: MovementCfg{
			dist: 0
			speed_multiplier: 1
			speed: player_speed
		}
	}
	game.start_time = time.ticks()
	game.last_tick = time.ticks()
	game.last_enemy_spawn = time.ticks()
}

fn (mut game Game) spawn_particle(pos Pos, color gx.Color) {
	offset := tile_size / 2
	game.particles << &Particle{
		pos: Pos{pos.x * tile_size + offset, pos.y * tile_size + offset}
		color: color
		size: rand.int_in_range(2, 5) or { 3 }
		speed_x: rand.int_in_range(-5, 5) or { 5 }
		speed_y: rand.int_in_range(-5, 5) or { 5 }
		lifespan: particle_lifespan
	}
}

fn (mut game Game) update_particles(delta i64) {
	for mut p in game.particles {
		p.pos = Pos{p.pos.x + p.speed_x, p.pos.y + p.speed_y}
		p.lifespan -= delta
		alpha := 255 * p.lifespan / particle_lifespan
		p.color = gx.rgba(p.color.r, p.color.g, p.color.b, u8(alpha) )
	}
}

// Randomize spawn of next enemy
fn (mut game Game) get_next_enemy() &Entity {
	dirs := [Direction.up, Direction.down, Direction.left, Direction.right]
	enemy_dir := dirs[rand.intn(dirs.len) or { 0 }]
	lane := rand.intn(lanes) or { 0 }
	x, y := match enemy_dir {
		.up { vertical_lanes_start + lane, (game_height - 1) }
		.down { vertical_lanes_start + lane, 0 }
		.left { (game_width - 1), horizontal_lanes_start + lane }
		.right { 0, horizontal_lanes_start + lane }
		else { 0, 0 }
	}

	enemy_pos := Pos{x, y}

	// Randomize color
	value := rand.intn(colors.len) or { 0 }

	return &Entity{
		dir: enemy_dir
		pos: enemy_pos
		value: value
		movement: MovementCfg{
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
				game.state = .game_over
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
	player := game.player
	enemies := game.enemies

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
	for enemy in enemies {
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


	//Draw particles
	for p in game.particles {
		game.gg.draw_circle_filled(p.pos.x, p.pos.y, p.size, p.color)
	}


	// Draw player
	movement_move_delta := player.movement.dir.move_delta()
	player_x := player.pos.x * tile_size - movement_move_delta.x * player.movement.dist
	player_y := player.pos.y * tile_size - movement_move_delta.y * player.movement.dist
	game.gg.draw_image(player_x, player_y, tile_size, tile_size, game.die_imgs[player.value])

	// Draw arrow to indicate player direction
	x1, y1, x2, y2, x3, y3 := player.get_arrow_coords()

	a_x := player_x + tile_size * f32(x1)
	a_y := player_y + tile_size * f32(y1)
	b_x := player_x + tile_size * f32(x2)
	b_y := player_y + tile_size * f32(y2)
	c_x := player_x + tile_size * f32(x3)
	c_y := player_y + tile_size * f32(y3)

	game.gg.draw_triangle_filled(a_x, a_y, b_x, b_y, c_x, c_y, gx.red)
	game.gg.draw_triangle_empty(a_x, a_y, b_x, b_y, c_x, c_y, gx.dark_red)

	// Draw overlay if game is not running
	if game.state != .running {
		game.gg.draw_rect_filled(0,0,game.gg.width, game.gg.height, gx.rgba(10, 10, 10, 225))
	}


	// Draw score and level
	if game.state != .menu {
		game.draw_text_to_grid('$game.score', 0, 0, false)
		game.draw_text_to_grid('SCORE', 0, 1, false)

		game.draw_text_to_grid('$game.level', game_width, 0, true)
		game.draw_text_to_grid('LEVEL', game_width, 1, true)
	}


	match game.state {
		.running {

			// Draw next enemy spawn marker
			next_enemy_x := game.next_enemy.pos.x * tile_size
			next_enemy_y := game.next_enemy.pos.y * tile_size
			game.gg.draw_image(next_enemy_x, next_enemy_y, tile_size, tile_size, game.spawn_marker_img)
		}
		.game_over, .paused {
			if game.state == .game_over {
				game.draw_text_to_grid('GAME', game_width / 2 - lanes / 2, 2, false)
				game.draw_text_to_grid('OVER', game_width / 2 - lanes / 2, 3, false)
				game.draw_text_to_grid('SPC,R: RETRY', 4, game_height / 2, false)
				game.draw_text_to_grid('ESC,Q: MENU', 4, game_height / 2 + 1, false)
			} else {
				game.draw_text_to_grid('PAUSED', game_width / 2 - 3, 2, false)
				game.draw_text_to_grid('SPC: RESUME', 6, game_height / 2, false)
				game.draw_text_to_grid('R: RETRY', 8, game_height / 2 + 1, false)
				game.draw_text_to_grid('Q: MENU', 8, game_height / 2 + 2, false)
			}
		}
		.menu {
			game.draw_text_to_grid('DICE', game_width / 2 - lanes / 2, 1, false)
			game.draw_text_to_grid('DASH', game_width / 2 - lanes / 2, 2, false)
			game.draw_text_to_grid('----', game_width / 2 - lanes / 2, 3, false)
			start_text := 'PRESS SPACE TO START'
			game.draw_text_to_grid(start_text, game_width / 2 - start_text.len / 2, game_height / 2, false)

			created_by_text := 'MADE BY'
			name :=  ' LASSI KÖYKKÄ'
			game.draw_text_to_grid(created_by_text, game_width / 2 - created_by_text.len / 2, game_height - 2, false)
			game.draw_text_to_grid(name, game_width / 2 - name.len / 2, game_height - 1, false)
		}

	}



	game.gg.end()
}

fn (game Game) draw_text_to_grid(text string, x int, y int, align_right bool) {
	offset := tile_size / 2
	if !align_right {
		for i, c in text.runes() {
			game.gg.draw_text(x * tile_size + i * tile_size + offset, tile_size * y, c.str(), default_text_cfg)
		}
	} else {
		for i, c in text.runes().reverse() {
			game.gg.draw_text(x * tile_size - (i * tile_size + offset), tile_size * y, c.str(), default_text_cfg)
		}
	}
}



// Update loop
fn (mut game Game) update(now i64, delta i64) {
		input := game.last_game_input()
		delta_dir := input.to_dir().move_delta()

		game.last_tick = now

		mut enemies := game.enemies
		mut player := game.player

		// Remove dead particles
		game.update_particles(delta)
		game.particles = game.particles.filter(it.lifespan > 0)

		// Remove destoyed enemies
		enemies_to_destroy := game.enemies.filter(it.destroyed && player.movement.dist <= 0)
		for e in enemies_to_destroy {
			for _ in 0..50 {
				game.spawn_particle(e.pos, colors[e.value])
			}
		}
		if enemies_to_destroy.len > 0 {
			go game.ap.play('die_throw1')
		}
		game.enemies = game.enemies.filter(!(it in enemies_to_destroy))

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

		input_is_dir := input.to_dir() != .@none

		new_pos := player.pos + delta_dir
		new_pos_inbounds := inbounds(new_pos)

		// Remember if player presse switch button
		if game.key_pressed(.action) {
			game.player_switching = true
		}

		if player.movement.dist > 0 {
			// Update movement position if player is mid-move
			player.update_move()
		} else if input_is_dir && (!new_pos_inbounds || (game.key_pressed(input) && player.dir != input.to_dir())){
			// Turn player to face direction
			player.dir = input.to_dir()
		} else if new_pos_inbounds && input != .@none{
			// Handle input

			if input_is_dir {
				// Move action
				player.pos = new_pos
				player.dir = input.to_dir()
				player.set_move_def(tile_size)
			} else if  game.player_switching {
				game.player_switching = false
				// Switch action
				// filter enemies in the lane
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
						mut destroyed_enemies := 0
						for mut e in enemies_in_lane {
							if e.value != player.value { break }
							destroyed_enemies++
							e.destroy()
						}

						game.score += destroyed_enemies * 100 * destroyed_enemies
						game.level = game.score / 1000 + 1

						distance := math.max(
							math.abs(player.pos.x - enemy.pos.x), 
							math.abs(player.pos.y - enemy.pos.y)) * tile_size  + 1
						original_pos := player.pos

						player.pos = enemy.pos

						player.set_move(MovementCfg{
							dist: distance, 
							destination: original_pos
							dir: player.dir, 
							speed_multiplier: 4
							on_finish: OnMoveFinish.reroll
						})
					} else {
						// Swap with enemy
						player.value, enemy.value = enemy.value, player.value
						distance := math.max(
							math.abs(player.pos.x - enemy.pos.x), 
							math.abs(player.pos.y - enemy.pos.y)) * tile_size  + 1
						player.set_move(MovementCfg{ 
							dist: distance,
							dir: player.dir.reverse(),
							speed_multiplier: 4
						})
						enemy.set_move(MovementCfg{ 
							dist: distance, 
							dir: enemy.dir.reverse(), 
							speed_multiplier: 4 
						})
						// go game.ap.play('die_shuffle')
					}
				}
			}		
		} 
}

fn loop(mut game Game) {

	now := time.ticks()
	delta := now -  game.last_tick
	if delta >= game.tick_rate {
		match game.state {
			.running {
				if game.key_pressed(.menu) || game.key_pressed(.quit) {
					game.state = .paused
				}
				game.update(now, delta)
			} 
			.menu {
				if game.key_pressed(.action) {
					game.reset()
					game.state = .running
				}
				if game.key_pressed(.quit) {
					game.gg.quit()
				}
			}
			.game_over {
				if game.key_pressed(.action) || game.key_pressed(.reset) {
					game.reset()
					game.state = .running
				}
				if game.key_pressed(.quit) || game.key_pressed(.menu) {
					game.reset()
					game.state = .menu
				}
			}
			.paused {
				if game.key_pressed(.action) || game.key_pressed(.menu) {
					game.state = .running
				} else if game.key_pressed(.reset) {
					game.reset()
					game.state = .running
				} else if game.key_pressed(.quit) {
					game.reset()
					game.state = .menu
				}
			}
		}
		game.input_buffer_last_frame = game.input_buffer
	}
	game.draw()
}


fn set_input_status(status bool, key gg.KeyCode, mod gg.Modifier, mut game Game) {
	input := match key {
		.w, .up 		{ UserInput.up }
		.s, .down 	 	{ UserInput.down }
		.a, .left 		{ UserInput.left }
		.d, .right 		{ UserInput.right }
		.space, .j		{ UserInput.action }
		.escape, .p		{ UserInput.menu }
		.q				{ UserInput.quit }
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
fn init_resources(mut game Game) {
	game.ap = ap.audio_player(sounds)
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
	tick_rate := $if windows || macos { tick_rate_ms / 2 } $else { tick_rate_ms }
	// tick_rate := 4
	mut game := Game{
		gg: 0
		ap: 0
		next_enemy: 0
		player: 0
		tick_rate: tick_rate
	}

	font_path := os.resource_abs_path('resources/fonts/ShareTechMono.ttf')
	game.reset()
	// native_rendering :=	$if windows { true } $else { false }
	game.gg = gg.new_context(
		init_fn: init_resources
		bg_color: gx.black
		frame_fn: loop
		font_size: 56
		keydown_fn: on_keydown
		keyup_fn: on_keyup
		user_data: &game
		width: canvas_width
		height: canvas_height
		create_window: true
		resizable: false
		resized_fn: game.on_resize
		window_title: 'DICE-DASH'
		font_path: font_path
		swap_interval: 1
	)

	game.gg.run()
}

