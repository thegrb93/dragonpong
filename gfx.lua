local class = require("class")

local function round(x) 
	if x >= 0 then return math.floor(x+0.5) 
	else return math.ceil(x-0.5) end
end

local Blit, Image, ImageAnimated, Monitor

Blit = class {
	init = function(self, txt, fg, bg)
        local max = math.max(#txt, #fg, #bg)
        if #txt==1 then txt=string.rep(txt, max) end
        if #fg==1 then fg=string.rep(fg, max) end
        if #bg==1 then bg=string.rep(bg, max) end
        if #txt ~= #fg or #txt ~= #bg then error("Blit lengths not the same!") end
        self.w = max
        self.txt, self.txtrev = txt, string.reverse(txt)
        self.fg, self.fgrev = fg, string.reverse(fg)
        self.bg, self.bgrev = bg, string.reverse(bg)
	end,
	blit = function(self, periph, x, y, flipped)
		x = round(x) y = round(y)
		periph.setCursorPos(x+1, y+1)
		if flipped then
			periph.blit(self.txtrev, self.fgrev, self.bgrev)
		else
			periph.blit(self.txt, self.fg, self.bg)
		end
	end,
    swapPallete = function(self, from, to)
        return Blit(self.txt, self.fg, string.gsub(self.bg, from, to))
    end
}

Image = class {
	init = function(self, filename)
		self.w = 0
		self.h = 0
		self.blits = {}
        if filename then
            self:load(filename)
        end
	end,
    load = function(self, filename)
		local f = assert(io.open(filename..".txt", "r"))
		for line in f:lines() do
			if self.w==0 then self.w=#line end
			if self.w~=#line then error("Image dimension inconsistent!") end
			for pos, blit in string.gmatch(string.lower(line), "()[0-9a-f]+") do
				self.blits[#self.blits + 1] = {x = pos-1, y=self.h, blit=Blit(" ","0",blit)}
			end
			self.h = self.h + 1
		end
		f:close()
        self.ox, self.oy = self.w*-0.5, self.h*-0.5
    end,
	blit = function(self, periph, x, y, flipped)
		x = round(x+self.ox) y = round(y+self.oy)

		if flipped then
			for _, v in ipairs(self.blits) do
				v:blit(periph, self.w-v.w-v.x, y+v.y, flipped)
			end
		else
			for _, v in ipairs(self.blits) do
				v:blit(periph, x+v.x, y+v.y, flipped)
			end
		end
	end,
    swapPallete = function(self, from, to)
        local ret = Image()
        ret.w, ret.h, ret.ox, ret.oy = self.w, self.h, self.ox, self.oy
        for i, v in ipairs(self.blits) do
            ret.blits[i] = v:swapPallete(from, to)
        end
        return ret
    end
}

local FrameCounterAdvance = class {
	init = function(self, imageanimated, framecounts, looped)
		self.frames = imageanimated.frames
        self.framecounts = framecounts
        if #self.frames ~= #self.framecounts then
            error("Expected frames and framecounts size to be equal!")
        end
        self.framei = 1
		self.counter = 0
		self.looped = looped~=false
	end,
	add = function(self, dt)
		self.counter = self.counter + dt
        while self.counter >= self.framecounts[self.framei] do
            self.counter = self.counter - self.framecounts[self.framei]
            if self.framei==#self.frames then
                if self.looped then
                    self.framei = 1
                end
            else
                self.framei = self.framei + 1
            end
        end
	end,
	blit = function(self, periph, x, y, flipped)
		self.frames[self.framei]:blit(periph, x, y, flipped)
	end
}
local RateAdvance = class {
	init = function(self, imageanimated, animtime, looped)
		self.frames = imageanimated.frames
        self.animtime = animtime
		self.t = 0
		self.looped = looped~=false
	end,
	add = function(self, dt)
		if self.looped then
			self.t = (self.t + dt/self.animtime) % 1
		else
			self.t = math.min(self.t + dt/self.animtime, 0.999999999999)
		end
	end,
	blit = function(self, periph, x, y, flipped)
		self.frames[math.floor(self.t*#self.frames)+1]:blit(periph, x, y, flipped)
	end
}

ImageAnimated = class {
	init = function(self, filename, frames)
		self.frames = {}
        if filename then
            for i=1, frames do
                self.frames[i] = Image(filename..tostring(i))
            end
        end
	end,
	new = function(self, type, ...)
        if type=="frame" then
		    return FrameCounterAdvance(self, ...)
        elseif type=="rate" then
            return RateAdvance(self, ...)
        else
            error("Invalid Type!")
        end
	end,
    swapPallete = function(self, from, to)
        local ret = ImageAnimated()
        for i, v in ipairs(self.frames) do
            ret.frames[i] = v:swapPallete(from, to)
        end
        return ret
    end
}

Monitor = class {
	init = function(self, address, x, y, w, h)
		self.periph = peripheral.wrap(address)
		self.x = x
		self.y = y
		self.w = w
		self.h = h
		self.periph.setTextScale(0.5)
		self.periph.clear()
	end,

	draw = function(self, drawable, x, y, flipped)
		drawable:blit(self.periph, x, y, flipped)
	end,
}

return {Monitor = Monitor, Image = Image, ImageAnimated = ImageAnimated, Blit = Blit}

