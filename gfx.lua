local class = require("class")

local function round(x) 
	if x >= 0 then return math.floor(x+0.5) 
	else return math.ceil(x-0.5) end
end

local Blit = class {
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
}

local Image = class {
	init = function(self, filename)
		self.w = 0
		self.h = 0
		self.blits = {}

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
	end,

	blit = function(self, periph, x, y, flipped)
		x = round(x) y = round(y)

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
}

local ImageAnimatedObj = class {
	init = function(self, imageanimated, animlength, looped)
		self.frames = imageanimated.frames
		self.t = 0
		self.looped = looped or looped==nil
	end,
	add = function(self, dt)
		if self.looped then
			self.t = (self.t + dt/animlength) % 1
		else
			self.t = math.min(self.t + dt/animlength, 0.999999999999)
		end
	end,
	blit = function(self, periph, x, y, flipped)
		local image = self.frames[math.floor(self.t*#self.frames)+1]
		image:blit(periph, x, y, flipped)
	end,
}

local ImageAnimated = class {
	init = function(self, filename, frames)
		self.frames = {}
		for i=1, frames do
			self.frames[i] = Image(filename..tostring(i))
		end
	end,
	new = function(self, animlength, looped)
		return ImageAnimatedObj(self, animlength, looped)
	end
}

local Monitor = class {
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
