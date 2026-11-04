class_name CustomerProfiles
## Authored visitors and the validated walking routes through the existing store layout.
const BROWSE_SPOT := Vector3(-1.5, 0, 0.6)
const COUNTER_SPOT := Vector3(-5.0, 0, 3.15)
const FLOOR_WAYPOINT := Vector3(-1.5, 0, 2.6)
const AISLE_MOUTH := Vector3(-3.6, 0, 3.0)
const DOOR_INSIDE := Vector3(1.7, 0, 4.6)

static func build(markers: Dictionary) -> Array[Dictionary]:
	var entrance: Vector3 = markers.NPCEntrance
	var door: Vector3 = markers.FrontDoor
	var exit: Vector3 = markers.NPCExit
	var arrive: Array[Vector3] = [door, DOOR_INSIDE, FLOOR_WAYPOINT]
	var browse: Array[Vector3] = [BROWSE_SPOT]
	var queue: Array[Vector3] = [FLOOR_WAYPOINT, AISLE_MOUTH, COUNTER_SPOT]
	var leave: Array[Vector3] = [AISLE_MOUTH, DOOR_INSIDE, door, exit]
	var route := {"entrance": entrance, "arrive": arrive, "browse": browse, "queue": queue, "leave": leave}
	return [
		{"id": "c1", "product": "crisps", "start": entrance, "route": route, "jacket": Color(0.14, 0.22, 0.17), "trousers": Color(0.12, 0.13, 0.17), "skin": Color(0.72, 0.55, 0.43), "hair": Color(0.08, 0.06, 0.05)},
		{"id": "c2", "product": "coffee", "start": entrance, "route": route, "jacket": Color(0.32, 0.12, 0.1), "trousers": Color(0.09, 0.1, 0.12), "skin": Color(0.45, 0.32, 0.24), "hair": Color(0.12, 0.1, 0.09)},
	]
