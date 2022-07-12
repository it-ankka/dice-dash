import gg
import gx
import time

const (
	canvas_width  = 700
	canvas_height  = 490
	game_width   = 20
	game_height  = 14
	tile_size    = canvas_width / game_width
	tick_rate_ms = 16
    player_move_cooldown = 100
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

struct App {
mut:
	gg         &gg.Context
	score      int
	player     Player
	start_time i64
	last_tick  i64
}

fn (mut app App) reset_game() {
	app.score = 0
	app.player.pos = Pos{9, 6}
	app.player.dir = .@none
	app.player.last_dir = .@none
	app.player.color = gx.blue
	app.player.distance_to_target = 0
	app.start_time = time.ticks()
	app.last_tick = time.ticks()
}

// Game loop
fn on_frame(mut app App) {

	mut delta_dir := Pos{0, 0}

	now := time.ticks()
	if now -  app.last_tick >= tick_rate_ms {
		app.gg.begin()
		app.last_tick = now

		if app.player.distance_to_target < 1 {
			// finding delta direction
			delta_dir = match app.player.dir {
				.up { Pos{0, -1} }
				.down { Pos{0, 1} }
				.left { Pos{-1, 0} }
				.right { Pos{1, 0} }
				.@none { Pos{0, 0} }
			}

			new_pos := app.player.pos + delta_dir

			new_pos_inbounds := new_pos.x >= 8
				&& new_pos.x < 12
				&& new_pos.y >= 5
				&& new_pos.y < 9

			if new_pos_inbounds {
				app.player.distance_to_target = tile_size
				app.player.pos = new_pos
			} else {
				// app.player.distance_to_target = 0
				app.player.dir = .@none
			}
		} else {
			app.player.distance_to_target -= 4
		}

        // Draw guides
		app.gg.draw_rect_filled(
			8 * tile_size,
			5 * tile_size,
			4 * tile_size,
			4 * tile_size,
			gx.light_gray
		)

		// Draw player
		app.gg.draw_rect_filled(
			app.player.pos.x * tile_size - app.player.distance_to_target * delta_dir.x,
			app.player.pos.y * tile_size - app.player.distance_to_target * delta_dir.y,
			tile_size,
			tile_size,
			app.player.color
		)

        // Draw grid
		for x := 0; x < game_width; x++ {
			for y := 0; y < game_height; y++ {
				app.gg.draw_circle_filled(
					x * tile_size + tile_size / 2, 
					y * tile_size + tile_size / 2, 
					3,
					gx.gray
				)
			}
		}

		app.gg.end()
	}

}

// events
fn on_keydown(key gg.KeyCode, mod gg.Modifier, mut app App) {
	match key {
		.w, .up {
			if app.player.dir != .down {
				app.player.dir = .up
			}
		}
		.s, .down {
			if app.player.dir != .up {
				app.player.dir = .down
			}
		}
		.a, .left {
			if app.player.dir != .right {
				app.player.dir = .left
			}
		}
		.d, .right {
			if app.player.dir != .left {
				app.player.dir = .right
			}
		}
		else {}
	}
}

fn on_keyup(key gg.KeyCode, mod gg.Modifier, mut app App) {
	app.player.dir = .@none
}

// Setup and app start
fn main() {
	mut app := App{
		gg: 0
	}

	app.reset_game()

	app.gg = gg.new_context(
		bg_color: gx.black
		frame_fn: on_frame
		keydown_fn: on_keydown
		keyup_fn: on_keyup
		user_data: &app
		width: canvas_width
		height: canvas_height
		create_window: true
		resizable: false
		window_title: 'voop'
	)

	app.gg.run()
}


