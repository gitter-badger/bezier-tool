
class Illust_ator
	@COLOR_ASSISTANCE: 'rgb(86, 111, 255)'

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
			@mousedown = true

			switch @state
				when @STATE_DEFAULT
					@bezier = new QuadraticCurve(@canvas, @ctx)
					@bezier.click(x, y)
					@state = @STATE_CLICKED

				when @STATE_CLICKED
					@bezier.anchor(x, y)
					@state = @STATE_ANCHORED

			@canvas.trigger 'bezier:clear'

		@canvas.on 'mouseup', (e) =>
			[x, y] = [e.offsetX, e.offsetY]
			@mousedown = false

			if @STATE_ANCHORED
				@bezier.determine(x, y)
				@state = @STATE_CLICKED

				bezier = new QuadraticCurve(@canvas, @ctx)
				@bezier.connect bezier
				@bezier = bezier

			if (@bezier.eAnchor.x != x) || (@bezier.eAnchor.y != y)
				@bezier.cpFixed = true
				@bezier.cp.x = x
				@bezier.cp.y = y

		@canvas.on 'mousemove', (e) =>
			[x, y] = [e.offsetX, e.offsetY]

			@canvas.trigger 'bezier:clear' if @state >= @STATE_CLICKED

			if @mousedown && @bezier.cpFixed
				if !@bezier.isBezier
					@bezier.toBezier()
				@bezier.cp2Move(x, y)

			else
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
		@ctx.strokeStyle = @color
		@ctx.moveTo @start.x, @start.y
		@ctx.lineTo @end.x, @end.y
		@ctx.stroke()

class QuadraticCurve extends Shape
	constructor: (@canvas, @ctx, @color = '#000') ->
		@sAnchor = new Dot(@canvas, @ctx, Illust_ator.COLOR_ASSISTANCE)
		@eAnchor = new Dot(@canvas, @ctx, Illust_ator.COLOR_ASSISTANCE)
		@cp      = new Dot(@canvas, @ctx, Illust_ator.COLOR_ASSISTANCE)
		@cLine   = new Line(@canvas, @ctx, Illust_ator.COLOR_ASSISTANCE)
		@cp2     = null
		@c2Line  = null
		@cpFixed = false

	click: (x, y) ->
		@sAnchor.x = @cp.x = @eAnchor.x = x
		@sAnchor.y = @cp.y = @eAnchor.y = y

		@sAnchor.add()
		@eAnchor.add()
		@add()

	anchor: (x, y) ->
		@eAnchor.x = x
		@eAnchor.y = y

		if !@cpFixed
			@cp.x = x
			@cp.y = y

		@cp.add()
		@cLine.add()

	determine: ->
		@cLine.remove()
		@cp.remove()
		@sAnchor.remove()
		@eAnchor.remove()
		@cp2.remove() if @cp2
		@c2Line.remove() if @c2Line
		@cLine.remove() if @cLine

	anchorMove: (x, y) ->
		@eAnchor.x = x
		@eAnchor.y = y

		if !@cpFixed
			@cp.x = x
			@cp.y = y

	cpMove: (x, y) ->
		sub = {x: @eAnchor.x - x, y:@eAnchor.y - y}
		@cp.x = x - (sub.x * 2) * -1
		@cp.y = y - (sub.y * 2) * -1

		@cLine.start.x = x
		@cLine.start.y = y
		@cLine.end.x   = @cp.x
		@cLine.end.y   = @cp.y

	# FIXME: cpMoveとかぶってる、共通化
	cp2Move: (x, y) ->
		sub = {x: @eAnchor.x - x, y:@eAnchor.y - y}
		@cp2.x = x - (sub.x * 2) * -1
		@cp2.y = y - (sub.y * 2) * -1

		@c2Line.start.x = x
		@c2Line.start.y = y
		@c2Line.end.x   = @cp2.x
		@c2Line.end.y   = @cp2.y

	connect: (bezier) ->
		bezier.click(@eAnchor.x, @eAnchor.y)

	toBezier: ->
		@isBezier = true
		@cp2    = new Dot(@canvas, @ctx, Illust_ator.COLOR_ASSISTANCE)
		@c2Line = new Line(@canvas, @ctx, Illust_ator.COLOR_ASSISTANCE)

		# FIXME: ここゴリ押し
		@cLine.start.x = @sAnchor.x
		@cLine.start.y = @sAnchor.y
		@cLine.end.x   = @cp.x
		@cLine.end.y   = @cp.y

		@cLine.add()
		@cp2.add()
		@c2Line.add()

	remove: ->
		@determine()
		# @sLine.remove()
		super

	render: ->
		@ctx.beginPath()
		@ctx.strokeStyle = @color
		@ctx.moveTo @sAnchor.x, @sAnchor.y
		if @cp2
			@ctx.bezierCurveTo @cp.x, @cp.y, @cp2.x, @cp2.y, @eAnchor.x, @eAnchor.y
		else
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
