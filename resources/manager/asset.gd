# Asset manager: scans folders for .gd/.tscn assets and caches by id.
extends Manager
class_name AssetManager

const ID := "assets"

func manager_id() -> String: return ID

var assets: Dictionary = {}

func _scan_assets(asset_path: String, assets_by_id: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(asset_path)
	if dir == null:
		push_error("Drive: Failed to open directory: " + asset_path)
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if entry == "." or entry == ".." or entry.begins_with("."):
			continue
		var entry_path: String = asset_path + "/" + entry
		if dir.current_is_dir():
			_scan_assets(entry_path, assets_by_id)
			continue
		var ext: String = entry.get_extension().to_lower()
		if ext != "tscn" and ext != "gd":
			continue
		var asset_id: String = entry.get_basename().to_lower()
		var asset: Asset = Asset.new()
		asset.id = asset_id
		asset.kind = ext
		asset.path = entry_path
		if ext == "tscn":
			assets_by_id[asset_id] = asset
		elif not assets_by_id.has(asset_id) or assets_by_id[asset_id].kind != "tscn":
			assets_by_id[asset_id] = asset
	dir.list_dir_end()

func list(asset_path: String) -> Array[Asset]:
	var assets_by_id: Dictionary = {}
	_scan_assets(asset_path, assets_by_id)
	assets.clear()
	var results: Array[Asset] = []
	for asset in assets_by_id.values():
		results.append(asset)
		assets[asset.id] = asset
	return results

func lookup(asset_id: String) -> Asset:
	var key: String = _key(asset_id)
	if key == "":
		return null
	return assets.get(key, null)
