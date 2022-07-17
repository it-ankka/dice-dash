module game
import gx

pub struct Particle {
	pub:
		speed_x int
		speed_y int
		size int
	pub mut: 
		color gx.Color
		pos Pos
		lifespan i64
}
