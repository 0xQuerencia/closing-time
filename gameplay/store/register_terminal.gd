class_name RegisterTerminal
extends Interactable
## The register screen: taking payment completes the sale.
var checkout: Checkout
var powered := Callable()  # set by the electrical system; absent means mains

func _init() -> void:
	super()
	display_name = "register"
	verb = "Take payment at"
	name = "RegisterTerminal"

func has_power() -> bool:
	return not powered.is_valid() or powered.call()

func can_interact(_actor: Node) -> bool:
	return checkout != null and has_power() and checkout.can_take_payment()

func blocked_reason(_actor: Node) -> String:
	if not has_power():
		return "The register is dead."
	return checkout.payment_blocked_reason() if checkout else ""

func prompt_text(actor: Node) -> String:
	if not can_interact(actor):
		return ""
	return "Take payment  %s" % ProductCatalog.price_text(checkout.total_cents())

func interact(actor: Node) -> void:
	checkout.take_payment()
	interacted.emit(actor)

func inspect(actor: Node) -> String:
	inspected.emit(actor)
	return "Register. %s" % checkout.status_text()
