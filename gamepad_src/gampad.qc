$modelname "weapons/w_async_gamepad.mdl"
$body "body" "anims/gampad_opt.smd"
$cdmaterials "models/weapons/async_gamepad/"
$cdmaterials "models/weapons/"
$surfaceprop "weapon"
$contents "solid"
$scale 1.0
$sequence "idle" {
	"anims/gampad_opt.smd"
	fps 30
}
$collisionmodel "anims/gampad_opt.smd" {
	$mass 1.5
	$concave
}
