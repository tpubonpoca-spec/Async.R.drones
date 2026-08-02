$modelname "weapons/w_async_gamepad.mdl"
$body "body" "anims/clean_stripped_dabest.smd"
$cdmaterials "models/weapons/async_gamepad/"
$cdmaterials "models/weapons/"
$surfaceprop "weapon"
$scale 1.0
$sequence "idle" {
	"anims/clean_stripped_dabest.smd"
	fps 30
}
$collisionmodel "anims/clean_stripped_dabest.smd" {
	$mass 1.5
}
