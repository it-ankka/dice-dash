import gg
import gx
import time

const (
	canvas_width  = 700
	canvas_height  = 490
	game_width   = 20
	game_height  = 14
	player_speed = 6
	tile_size    = canvas_width / game_width
	tick_rate_ms = 16
)

struct Pos {
	x int
	y int
}

fn (a Pos) + (b Pos) Pos {
	return Pos{a.x + b.x, a.y + b.y}
}

fn (a Pos) - (b Pos) Pos {
	return Pos{a.x - b.x, a.y - b.y}
}

enum Direction {
	up
	down
	left
	right
	@none
}

enum UserInput {
	up
	down
	left
	right
	action
	@none
}


struct Player {
mut:
	pos Pos
	distance_to_target int
	dir Direction
	last_dir Direction
	color gg.Color
}

struct Shape {
mut:
	pos Pos
	color gg.Color
}

struct Game {
mut:
	gg         &gg.Context
	input_buffer     []UserInput
	input_buffer_last_frame     []UserInput
	score      int
	player     Player
	start_time i64
	last_tick  i64
}

fn (mut game Game) reset() {
	game.score = 0
	game.input_buffer = []UserInput{}
	game.player.pos = Pos{9, 6}
	game.player.dir = .@none
	game.player.last_dir = .@none
	game.player.color = gx.blue
	game.player.distance_to_target = 0
	game.start_time = time.ticks()
	game.last_tick = time.ticks()
}


// convert to direction
fn (input UserInput)  to_dir() Direction {
	return match input {
		.up { Direction.up }
		.down { Direction.down }
		.left { Direction.left }
		.right { Direction.right }
		else { .@none }
	}
}

// finding delta direction
fn  get_move_delta(dir Direction) Pos {
	return match dir {
		.up { Pos{0, -1} }
		.down { Pos{0, 1} }
		.left { Pos{-1, 0} }
		.right { Pos{1, 0} }
		else { Pos{0, 0} }
	}
}

fn last_directional_input(game Game) UserInput {
	directional_inputs := [UserInput.up, UserInput.down, UserInput.left, UserInput.right]
	for input in game.input_buffer.reverse() {
		if input in directional_inputs {
			return input
		}
	}
	return UserInput.@none
}

// Game loop
fn on_frame(mut game Game) {

	
	input_dir := last_directional_input(game)
	delta_dir := get_move_delta(input_dir.to_dir())

	now := time.ticks()
	if now -  game.last_tick >= tick_rate_ms {
		game.last_tick = now

		new_pos := game.player.pos + delta_dir

		new_pos_inbounds := new_pos.x >= 8
			&& new_pos.x < 12
			&& new_pos.y >= 5
			&& new_pos.y < 9

		if new_pos_inbounds && game.player.distance_to_target < 1 && input_dir != .@none {
			game.player.distance_to_target = tile_size
			game.player.pos = new_pos
			game.player.last_dir = input_dir.to_dir()
		} else if game.player.distance_to_target > 0 {
			game.player.distance_to_target -= player_speed

			if game.player.distance_to_target < 0 {
				game.player.distance_to_target = 0
			}
		}


		game.gg.begin()

        // Draw guides
		game.gg.draw_rect_filled(
			8 * tile_size,
			5 * tile_size,
			4 * tile_size,
			4 * tile_size,
			gx.light_gray
		)
		last_move_delta := get_move_delta(game.player.last_dir)
		player_x := game.player.pos.x * tile_size - last_move_delta.x * game.player.distance_to_target
		player_y := game.player.pos.y * tile_size - last_move_delta.y * game.player.distance_to_target

		// Draw player
		game.gg.draw_rect_filled(
			player_x,
			player_y,
			tile_size,
			tile_size,
			game.player.color
		)

        // Draw grid
		for x := 0; x < game_width; x++ {
			for y := 0; y < game_height; y++ {
				game.gg.draw_circle_filled(
					x * tile_size + tile_size / 2, 
					y * tile_size + tile_size / 2, 
					3,
					gx.gray
				)
			}
		}

		game.gg.end()
	}

}

fn set_input_status(status bool, key gg.KeyCode, mod gg.Modifier, mut game Game) {
	input := match key {
		.w, .up {
			UserInput.up
		}
		.s, .down {
			UserInput.down
		}
		.a, .left {
			UserInput.left
		}
		.d, .right {
			UserInput.right
		}
		.space {
			UserInput.action
		}
		else {
			UserInput.@none
		}
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
	}

	game.reset()

	game.gg = gg.new_context(
		bg_color: gx.black
		frame_fn: on_frame
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


