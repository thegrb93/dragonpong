
local class = require("class")

local function lineLineIntersect(x1, y1, dx1, dy1, x2, y2, dx2, dy2)
    local denom = dx1*dy2 - dy1*dx2
    if denom<=0 then return 1 end
    local u = ((x3 - x1)*dy1 - (y3 - y1)*dx1)/denom
    if u > 1 or u < 0 then return 1 end
    return ((x3 - x1)*dy2 - (y3 - y1)*dx2)/denom
end

local function lineCircleIntersect(x, y, dx, dy, xc, yc, r)
    local a = dx^2 + dy^2
    local b = 2*(dx*(x - xc) + dy*(y - yc))
    local c = xc^2 + yc^2 + x^2 + y^2 - 2*(xc*x + yc*y) - r^2
    local discrim = b^2 - 4*a*c
    if discrim<=0 then return 1 end
    discrim = math.sqrt(discrim)
    local t = (-b - discrim) / (2*a)
    if t<0 and ((xc - x)^2 + (yc - y)^2)>r^2 then return 1 end
    return t
end

local function reflect(dx, dy, nx, ny)
    local dot = dx*nx + dy*ny
    if dot>=0 then return end
    return dx-2*dot*nx, dy-2*dot*ny
end

local WallCollider = class {
    init = function(self, x1, y1, x2, y2)
        self.x = x1
        self.y = y1
        self.dx = x2-x1
        self.dy = y2-y1
        local mag = math.sqrt(self.dx^2 + self.dy^2)
        self.tx = self.dx/mag
        self.ty = self.dy/mag
        self.nx = -self.ty
        self.ny = self.tx
    end,
    checkCollision = function(self, state, dirx, diry)
        return lineLineIntersect(state[1], state[2], dirx, diry, self.x, self.y, self.dx, self.dy)
    end,
    doCollision = function(self, state, dirx, diry, t)
        state[1] = state[1] + dirx*t
        state[2] = state[2] + diry*t

        local newscale = (1 - t)
        dirx, diry = newscale*dirx, newscale*diry
        dirx, diry = reflect(dirx, diry, self.nx, self.ny)
        state[4], state[5] = reflect(state[4], state[5], self.nx, self.ny)
        return dirx, diry
    end
}

local CircleCollider = class {
    init = function(self, x, y, r)
        self.x = x
        self.y = y
        self.r = r
    end,
    checkCollision = function(self, state, dirx, diry)
        return lineCircleIntersect(state[1], state[2], dirx, diry, self.x, self.y, self.r)
    end,
    doCollision = function(self, state, dirx, diry, t)
        state[1] = state[1] + dirx*t
        state[2] = state[2] + diry*t
        
        local newscale = (1 - t)
        dirx = newscale*dirx
        diry = newscale*diry

        local nx = (state[1] - self.x)/self.r
        local ny = (state[2] - self.y)/self.r

        dirx, diry = reflect(dirx, diry, nx, ny)
        state[4], state[5] = reflect(state[4], state[5], nx, ny)
        return dirx, diry
    end
}


local GoalCollider = class {
    init = WallCollider.init,
    checkCollision = WallCollider.checkCollision,
    doCollision = function(self, state, dirx, diry, t)
        state[1] = state[1] + dirx*t
        state[2] = state[2] + diry*t
        os.pushEvent("scored")
        return 0, 0
    end
}

return {
    WallCollider = WallCollider,
    CircleCollider = CircleCollider,
    GoalCollider = GoalCollider
}

local colliders = {
    phys.WallCollider(-30, 4, 200, 4),
    phys.WallCollider(200, 77, -30, 77),
    phys.WallCollider(4, 23, 4, -30),
    phys.WallCollider(4, 110, 4, 58),
    phys.WallCollider(160, -30, 160, 23),
    phys.WallCollider(160, 58, 160, 110),
    phys.GoalCollider(0, 54, 0, 27),
    phys.GoalCollider(168, 27, 168, 54),
    phys.CircleCollider(0, 23, 4),
    phys.CircleCollider(0, 58, 4),
    phys.CircleCollider(164, 23, 4),
    phys.CircleCollider(164, 58, 4),
}

local state = self.state
for i=1, 10 do
    if math.abs(dirx)<1e-8 and math.abs(diry)<1e-8 then
        dirx, diry = 0, 0
        break
    end

    local tmin = 1
    local collider
    for _, v in ipairs(colliders) do
        local t = v:checkCollision(state, dirx, diry)
        if t and t<tmin then tmin=t collider=v end
    end
    if not collider then break end
    dirx, diry = collider:doCollision(state, dirx, diry, tmin)
end
state[1], state[2] = state[1] + dirx, state[2] + diry
