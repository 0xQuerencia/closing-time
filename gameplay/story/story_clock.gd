class_name StoryClock
extends RefCounted
## In-fiction clock. It only moves when the story moves it, never on a real-time timer.
signal changed(text: String)
const SHIFT_START := 23 * 60  # 11:00 PM; `elapsed` counts minutes after this
var elapsed := 24  # 11:24 PM

## Moves forward only. Hours 0-11 mean AM after midnight.
func advance_to(hour24: int, minute: int) -> bool:
	var target := hour24 * 60 + minute + (24 * 60 if hour24 < 12 else 0) - SHIFT_START
	if target <= elapsed:
		return false
	elapsed = target
	changed.emit(text())
	return true

func text() -> String:
	var total := (SHIFT_START + elapsed) % (24 * 60)
	@warning_ignore("integer_division")
	var hour := total / 60
	var twelve := hour % 12
	return "%d:%02d %s" % [12 if twelve == 0 else twelve, total % 60, "AM" if hour < 12 else "PM"]
