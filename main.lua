
local class = require("class")
local gfx = require("gfx")
local phys = require("phys")

local dt = 0.1
local screenToPhysY, physToScreenY = 41/27, 27/41
local scrw, scrh = 164, 81
local gamew, gameh = scrw, screenToPhysY*scrh
local Images = {
	Egg = gfx.ImageAnimated("dragonpong/img/egg", 1),
	EggOpen = gfx.ImageAnimated("dragonpong/img/egg_open", 1),
	EggCrying = gfx.ImageAnimated("dragonpong/img/egg_crying", 1),
	DragonRed = gfx.ImageAnimated("dragonpong/img/dragon", 1),
	DragonRedWin = gfx.ImageAnimated("dragonpong/img/dragon_win", 1),
	DragonRedLose = gfx.ImageAnimated("dragonpong/img/dragon_lose", 1),
	CursorRed = gfx.Image("dragonpong/img/cursor"),
	Score = gfx.ImageAnimated("dragonpong/img/score", 2),
	Background = gfx.Image("dragonpong/img/board"),
	ClickReady = gfx.Blit("Click screen to ready!", "0", "f"),
	Ready = gfx.Blit("Ready!", "0", "f"),
	Winner = gfx.Blit("Winner!", "0", "f")
}
Images.DragonGreen = Images.DragonRed:swapPallete("e","d")
Images.DragonGreenWin = Images.DragonRedWin:swapPallete("e","d")
Images.DragonGreenLose = Images.DragonRedLose:swapPallete("e","d")
Images.CursorGreen = Images.CursorRed:swapPallete("e","d")

