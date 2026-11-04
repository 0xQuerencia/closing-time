class_name CustomerProfiles
## The night's visitors and their validated walking routes through the existing store layout.
const BROWSE_AISLE := Vector3(-1.5, 0, 0.6)
const BROWSE_COOLER := Vector3(-1.5, 0, -4.1)
const BROWSE_COFFEE := Vector3(-7.15, 0, -0.6)
const COFFEE_FRONT := Vector3(-7.2, 0, 3.0)  # z=3.0 clears the end-cap displays (z<=2.23)
const FLOOR_WAYPOINT := Vector3(-1.5, 0, 2.6)
const AISLE_MOUTH := Vector3(-3.6, 0, 3.0)
const COUNTER_SPOT := Vector3(-5.0, 0, 3.15)
const DOOR_INSIDE := Vector3(1.7, 0, 4.6)
const CAR_APPROACH := [Vector3(1.7, 0, 10.6), Vector3(-1.0, 0, 10.8), Vector3(-3.5, 0, 12.8)]

static func build(markers: Dictionary) -> Array[Dictionary]:
	var entrance: Vector3 = markers.NPCEntrance
	var door: Vector3 = markers.FrontDoor
	var exit: Vector3 = markers.NPCExit
	var arrive: Array[Vector3] = [door, DOOR_INSIDE, FLOOR_WAYPOINT]
	var leave: Array[Vector3] = [AISLE_MOUTH, DOOR_INSIDE, door, exit]
	var aisle := _route(entrance, arrive, [BROWSE_AISLE], [FLOOR_WAYPOINT, AISLE_MOUTH, COUNTER_SPOT], leave)
	var coffee := _route(entrance, arrive, [Vector3(-3.4, 0, 3.0), COFFEE_FRONT, BROWSE_COFFEE], [COFFEE_FRONT, COUNTER_SPOT], leave)
	var cooler := _route(entrance, arrive, [BROWSE_AISLE, BROWSE_COOLER], [BROWSE_AISLE, FLOOR_WAYPOINT, AISLE_MOUTH, COUNTER_SPOT], leave)
	var to_car := _route(entrance, arrive, [BROWSE_AISLE, BROWSE_COOLER], [BROWSE_AISLE, FLOOR_WAYPOINT, AISLE_MOUTH, COUNTER_SPOT], leave)
	to_car["car"] = CAR_APPROACH.duplicate()
	var cooler_car := to_car
	return [
		{"id": "mara", "name": "Mara", "items": ["cup_coffee", "paper"], "model": "office_worker", "start": entrance, "route": coffee, "browse_face": Vector3(-1, 0, 0)},
		{"id": "ben", "name": "Ben", "items": ["cola", "noodles"], "model": "young_man", "start": entrance, "route": aisle, "card_fails": 1, "browse_face": Vector3(1, 0, 0)},
		{"id": "leon1", "name": "Leon", "items": ["water"], "model": "vinrax", "outfit": "leon_jacket", "start": entrance, "route": cooler_car, "mannerism": "LookAround", "browse_face": Vector3(0, 0, -1)},
		{"id": "leon2", "name": "Leon", "items": ["water"], "model": "vinrax", "outfit": "leon_overshirt", "cap": true, "start": entrance, "route": cooler_car, "mannerism": "LookAround", "browse_face": Vector3(0, 0, -1)},
	]

static func _route(entrance: Vector3, arrive: Array[Vector3], browse: Array[Vector3], queue: Array[Vector3], leave: Array[Vector3]) -> Dictionary:
	return {"entrance": entrance, "arrive": arrive, "browse": browse, "queue": queue, "leave": leave}
