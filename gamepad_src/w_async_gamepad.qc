$modelname "weapons/w_async_gamepad.mdl"
$body "body" "anims/w_gamepad.smd"
$cdmaterials "models/weapons/async_gamepad/"
$cdmaterials "models/weapons/"
$surfaceprop "weapon"
$contents "solid"
$scale 1.0
$sequence "idle" {
	"anims/w_gamepad.smd"
	fps 30
}
$collisionmodel "anims/w_gamepad.smd" {
	$mass 1.5
}
