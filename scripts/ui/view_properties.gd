extends RefCounted

# Some Control setters notify the theme or layout even for an identical value.
static func apply(node: Object, property: StringName, value: Variant) -> void:
	if node.get(property) != value:
		node.set(property,value)
