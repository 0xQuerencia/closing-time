class_name ProductCatalog
## Fictional products. Prices are integer cents.
const ITEMS := {
	"crisps": {"name": "Hollis Salt Crisps", "price": 249, "shape": "box", "size": Vector3(0.21, 0.28, 0.07), "color": Color(0.5, 0.1, 0.07), "band": Color(0.88, 0.8, 0.55), "blurb": "Family bag. Best before March."},
	"cola": {"name": "Marlow's Cola", "price": 179, "shape": "can", "size": Vector3(0.066, 0.122, 0.066), "color": Color(0.35, 0.04, 0.04), "band": Color(0.85, 0.82, 0.75), "blurb": "330 ml, ice cold if the cooler is behaving."},
	"water": {"name": "Birch Spring Water", "price": 149, "shape": "can", "size": Vector3(0.07, 0.21, 0.07), "color": Color(0.55, 0.7, 0.78), "band": Color(0.12, 0.3, 0.22), "blurb": "500 ml. Still."},
	"coffee": {"name": "Night Owl Instant Coffee", "price": 399, "shape": "can", "size": Vector3(0.085, 0.14, 0.085), "color": Color(0.12, 0.08, 0.05), "band": Color(0.75, 0.55, 0.2), "blurb": "Strong. The label says so twice."},
	"noodles": {"name": "Kettle Cup Noodles", "price": 219, "shape": "box", "size": Vector3(0.09, 0.11, 0.09), "color": Color(0.7, 0.25, 0.1), "band": Color(0.9, 0.85, 0.6), "blurb": "Add hot water. Wait three minutes."},
}

static func get_def(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func price_text(cents: int) -> String:
	@warning_ignore("integer_division")
	return "$%d.%02d" % [cents / 100, cents % 100]
