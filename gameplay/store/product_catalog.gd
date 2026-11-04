class_name ProductCatalog
## Fictional products. Prices are integer cents.
const ITEMS := {
	"crisps": {"name": "Hollis Salt Crisps", "price": 249, "shape": "box", "size": Vector3(0.21, 0.28, 0.07), "color": Color(0.5, 0.1, 0.07), "band": Color(0.88, 0.8, 0.55), "blurb": "Family bag. Best before March."},
	"cola": {"name": "Marlow's Cola", "price": 179, "shape": "can", "size": Vector3(0.066, 0.122, 0.066), "color": Color(0.35, 0.04, 0.04), "band": Color(0.85, 0.82, 0.75), "blurb": "330 ml, ice cold if the cooler is behaving."},
	"water": {"name": "Birch Spring Water", "price": 149, "shape": "can", "size": Vector3(0.07, 0.21, 0.07), "color": Color(0.55, 0.7, 0.78), "band": Color(0.12, 0.3, 0.22), "blurb": "500 ml. Still."},
	"coffee": {"name": "Night Owl Instant Coffee", "price": 399, "shape": "can", "size": Vector3(0.085, 0.14, 0.085), "color": Color(0.12, 0.08, 0.05), "band": Color(0.75, 0.55, 0.2), "blurb": "Strong. The label says so twice."},
	"cup_coffee": {"name": "Fresh Coffee, Regular", "price": 99, "shape": "can", "ink": Color(0.1, 0.06, 0.02), "size": Vector3(0.082, 0.11, 0.082), "color": Color(0.88, 0.85, 0.76), "band": Color(0.55, 0.3, 0.12), "blurb": "From the pot by the wall. Brewed until ten, apparently."},
	"paper": {"name": "Bellwick Courier", "price": 150, "shape": "box", "ink": Color(0.12, 0.12, 0.12), "size": Vector3(0.3, 0.012, 0.22), "color": Color(0.78, 0.76, 0.7), "band": Color(0.55, 0.55, 0.52), "blurb": "Yesterday's headlines, today's price."},
	"trash_bag": {"name": "Trash bag", "price": 0, "shape": "sack", "ink": Color(0.5, 0.5, 0.5), "size": Vector3(0.34, 0.4, 0.24), "color": Color(0.03, 0.035, 0.04), "band": Color(0.05, 0.055, 0.06), "blurb": "Tied off. Heavier than it looks."},
	"noodles": {"name": "Kettle Cup Noodles", "price": 219, "shape": "box", "size": Vector3(0.09, 0.11, 0.09), "color": Color(0.7, 0.25, 0.1), "band": Color(0.9, 0.85, 0.6), "blurb": "Add hot water. Wait three minutes."},
}

static func get_def(id: String) -> Dictionary:
	return ITEMS.get(id, {})

static func price_text(cents: int) -> String:
	@warning_ignore("integer_division")
	return "$%d.%02d" % [cents / 100, cents % 100]
