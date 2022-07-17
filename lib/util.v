module lib

// POSITION
pub struct Pos {
pub:
	x int
	y int
}

fn (a Pos) + (b Pos) Pos {
	return Pos{a.x + b.x, a.y + b.y}
}

fn (a Pos) - (b Pos) Pos {
	return Pos{a.x - b.x, a.y - b.y}
}

// DIRECTION
pub enum Direction {
	up
	down
	left
	right
	@none
}

// finding delta direction
pub fn (dir Direction) move_delta() Pos {
	return match dir {
		.up { Pos{0, -1} }
		.down { Pos{0, 1} }
		.left { Pos{-1, 0} }
		.right { Pos{1, 0} }
		else { Pos{0, 0} }
	}
}

pub fn (dir Direction) reverse() Direction {
	return match dir {
		.up { .down }
		.down { .up }
		.left { .right }
		.right { .left }
		else { .@none }
	}
}

// INPUT
pub enum UserInput {
	up
	down
	left
	right
	action
	reset
	@none
}

// convert to direction
pub fn (input UserInput) to_dir() Direction {
	return match input {
		.up { Direction.up }
		.down { Direction.down }
		.left { Direction.left }
		.right { Direction.right }
		else { .@none }
	}
}


pub enum OnFinish {
	destroy
	@none
}
