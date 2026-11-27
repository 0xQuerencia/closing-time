extends SceneTree
## Mount the shipped archive in an empty project; source-tree files cannot hide a missing resource.
const FORBIDDEN := [
	"assets/models/office_props/", "assets/models/characters/vinrax/",
	"assets/models/characters/young_man", "assets/models/characters/office_worker",
	"assets/models/props/desktop_pc", "assets/models/props/cctv_",
	"assets/models/props/mug", "assets/models/props/bottle_crate",
	"assets/models/props/fire_extinguisher", "assets/models/exterior.glb",
	"assets/models/exterior_car_gray", "assets/audio/footsteps/",
	"assets/fonts/roboto_condensed/", "assets/fonts/vt323/",
	"assets/fonts/pixelify_sans/", "assets/fonts/jetbrains_mono/"
]
const REQUIRED := [
	"scenes/world/market_root.tscn", "scenes/apartment/apartment.tscn", "scenes/route9/route9.tscn",
	"gameplay/story/data/production_story.json", "gameplay/dialogue/data/production_dialogue.json",
	"assets/fonts/original/marlow.fnt", "assets/models/opening/route9_wagon.glb",
	"assets/models/cooler_aisle.glb", "assets/models/characters/original/jamie_lod0.glb",
	"assets/models/characters/original/leon_lod0.glb", "assets/story/dvr/rear-hall-0.png",
	"assets/story/dvr/rear-hall-1.png", "assets/story/dvr/rear-hall-2.png", "assets/story/dvr/rear-hall-3.png",
]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not ProjectSettings.load_resource_pack(args[0]):
		push_error("Unable to mount shipped PCK")
		quit(1)
		return
	var failures := 0
	var paths: Array[String] = []
	_walk("res://assets",paths)
	for folder in ["build", "local"]:
		if DirAccess.dir_exists_absolute("res://" + folder):
			push_error("Workspace output directory packaged: " + folder)
			failures += 1
	for path in paths:
		for pattern in FORBIDDEN:
			if path.trim_prefix("res://").begins_with(pattern):
				push_error("Forbidden legacy asset packaged: " + path)
				failures += 1
	for path in REQUIRED:
		if not ResourceLoader.exists("res://" + path) and not FileAccess.file_exists("res://" + path):
			push_error("Missing production resource: " + path)
			failures += 1
	if paths.is_empty():
		push_error("No mounted asset entries were enumerated")
		failures += 1
	print("PACK AUDIT: ",paths.size()," asset paths; ",failures," failures")
	quit(1 if failures else 0)

func _walk(path: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		paths.append(path.path_join(file))
	for child in dir.get_directories():
		_walk(path.path_join(child),paths)
