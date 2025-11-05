
local class = require("class")
local gfx = require("gfx")
local phys = require("phys")

local dt = 0.1
local screenToPhysY, physToScreenY = 47/21, 21/47
local scrw, scrh = 168, 89
local gamew, gameh = scrw, screenToPhysY*scrh
local Images = {
	Ball = gfx.ImageAnimated("DragonPong/ball", 1),
--	BallOpen = gfx.ImageAnimated("DragonPong/ball_open", 10),
--	BallCrying = gfx.ImageAnimated("DragonPong/ball_crying", 10),
	Dragon = gfx.ImageAnimated("DragonPong/dragon", 1),
--	DragonWin = gfx.ImageAnimated("DragonPong/dragonwin", 4),
--	DragonLose = gfx.ImageAnimated("DragonPong/dragonlose", 4),
	Score = gfx.ImageAnimated("DragonPong/score", 2),
	Background = gfx.Image("DragonPong/background"),
	Cursor = gfx.Image("DragonPong/cursor"),
    ClickReady = gfx.Text("Click screen to ready!", "1", "0"),
    Ready = gfx.Text("Ready!", "1", "0"),
    Winner = gfx.Text("Winner!", "1", "0")
}
Images.BallOpen = Images.Ball
Images.BallCrying = Images.Ball
Images.DragonWin = Images.Dragon
Images.DragonLose = Images.Dragon

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

local pk, vk = 100, math.sqrt(4*100)
local function pd(px, py, vx, vy)
	return pk*px + vk*vx, pk*py + vk*vy
end

Paddle = class {
	init = function(self, p1, p2)
        local radius = 10
		self.phys = phys.PhysCircleComponent(radius, 10, 10)
        boardColliders(self.phys.colliders, radius, p1, p2)
        if p1 then
            self.startx, self.starty = gamew/4, gameh/2
        end
        if p2 then
            self.startx, self.starty = gamew*3/4, gameh/2
        end
		self.tx, self.ty = 0, 0
        self.score = 0
		self.ready = false
		self.dragon = Images.Dragon:new()
        self.dragonWin = Images.DragonWin:new()
        self.dragonLose = Images.DragonLose:new()
	end,
	reset = function(self)
		self.phys:set(self.startx,self.starty,0,0,0,0)
		self.flipped = self==game.p2
		self.frozen = true
        self.sprite = self.dragon
        self.dragon.t = 0
        self.dragonWin.t = 0
        self.dragonLose.t = 0
	end,
	score = function(self, scored)
        self.frozen = true
		if scored then
            self.sprite = self.dragonWin
			self.score = self.score + 1
        else
            self.sprite = self.dragonLose
        end
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

		self.sprite:add(flapspeed)
		if state[4] < -0.5 then
			self.flipped = true
		elseif state[4] > 0.5 then
			self.flipped = false
		end

		game.monitor:blit(Images.Cursor, self.tx, self.ty*physToScreenY)
		game.monitor:blit(self.sprite, state[1], state[2]*physToScreenY, self.flipped)

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
		self.egg = Images.Ball:new(1)
        self.egg_opening = Images.BallOpen:new(3, false)
        self.egg_crying = Images.BallCrying:new(1)
	end,
	reset = function(self)
		self.phys:set(gamew/2,gameh/2,0,0,0,0)
		self.frozen = true
		self.sprite = self.egg
	end,
	score = function(self)
		self.frozen = true
		self.sprite = self.egg_opening
        self.sprite.t = 0
		game:addtimer(self.sprite.tlen, function()
			self.sprite = self.egg_crying
            self.sprite.t = 0
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
		else
			self.sprite:add(dt)
		end

		game.monitor:blit(self.sprite, state[1], state[2]*physToScreenY)
	end,
}

Pong = class {
	init = function(self)
		game = self
		self.timers = {}
		self.monitor = gfx.Monitor("top", 0, 0, 168, 81, 0.5)
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

	score = function(self, player)
		self.p1:score(player == self.p1)
		self.p2:score(player == self.p2)
		self.ball:score()
		self:addtimer(5, function() self:reset() end)
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
                self:score(p1)
			end
		end
	end
}

Pong()
