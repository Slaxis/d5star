# Typed command envelope for the Air bus.
extends Resource
class_name Cmd

var type: StringName = &""
var source: Node = null
var target: Node = null
var payload: Dictionary = {}

static func make(t: StringName, data: Dictionary = {}, from: Node = null, to: Node = null) -> Cmd:
	var c := Cmd.new()
	c.type = t
	c.source = from
	c.target = to
	c.payload = data
	return c
