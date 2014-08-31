
class Illust_ator
	COLOR_ASSISTANCE: 'rgb(86, 111, 255)'

# ================================
# Actions
# ================================

class ActionModule
	init: ($canvas) ->
	events: ->

class BezierAction
	STATE_DEFAULT: 0
	STATE_CLICKED: 1
	STATE_ANCHORED: 2

	KEY_CODE_ESC: 27

	constructor: (@canvas, @ctx, @state = @STATE_DEFAULT) ->

	events: ->
		@canvas.on 'mousedown', (e) =>
			[x, y] = [e.offsetX, e.offsetY]

			switch @state
				when @STATE_DEFAULT
					@bezier = new QuadraticCurve(@canvas, @ctx)
					@bezier.click(x, y)
					@state = @STATE_CLICKED

				when @STATE_CLICKED
					@bezier.anchor(x, y)
					@state = @STATE_ANCHORED

				when @STATE_ANCHORED
					@bezier.determine(x, y)
					@state = @STATE_CLICKED

					bezier = new QuadraticCurve(@canvas, @ctx)
					@bezier.connect bezier
					@bezier = bezier


			@canvas.trigger 'bezier:clear'

		@canvas.on 'mousemove', (e) =>
			[x, y] = [e.offsetX, e.offsetY]

			@canvas.trigger 'bezier:clear' if @state >= @STATE_CLICKED

			if @state is @STATE_CLICKED
				@bezier.anchorMove(x, y)

			if @state is @STATE_ANCHORED
				@bezier.cpMove(x, y)

		$(window).on 'keydown', (e) =>
			if e.keyCode is @KEY_CODE_ESC
				@state = @STATE_DEFAULT
				@bezier.remove()
				@canvas.trigger 'bezier:clear'


# ================================
# Shapes
# ================================

class Shape
	constructor: (@canvas, @ctx, @color = '#000') ->

	render: ->

	add: ->
		@canvas.trigger 'bezier:shape:add', @
		return @

	remove: ->
		@canvas.trigger 'bezier:shape:remove', @
		return @


class Dot extends Shape
	DOT_SIZE: 5

	constructor: (@canvas, @ctx, @color = '#000', @size = @DOT_SIZE) ->
		@x = 0
		@y = 0

	render: ->
		offset = @size / 2
		@ctx.fillStyle = @color
		@ctx.fillRect(@x - offset, @y - offset, @size, @size)

class Line extends Shape
	constructor: (@canvas, @ctx, @color = '#000') ->
		@start = {x: 0, y: 0}
		@end = {x: 0, y: 0}

	render: ->
		@ctx.beginPath()
		@ctx.fillStyle = @color
		@ctx.moveTo @start.x, @start.y
		@ctx.lineTo @end.x, @end.y
		@ctx.stroke()

class QuadraticCurve extends Shape
	constructor: (@canvas, @ctx, @color = '#000') ->
		@sAnchor = new Dot(@canvas, @ctx, Illust_ator.COLOR_ASSISTANCE)
		@eAnchor = new Dot(@canvas, @ctx, Illust_ator.COLOR_ASSISTANCE)
		@cp      = new Dot(@canvas, @ctx, Illust_ator.COLOR_ASSISTANCE)
		@sLine   = new Line(@canvas, @ctx, Illust_ator.COLOR_ASSISTANCE)
		@cLine   = new Line(@canvas, @ctx)

	click: (x, y) ->
		@sAnchor.x = @eAnchor.x = @sLine.start.x = @sLine.end.x = x
		@sAnchor.y = @eAnchor.y = @sLine.start.y = @sLine.end.y = y

		@sAnchor.add()
		@eAnchor.add()
		@sLine.add()

	anchor: (x, y) ->
		@sLine.remove()

		@eAnchor.x = @cp.x = x
		@eAnchor.y = @cp.y = y

		@cp.add()
		@cLine.add()
		@add()

	determine: ->
		@cLine.remove()
		@cp.remove()
		@sAnchor.remove()
		@eAnchor.remove()

	anchorMove: (x, y) ->
		@sLine.end.x = x
		@sLine.end.y = y

	cpMove: (x, y) ->
		sub = {x: @eAnchor.x - x, y:@eAnchor.y - y}
		@cp.x = x - (sub.x * 2) * -1
		@cp.y = y - (sub.y * 2) * -1

		@cLine.start.x = x
		@cLine.start.y = y
		@cLine.end.x   = @cp.x
		@cLine.end.y   = @cp.y

	connect: (bezier) ->
		bezier.click(@eAnchor.x, @eAnchor.y)

	remove: ->
		@determine()
		@sLine.remove()
		super

	render: ->
		@ctx.beginPath()
		@ctx.fillStyle = @color
		@ctx.moveTo @sAnchor.x, @sAnchor.y
		@ctx.quadraticCurveTo @cp.x, @cp.y, @eAnchor.x, @eAnchor.y
		@ctx.stroke()

class BackGroundImage extends Shape
	constructor: (@canvas, @ctx, src, @color = '#000') ->
		@start = {x: 0, y: 0}
		@end   = {x: 0, y: 0}
		@dist  = {x: 0, y: 0}

		$img = $('<img/>');
		$img.get(0).onload = =>
			@canvas.trigger 'bezier:clear'

		@img = $img.attr('src', src)

	render: ->
		@ctx.drawImage @img.get(0), @dist.x, @dist.y

# init

$window = $(window)
$canvas = $('#canvas')
ctx = $canvas.get(0).getContext('2d')

paths = []

$canvas.attr
	width: $window.width()
	height: $window.height()

$canvas.on 'bezier:shape:add', (e, shape) ->
	paths.push shape
	$canvas.trigger 'bezier:clear'

$canvas.on 'bezier:shape:remove', (e, shape) ->
	idx = paths.indexOf shape
	paths.splice(idx, 1) if idx >= 0

$canvas.on 'bezier:clear', ->
	ctx.clearRect(0, 0, $canvas.width(), $canvas.height())

	for path in paths
		path.render()

bg = new BackGroundImage($canvas, ctx, 'img/bg.png')
$canvas.trigger 'bezier:shape:add', bg

actions = [
	# new DotAction($canvas, ctx),
	new BezierAction($canvas, ctx),
]

for action in actions
	action.events()
