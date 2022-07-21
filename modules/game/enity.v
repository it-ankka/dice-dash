module game

import rand

pub struct Entity {
pub mut:
	destroyed bool
	speed int
	pos Pos
	next_pos Pos
	dir Direction
	movement MovementCfg
	value int
}

pub struct MovementCfg {
	pub mut:
	dist int
	dir Direction
	speed int
	speed_multiplier f32 = 1
	destination Pos
	on_finish OnMoveFinish = .@none
}

// Action on move finish
pub enum OnMoveFinish {
	reroll
	destroy
	@none
}

pub fn (mut entity Entity) destroy() {
	entity.destroyed = true
}

pub fn (mut entity Entity) set_move_def(distance int) {
	entity.movement.dist = distance
	entity.movement.dir = entity.dir
	entity.movement.speed_multiplier = 1
}

pub fn (mut entity Entity) set_move(cfg MovementCfg) {
	entity.movement = MovementCfg{
		...entity.movement
		on_finish: cfg.on_finish
		dist: cfg.dist
		dir: cfg.dir
		destination: cfg.destination
		speed_multiplier: cfg.speed_multiplier
	}
}

pub fn (mut entity Entity) update_move() {
	delta := int(f32(entity.movement.speed) * entity.movement.speed_multiplier)
	entity.movement.dist -= delta
	if entity.movement.dist < 0 {
		entity.movement.dist = 0 
		match entity.movement.on_finish {
			.reroll {
				entity.pos = entity.movement.destination
				entity.value = ( entity.value + rand.int_in_range(1, 4) or { 1 } ) % 6
			} .destroy {
				entity.destroyed = true
			} else { }
		}
		entity.movement.on_finish = .@none
	} 
}

// Get the offsets of the three points of the triangle 
// x1, y1, x2, y2, x3, y3,
pub fn (entity Entity) get_arrow_coords() (f64, f64, f64, f64, f64, f64) {
	return match entity.dir {
		.up { 0.5, -0.3, 0.3, -0.1, 0.7, -0.1 }
		.down { 0.5, 1.3, 0.3, 1.1, 0.7, 1.1 }
		.left { -0.3, 0.5, -0.1, 0.3, -0.1, 0.7 }
		.right { 1.3, 0.5, 1.1, 0.3, 1.1, 0.7 }
		else { 1.3, 0.5, 1.1, 0.3, 1.1, 0.7 }
	}
}
