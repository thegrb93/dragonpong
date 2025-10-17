local class = require("class")
local gfx = require("gfx")

local Images = {
	Ball = gfx.ImageAnimated("DragonPong/ball", 10),
	BallOpen = gfx.ImageAnimated("DragonPong/ball_open", 10),
	BallCrying = gfx.ImageAnimated("DragonPong/ball_crying", 10),
	Dragon = gfx.ImageAnimated("DragonPong/dragon", 4),
	DragonWin = gfx.ImageAnimated("DragonPong/dragonwin", 4),
	DragonDefeat = gfx.ImageAnimated("DragonPong/dragondefeat", 4),
	Score = gfx.ImageAnimated("DragonPong/score", 2),
	Background = gfx.Image("DragonPong/background"),
	Cursor = gfx.Image("DragonPong/cursor")
}

local dt = 0.1
local function integrate(state, fx, fy, fa)
	state[4], state[5], state[6] = state[4]+fx*dt, state[5]+fy*dt, state[6]+fa*dt
	state[1], state[2], state[3] = state[1]+state[4]*dt, state[2]+state[5]*dt, (state[3]+state[6]*dt)%1
end
local pk, vk = 100, math.sqrt(4*100)
local function pd(px, py, vx, vy)
	return pk*px + vk*vx, pk*py + vk*vy, 0
end

local Paddle, Ball, Pong

Paddle = class {
	init = function(self)
		self.state = {0, 0, 0, 0, 0, 0}
		self.tx, self.ty = 0, 0
		self.dragongfx = {Images.Dragon:new(), Images.DragonWin:new(), Images.DragonDefeat:new()}
		self.scoregfx = {Images.Score:new(2), Images.Score:new(2), Images.Score:new(2)}
		self.txt1 = gfx.Text("Click screen to ready!", "1", "0"),
		self.txt2 = gfx.Text("Ready!", "1", "0")
		self.wintext = gfx.Text("Winner!", "1", "0")
		self.cursorgfx = gfx.Text("  ", "0", "a")
	end,
	setup = function(self, x, y, flipped)
		local state = self.state
		self.startx, self.starty = x, y
		state[1],state[2],state[4],state[5] = x,y,0,0
		self.flippedleft = flipped
		self.drawing = self.gfx1
		self.ready = false
		self.frozen = true
	end,
	score = function(self, scored)
		self.frozen = true
		if scored then
			self.drawing = self.gfx2
			self.score:add()
		self.drawing = self.egg_open
	end,
	clicked = function(self, x, y)
		self.tx, self.ty = x, y
		self.ready = true
	end,
	think = function(self)
		local state = self.state
		if not self.frozen then
			integrate(self.state, pd(self.tx-state[1], self.ty-state[2], -state[4], -state[5]))
		end

		local flapspeed = dt*(1 + math.min(1, math.sqrt(state[4]^2 + state[5]^2)))
		self.gfx:add(flapspeed)
		if state[4] < -0.5 then
			self.flippedleft = true
		elseif state[4] > 0.5 then
			self.flippedleft = false
		end

		game.monitor:blit(self.drawing, state[1]-self.gfx.w*0.5, state[2]-self.gfx.h*0.5, self.flippedleft)
		game.monitor:blit(Images.Cursor, self.tx, self.ty)

		if self.frozen then
			self:drawScore(self.startx, 10, self.score)
		end
	end,
	drawScore = function(self, x, y, score)
		if score==3 then
			game.monitor:blit(self.wintext, x-4, y-5)
		end
		for i=1, 3 do
			self.gfx[i].t = score>=i and 1 or 0
			game.monitor:blit(self.gfx[i], x+(i-1)*8, y)
		end
	end
}
Ball = class {
	radius = 8,
	init = function(self)
		self.state = {0, 0, 0, 0, 0, 0}
		self.egg = Images.Ball:new(1)
		self.egg_open = Images.BallOpen:new(3, false)
		self.egg_crying = Images.BallCrying:new(1)
	end,
	setup = function(self, x, y)
		local state = self.state
		state[1],state[2],state[3],state[4],state[5],state[6] = x,y,0,0,0,0
		self.frozen = true
		self.drawing = self.egg
		self.egg_open:reset()
		self.egg_crying:reset()
	end,
	score = function(self)
		self.frozen = true
		self.drawing = self.egg_open
		game:addtimer(self.drawing.tlen, function()
			self.drawing = self.egg_crying
		end)
	end,
	think = function(self)
		local state = self.state
		if not self.frozen then
			local prevstate = {state[1], state[2]}

			local lift = 0.1*state[6]*math.sqrt(state[4]^2 + state[5]^2)
			local fx, fy = (-state[5] - state[4])*lift, (state[4] - state[5])*lift
			integrate(state, fx, fy, 0)
			
			self:checkPaddleCollision(state, game.p1.state)
			self:checkPaddleCollision(state, game.p2.state)
			while self:checkBoardCollisions(prevstate, state) do end
		end

		if self.drawing == self.egg then
			self.drawing.t = state[3]
		else
			self.drawing:add(dt)
		end

		game.monitor:blit(self.drawing, state[1]-self.drawing.w*0.5, state[2]-self.drawing.h*0.5)
	end,
	checkPaddleCollision = function(self, x1, x2)
		local dx, dy = x2[1]-x1[1], x2[2]-x1[1]
		local distSqr = dx^2+dy^2
		if distSqr<(self.radius + 12)^2 then
			local normdot = ((x2[4] - x1[4])*(x2[1] - x1[1]))+((x2[5] - x1[5])*(x2[2] - x1[2]))
			if normdot>0 then
				local vnormx, vnormy = normdot*(x2[1] - x1[1])/distSqr, normdot*(x2[2] - x1[2])/distSqr

				local tandot = ((x2[4] - x1[4])*(x1[2] - x2[2]))+((x2[5] - x1[5])*(x2[1] - x1[1])) - self.radius*x1[3]*math.sqrt(distSqr)
				local vtanx, vtany = tandot*(x1[2] - x2[2])/distSqr, tandot*(x2[1] - x1[1])/distSqr

				local m1, m2, m3, m4 = 5/(5+1), 1/(5+1), 1/(1+4), 4/(1+4)
				x1[4], x1[5] = x1[4] + 2*m1*(vnormx-m3*vtanx), x1[5] + 2*m1*(vnormy-m3*vtany)
				x2[4], x2[5] = x2[4] - 2*m2*(vnormy-m3*vtany), x2[5] - 2*m2*(vnormy-m3*vtany)
				x1[3] = x1[3] + 2*m4*math.sqrt(vtanx^2+vtany^2)
			end
		end
	end,
	checkBoardCollisions = function(self, prevstate, state)
		--top of board
		if self:checkLineIntersect(prevstate, state, 0, 3, game.w, 3, 0, 1) then return true end
		--bottom of board
		if self:checkLineIntersect(prevstate, state, 0, game.h-3, game.w, game.h-3, 0, -1) then return true end
	end,
}

