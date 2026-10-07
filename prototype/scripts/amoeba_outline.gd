extends RefCounted
## A cached signed-distance field of the existing artwork. It supplies geometry,
## not a second visible layer, so reaching tissue shares the body's outer rim.
const RESOLUTION := 192
static var cached: ImageTexture

static func texture_for(art: Texture2D) -> ImageTexture:
	if cached!=null: return cached
	var image := art.get_image()
	image.decompress()
	var distances := PackedFloat32Array()
	var inside := PackedByteArray()
	distances.resize(RESOLUTION*RESOLUTION)
	inside.resize(distances.size())
	for y in RESOLUTION:
		for x in RESOLUTION:
			var source := Vector2i(int((x+0.5)*image.get_width()/RESOLUTION),int((y+0.5)*image.get_height()/RESOLUTION))
			inside[y*RESOLUTION+x] = 1 if image.get_pixelv(source).a>0.45 else 0
	for y in RESOLUTION:
		for x in RESOLUTION:
			var index := y*RESOLUTION+x
			var boundary := false
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var at: Vector2i = Vector2i(x,y)+offset
				if at.x>=0 and at.x<RESOLUTION and at.y>=0 and at.y<RESOLUTION and inside[at.y*RESOLUTION+at.x]!=inside[index]: boundary = true
			distances[index] = 0.5 if boundary else 1000.0
	# Two chamfer passes approximate Euclidean distance at sub-game-pixel spacing.
	for y in RESOLUTION:
		for x in RESOLUTION:
			var index := y*RESOLUTION+x
			if x>0: distances[index] = minf(distances[index],distances[index-1]+1.0)
			if y>0:
				distances[index] = minf(distances[index],distances[index-RESOLUTION]+1.0)
				if x>0: distances[index] = minf(distances[index],distances[index-RESOLUTION-1]+sqrt(2.0))
				if x<RESOLUTION-1: distances[index] = minf(distances[index],distances[index-RESOLUTION+1]+sqrt(2.0))
	for y in range(RESOLUTION-1,-1,-1):
		for x in range(RESOLUTION-1,-1,-1):
			var index := y*RESOLUTION+x
			if x<RESOLUTION-1: distances[index] = minf(distances[index],distances[index+1]+1.0)
			if y<RESOLUTION-1:
				distances[index] = minf(distances[index],distances[index+RESOLUTION]+1.0)
				if x>0: distances[index] = minf(distances[index],distances[index+RESOLUTION-1]+sqrt(2.0))
				if x<RESOLUTION-1: distances[index] = minf(distances[index],distances[index+RESOLUTION+1]+sqrt(2.0))
	for i in distances.size(): distances[i] *= (-1.0 if inside[i] else 1.0)/RESOLUTION
	cached = ImageTexture.create_from_image(Image.create_from_data(RESOLUTION,RESOLUTION,false,Image.FORMAT_RF,distances.to_byte_array()))
	return cached