local function boardColliders(colliders, r, p1, p2)
	local wSize = 4
	colliders[#colliders + 1] = phys.WallCollider(-30, wSize+r, gamew+30, wSize+r)
	colliders[#colliders + 1] = phys.WallCollider(gamew+30, gameh-wSize-r, -30, gameh-wSize-r)
	if p1 then
		colliders[#colliders + 1] = phys.WallCollider(wSize+r, gameh/3 + r, wSize+r, -30)
		colliders[#colliders + 1] = phys.WallCollider(wSize+r, gameh + 30, wSize+r, gameh*2/3 - r)
		colliders[#colliders + 1] = phys.CircleCollider(0, gameh/3+r, wSize+r)
		colliders[#colliders + 1] = phys.CircleCollider(0, gameh*2/3-r, wSize+r)
	end
	if p2 then
		colliders[#colliders + 1] = phys.WallCollider(gamew-wSize-r, -30, gamew-wSize-r, gameh/3 + r)
		colliders[#colliders + 1] = phys.WallCollider(gamew-wSize-r, gameh*2/3 - r, gamew-wSize-r, gameh + 30)
		colliders[#colliders + 1] = phys.CircleCollider(gamew, gameh/3+r, wSize+r)
		colliders[#colliders + 1] = phys.CircleCollider(gamew, gameh*2/3-r, wSize+r)
	end
	if p1 and p2 then
		colliders[#colliders + 1] = phys.GoalCollider(0, gameh, 0, 0)
		colliders[#colliders + 1] = phys.GoalCollider(gamew, 0, gamew, gameh)
	end
end

local Paddle, Ball, Pong

local pk, vk = 10, math.sqrt(4*10)
local function pd(px, py, vx, vy)
	return pk*px + vk*vx, pk*py + vk*vy
end

Paddle = class {
	init = function(self, p1, p2)
		local radius = 10
		self.phys = phys.PhysCircleComponent(radius, 10, 10)
		boardColliders(self.phys.colliders, radius, p1, p2)
		if p1 then
			self.startx, self.starty, self.startflipped = gamew/4, gameh/2, false
			self.dragon = Images.DragonGreen:new("frame", {5})
			self.dragonWin = Images.DragonGreenWin:new("frame", {5})
			self.dragonLose = Images.DragonGreenLose:new("frame", {5})
			self.cursor = Images.CursorGreen
		end
		if p2 then
			self.startx, self.starty, self.startflipped = gamew*3/4, gameh/2, true
			self.dragon = Images.DragonRed:new("frame", {5})
			self.dragonWin = Images.DragonRedWin:new("frame", {5})
			self.dragonLose = Images.DragonRedLose:new("frame", {5})
			self.cursor = Images.CursorRed
		end
		self.tx, self.ty = 0, 0
		self.score = 0
		self.ready = false
	end,
	reset = function(self)
		self.phys:set(self.startx,self.starty,0,0,0,0)
		self.tx, self.ty = self.startx, self.starty
		self.flipped = self.startflipped
		self.frozen = true
		self.sprite = self.dragon
		self.sprite:reset()
	end,
	scored = function(self, scored)
		self.frozen = true
		if scored then
			self.sprite = self.dragonWin
			self.score = self.score + 1
		else
			self.sprite = self.dragonLose
		end
		self.sprite:reset()
	end,
	clicked = function(self, x, y)
		self.tx, self.ty = x, y
		self.ready = true
	end,
	think = function(self)
		local state = self.phys.state
		local flapspeed
		if self.frozen then
			flapspeed = 1
		else
			local fx, fy = pd(self.tx-state[1], self.ty-state[2], -state[4], -state[5])
			self.phys:step(fx, fy, 0, dt)
			flapspeed = dt*(1 + math.min(1, math.sqrt(state[4]^2 + state[5]^2)))
		end

		if state[4] < -0.5 then
			self.flipped = true
		elseif state[4] > 0.5 then
			self.flipped = false
		end

		game.monitor:blit(self.cursor, self.tx, self.ty*physToScreenY)
		game.monitor:blit(self.sprite, state[1], state[2]*physToScreenY, self.flipped)
		self.sprite:add(flapspeed)

		if self.frozen then
			local scorex, scorey = state[1]-6, (state[2]-10)*physToScreenY
			if not self.ready then
				game.monitor:blit(Images.ClickReady, scorex, scorey)
			elseif self.score==3 then
				game.monitor:blit(Images.Winner, scorex, scorey)
			else
				for i=1, 3 do
					game.monitor:blit(Images.Score.frames[self.score>=i and 2 or 1], scorex+(i-1)*8, scorey)
				end
			end
		end
	end,
}

Ball = class {
	init = function(self)
		local radius = 6
		self.phys = phys.PhysCircleComponent(radius, 1, 1)
		boardColliders(self.phys.colliders, radius, true, true)
		self.egg = Images.Egg:new("rate", 1)
		self.egg_opening = Images.EggOpen:new("frame", {5}, false)
		self.egg_crying = Images.EggCrying:new("frame", {5})
	end,
	reset = function(self)
		self.phys:set(gamew/2,gameh/2,0,0,0,0)
		self.frozen = true
		self.sprite = self.egg
	end,
	scored = function(self)
		self.frozen = true
		self.sprite = self.egg_opening
		self.sprite:reset()
		game:addtimer(dt*5, function()
			self.sprite = self.egg_crying
			self.sprite:reset()
		end)
	end,
	think = function(self)
		local state = self.phys.state
		if not self.frozen then
			local lift = 0.1*state[6]*math.sqrt(state[4]^2 + state[5]^2)
			local fx, fy = (-state[5] - state[4])*lift, (state[4] - state[5])*lift
			self.phys:step(fx, fy, 0, dt)
		end

		if self.sprite == self.egg then
			self.sprite.t = state[3]
		end

		game.monitor:blit(self.sprite, state[1], state[2]*physToScreenY)
		
		if self.sprite ~= self.egg then
			self.sprite:add(1)
		end
	end,
}

Pong = class {
	init = function(self)
		game = self
		self.timers = {}
		self.monitor = gfx.Monitor("left", 0, 0, scrw, scrh, 0.5)
		self.p1 = Paddle(true, false)
		self.p2 = Paddle(false, true)
		self.ball = Ball()
		self:reset()
		self:run()
	end,

	reset = function(self)
		self.p1:reset()
		self.p2:reset()
		self.ball:reset()
		self.think = self.thinkSetup
	end,

	start = function(self)
		self.p1.frozen = false
		self.p2.frozen = false
		self.ball.frozen = false
	end,

	scored = function(self, player)
		self.p1:scored(player == self.p1)
		self.p2:scored(player == self.p2)
		self.ball:scored()
		if self.p1.score == 3 or self.p2.score == 3 then
			self:addtimer(10, function()
				self.p1.ready = false
				self.p2.ready = false
				self.p1.score = 0
				self.p2.score = 0
				self:reset()
			end)
		else
			self:addtimer(5, function() self:reset() end)
		end
	end,

	thinkSetup = function(self)
		if self.p1.ready and self.p2.ready then
			self:addtimer(1, function() self:start() end)
			self.think = self.thinkAll
		end
		self:thinkAll()
	end,

	thinkAll = function(self)
		self.monitor:blit(Images.Background, scrw*0.5, scrh*0.5)
		self.p1:think()
		self.p2:think()
		self.ball:think()
		if not self.ball.frozen then
			self.ball.phys:doCollision(self.p1.phys)
			self.ball.phys:doCollision(self.p2.phys)
			self.p1.phys:doCollision(self.p2.phys)
		end
	end,

	clicked = function(self, x, y)
		if x<gamew*0.5 then
			self.p1:clicked(x, y*screenToPhysY)
		else
			self.p2:clicked(x, y*screenToPhysY)
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
			if event == "timer" then
				local f = timers[p1]
				if f then timers[p1]=nil f() end
			elseif event == "monitor_touch" then
				self:clicked(p2, p3)
			elseif event == "scored" then
				self:scored(p1)
			end
		end
	end
}

print(xpcall(Pong, debug.traceback))



