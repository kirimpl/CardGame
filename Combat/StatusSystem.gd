extends RefCounted
class_name StatusSystem

static func apply_effect(effects: Dictionary, effect: EffectData, durability: int, stacks: int = 1) -> void:
	if effect == null or effect.id == "" or durability <= 0:
		return
	var id: String = effect.id
	var e: Dictionary = effects.get(id, {})
	if e.is_empty():
		e = {"data": effect, "dur": durability, "stacks": max(1, stacks)}
	else:
		e["data"] = effect
		match effect.stack_model:
			EffectData.StackModel.INTENSITY:
				e["stacks"] = int(e.get("stacks", 0)) + max(1, stacks)
				e["dur"] = max(int(e.get("dur", 0)), durability)
			EffectData.StackModel.UNIQUE:
				e["stacks"] = 1
				e["dur"] = max(int(e.get("dur", 0)), durability)
			_:
				e["stacks"] = 1
				e["dur"] = int(e.get("dur", 0)) + durability
	effects[id] = e


static func build_effect_details(effects: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id in effects.keys():
		var e: Dictionary = effects[id]
		var eff: EffectData = e.get("data") as EffectData
		if eff == null:
			continue
		out[id] = {
			"title": eff.title if eff.title != "" else str(id),
			"description": eff.description,
			"stacks": int(e.get("stacks", 1)),
			"duration": int(e.get("dur", 0)),
			"stack_model": int(eff.stack_model),
		}
	return out

