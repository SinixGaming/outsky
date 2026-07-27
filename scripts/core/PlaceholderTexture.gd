class_name PlaceholderTexture
extends RefCounted
## Generates a flat-color ImageTexture at runtime so Phase 1 entities are
## visible with zero art assets. Every user of this only assigns the
## placeholder when a node's texture is still null, so dropping in a real
## sprite sheet later (via the editor) requires no script changes at all.

static func make(size: Vector2i, color: Color) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