Pong = class {
	init = function(self)
		game = self
		self.timers = {}
		self.monitor = gfx.Monitor("top", 0, 0, 168, 81, 0.5)
		self.p1 = Paddle()
		self.p2 = Paddle()
		self.ball = Ball()
		self:setup()
		self:run()
	end,

	setup = function(self)
		self.p1:setup(30, 80, false)
		self.p2:setup(150, 80, true)
		self.ball:setup(80, 80)
		self.think = self.thinkSetup
	end,

	start = function(self)
		self.p1.frozen = false
		self.p2.frozen = false
		self.ball.frozen = false
	end,

	score = function(self)
		local p1scored = self.ball.state[1] > self.center
		self.p1:score(p1scored)
		self.p2:score(not p1scored)
		self.ball:score()
		self:addtimer(5, function() self:setup() end)
	end,

	thinkSetup = function(self)
		if self.p1.ready and self.p2.ready then
			self:addtimer(1, function() self:start() end)
			self.think = thinkAll
		end
		self:thinkAll()
	end,

	thinkAll = function(self)
		self.monitor:blit(Images.Background, 0, 0)
		self.score:think()
		self.p1:think()
		self.p2:think()
		self.ball:think()
	end,

	clicked = function(self, x, y)
		if x<90 then
			self.p1:clicked(x, y)
		elseif x>110 then
			self.p2:clicked(x, y)
		end
	end,

	addtimer = function(self, t, f)
		self.timers[os.startTimer(t)] = f
	end,

	run = function(self)
		self.thinkTimer = function() self:think() self:addtimer(dt, self.thinkTimer) end
		self.thinkTimer()

		local timers = self.timers
		while true do
			local event, p1, p2, p3 = os.pullEvent()
			if event == "monitor_touch" then
				self:clicked(p2, p3)
			elseif event == "timer" then
				local f = timers[p1]
				if f then timers[p1]=nil f() end
			end
		end
	end
}

Pong()
