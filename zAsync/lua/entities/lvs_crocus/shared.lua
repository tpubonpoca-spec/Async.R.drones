ENT.Base = "lvs_base_helicopter"
ENT.Type = "anim"
ENT.PrintName = "[LVS] Crocus Remastered"
ENT.Author = "Kortez / zAsync"
ENT.Information = "Crocus Remastered FPV Strike Unit"
ENT.Category = "[LVS] - Drones"

ENT.Spawnable = true
ENT.AdminOnly = false

ENT.MDL = "models/drones/crocus.mdl"

ENT.MaxHP = 60
ENT.Mass = 120

ENT.EngineSounds = {
	{
		sound = "fpv_custom/crocus_idle.ogg",
		Pitch = 150,
		PitchMin = 0,
		PitchMax = 255,
		PitchMul = 100,
		Volume = 1,
		VolumeMin = 0,
		VolumeMax = 1,
		SoundLevel = 100,
		UseDoppler = true,
	},
}
