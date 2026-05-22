# thing/things/

D5Star uses **pure-data Things**: every entity is the base `Thing` node
(`thing/thing.gd`) carrying JSON `data`, with type inheritance via the
`ancestor` key. There are no per-entity GDScript node classes — behaviour
lives in systems, not in entity subclasses.

This folder is the optional home that `God.thing_script()` scans for custom
`Thing` node scripts. It is intentionally empty. Keep it that way unless a
Thing genuinely needs node behaviour the data model and external systems
cannot provide — and prefer placing such scripts in the game/module layer.

(This file only exists so the folder is present; it is ignored by the asset
scanner.)
