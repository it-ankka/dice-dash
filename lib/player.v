module lib

pub struct Player {
pub mut:
	pos Pos
	distance_to_target int
	last_dir Direction
	value int
}

// Get the offsets of the three points of the triangle 
// x1, y1, x2, y2, x3, y3,
pub fn (player Player) get_arrow_coords() (f64, f64, f64, f64, f64, f64) {
	return match player.last_dir {
		.up { 0.5, -0.3, 0.3, -0.1, 0.7, -0.1 }
		.down { 0.5, 1.3, 0.3, 1.1, 0.7, 1.1 }
		.left { -0.3, 0.5, -0.1, 0.3, -0.1, 0.7 }
		.right { 1.3, 0.5, 1.1, 0.3, 1.1, 0.7 }
		else { 1.3, 0.5, 1.1, 0.3, 1.1, 0.7 }
	}
}
