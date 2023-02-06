package SongOfTheEarth

/// CONTROLS "G" GAME STATE
GLOBAL_set_clear_alpha :: #force_inline proc(alpha: u8)
{
	g.clear_alpha = alpha
}

GLOBAL_set_scene :: #force_inline proc(scene: GameScene)
{
	g.scene = scene
}