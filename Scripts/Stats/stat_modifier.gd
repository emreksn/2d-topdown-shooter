class_name StatModifier
extends Resource

enum Operation {
	FLAT,
	INCREASED,
	MORE
}

enum Scope {
	LOCAL = 1,
	GLOBAL = 2
}

@export var stat_id: StringName
@export var operation: Operation = Operation.FLAT
@export var value: float = 0.0
@export_flags("Local:1", "Global:2") var scope: int = Scope.GLOBAL
@export var target_domain: StringName
@export var required_all_tags: Array[StringName] = []
@export var required_any_tags: Array[StringName] = []
@export var excluded_tags: Array[StringName] = []

func applies_to(
	domain: StringName,
	context_tags: Array[StringName],
	scope_mask: int
) -> bool:
	if scope & scope_mask == 0:
		return false
	if target_domain != &"" and target_domain != domain:
		return false
	for tag in required_all_tags:
		if not context_tags.has(tag):
			return false
	if not required_any_tags.is_empty():
		var found_any := false
		for tag in required_any_tags:
			if context_tags.has(tag):
				found_any = true
				break
		if not found_any:
			return false
	for tag in excluded_tags:
		if context_tags.has(tag):
			return false
	return true
