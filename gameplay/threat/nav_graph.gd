class_name NavGraph
extends RefCounted
## Hand-placed walking graph through the store, the staff corridor, the office and the stockroom. Every edge is swept
## with the player's capsule in the tests, so Leon only ever walks lines the player could walk too.
const NODES := {
	"vestibule": Vector2(4.2, -4.95),
	"hall_office": Vector2(4.25, -4.3),
	"hall_mid": Vector2(4.25, -2.2),
	"hall_stock": Vector2(4.25, 0.0),
	"hall_breaker": Vector2(4.25, 2.6),
	"hall_south": Vector2(4.25, 4.4),
	"office_door": Vector2(5.0, -4.3),
	"office_in": Vector2(5.9, -4.3),
	"office_desk": Vector2(6.6, -3.5),
	"stock_door": Vector2(5.0, 0.0),
	"stock_in": Vector2(6.2, 0.0),
	"stock_mid": Vector2(6.4, 2.0),
	"stock_alcove": Vector2(7.7, 3.0),
	"shop_ne": Vector2(2.4, -4.3),
	"shop_e_mid": Vector2(2.4, -1.6),
	"shop_e": Vector2(2.4, 0.0),
	"shop_se": Vector2(2.4, 2.9),
	"front_in": Vector2(1.7, 4.6),
	"front_lane": Vector2(0.9, 2.9),
	"lane_mid": Vector2(-1.5, 2.9),
	"lane_counter": Vector2(-4.5, 2.9),
	"lane_west": Vector2(-7.3, 2.9),
	"counter_end": Vector2(-3.4, 3.7),
	"clerk_gap": Vector2(-3.4, 5.0),
	"clerk": Vector2(-5.6, 5.1),
	"north_e": Vector2(1.5, -4.3),
	"north_mid": Vector2(-1.5, -4.3),
	"north_w": Vector2(-4.5, -4.3),
	"aisle_a": Vector2(-1.5, -0.9),
	"aisle_b": Vector2(-4.5, -0.9)}
const EDGES := [
	["vestibule", "hall_office"], ["hall_office", "hall_mid"], ["hall_mid", "hall_stock"], ["hall_stock", "hall_breaker"],
	["hall_breaker", "hall_south"], ["hall_office", "office_door"], ["office_door", "office_in"], ["office_in", "office_desk"],
	["hall_stock", "stock_door"], ["stock_door", "stock_in"], ["stock_in", "stock_mid"], ["stock_mid", "stock_alcove"],
	["hall_office", "shop_ne"], ["hall_stock", "shop_e"], ["shop_ne", "shop_e_mid"], ["shop_e_mid", "shop_e"],
	["shop_e", "shop_se"], ["shop_se", "front_in"], ["shop_se", "front_lane"], ["front_lane", "lane_mid"],
	["lane_mid", "lane_counter"], ["lane_counter", "lane_west"], ["lane_counter", "counter_end"], ["counter_end", "clerk_gap"],
	["clerk_gap", "clerk"], ["shop_ne", "north_e"], ["north_e", "north_mid"], ["north_mid", "north_w"],
	["north_mid", "aisle_a"], ["aisle_a", "lane_mid"], ["north_w", "aisle_b"], ["aisle_b", "lane_counter"],
	["front_in", "front_lane"]]
var astar := AStar3D.new()
var ids := {}

func _init() -> void:
	var next := 0
	for key in NODES:
		ids[key] = next
		var p: Vector2 = NODES[key]
		astar.add_point(next, Vector3(p.x, 0.0, p.y))
		next += 1
	for edge in EDGES:
		astar.connect_points(ids[edge[0]], ids[edge[1]])

func point(key: String) -> Vector3:
	var p: Vector2 = NODES[key]
	return Vector3(p.x, 0.0, p.y)

func nearest_key(pos: Vector3) -> String:
	var best := ""
	var best_d := INF
	for key in NODES:
		var d := point(key).distance_squared_to(Vector3(pos.x, 0.0, pos.z))
		if d < best_d:
			best_d = d
			best = key
	return best

## Walkable points from `from` to `to` (graph nodes between them, not including `from`).
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a: int = ids[nearest_key(from)]
	var b: int = ids[nearest_key(to)]
	var nodes := astar.get_point_path(a, b)
	var out := PackedVector3Array()
	for p in nodes:
		out.append(p)
	return out
