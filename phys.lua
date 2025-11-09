
local class = require("class")

local function lineLineIntersect(x1, y1, dx1, dy1, x2, y2, dx2, dy2)
    local denom = dx1*dy2 - dy1*dx2
    if denom<=0 then return 1 end
    local u = ((x2 - x1)*dy1 - (y2 - y1)*dx1)/denom
    if u > 1 or u < 0 then return 1 end
    return ((x2 - x1)*dy2 - (y2 - y1)*dx2)/denom
end

local function lineCircleIntersect(x, y, dx, dy, xc, yc, r)
    local a = dx^2 + dy^2
    local b = 2*(dx*(x - xc) + dy*(y - yc))
    local c = xc^2 + yc^2 + x^2 + y^2 - 2*(xc*x + yc*y) - r^2
    local discrim = b^2 - 4*a*c
    if discrim<=0 then return 1 end
    discrim = math.sqrt(discrim)
    local t = (-b - discrim) / (2*a)
    if t<0 then return 1 end
    return t
end

local function reflect(dx, dy, nx, ny)
    local dot = dx*nx + dy*ny
    if dot>=0 then return end
    return dx-2*dot*nx, dy-2*dot*ny
end

local function reflectMomentum(vx, vy, dotnormx, dotnormy, I)
    return vx + 2*I*dotnormx, vy + 2*I*dotnormy
end

local function reflectMomentumAngular(vx, vy, va, tx, ty, circumference, linearInertia, angularInertia)
    local IT = linearInertia + angularInertia
    local tx, ty = -nx, ny
    va = va*circumference
    local avx, avy = va*tx, va*ty
    local tandot = vx*tx + vy*ty
    local vtandotx, vtandoty = tandot*tx + avx, tandot*ty + avy

    vx, vy = reflectMomentum(vx, vy, vtandotx, vtandoty, angularInertia/IT)
    avx, avy = reflectMomentum(avx, avy, -vtandotx, -vtandoty, linearInertia/IT)
    va = (avx*tx + avy*ty)/circumference
    return vx, vy, va
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
    doCollision = function(self, body, state, dirx, diry, t)
        state[1] = state[1] + dirx*t
        state[2] = state[2] + diry*t

        local newscale = (1 - t)
        dirx, diry = newscale*dirx, newscale*diry
        dirx, diry = reflect(dirx, diry, self.nx, self.ny)
        state[4], state[5] = reflect(state[4], state[5], self.nx, self.ny)

        if body.rotating then
            state[4], state[5], state[6] = reflectMomentumAngular(state[4], state[5], state[6], -self.ny, self.nx, 2*math.pi*body.radius, body.linearInertia, body.angularInertia)
        end
    
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
    doCollision = function(self, body, state, dirx, diry, t)
        state[1] = state[1] + dirx*t
        state[2] = state[2] + diry*t
        
        local newscale = (1 - t)
        dirx = newscale*dirx
        diry = newscale*diry

        local nx = (state[1] - self.x)/self.r
        local ny = (state[2] - self.y)/self.r

        dirx, diry = reflect(dirx, diry, nx, ny)
        state[4], state[5] = reflect(state[4], state[5], nx, ny)
        
        if body.rotating then
            state[4], state[5], state[6] = reflectMomentumAngular(state[4], state[5], state[6], -ny, nx, 2*math.pi*body.radius, body.linearInertia, body.angularInertia)
        end

        return dirx, diry
    end
}


local GoalCollider = class {
    init = WallCollider.init,
    checkCollision = WallCollider.checkCollision,
    doCollision = function(self, body, state, dirx, diry, t)
        state[1] = state[1] + dirx*t
        state[2] = state[2] + diry*t
        os.queueEvent("scored")
        return 0, 0
    end
}

local PhysCircleComponent = class {
    init = function(self, parent, rotating, radius, linear, angular)
        self.parent = parent
        self.rotating = rotating
        self.radius = radius
		self.state = {0, 0, 0, 0, 0, 0}
        self.linearInertia = linear
        self.angularInertia = angular
        self.colliders = {}
    end,
    set = function(self, x, y, a, dx, dy, da)
        local state = self.state
        state[1], state[2], state[3], state[4], state[5], state[6] = x, y, a, dx, dy, da
    end,
    step = function(self, fx, fy, fa, dt)
        local state, colliders = self.state, self.colliders

        state[4], state[5], state[6] = state[4]+fx*dt, state[5]+fy*dt, state[6]+fa*dt
    
        local dirx, diry = state[4]*dt, state[5]*dt
        local i = 1
        while true do
            if i==10 or (math.abs(dirx)<1e-8 and math.abs(diry)<1e-8) then
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
            dirx, diry = collider:doCollision(self, state, dirx, diry, tmin)
            i = i + 1
        end
        state[1], state[2], state[3] = state[1] + dirx, state[2] + diry, (state[3]+state[6]*dt)%1
    end,
    doCollision = function(self, other)
        local x1, x2 = self.state, other.state
        local dx, dy = x2[1] - x1[1], x2[2] - x1[2]
		local distSqr = dx^2+dy^2
		if distSqr<(self.radius + other.radius)^2 then
            local dvx, dvy = x2[4] - x1[4], x2[5] - x1[5]
			local normdot = dvx*dx + dvy*dy
			if normdot<0 then
				local vnormx, vnormy = normdot*dx/distSqr, normdot*dy/distSqr

                -- First do the normal component reflection
                local IT = self.linearInertia + other.linearInertia
				x1[4], x1[5] = reflectMomentum(x1[4], x1[5], vnormx, vnormy, other.linearInertia/IT)
				x2[4], x2[5] = reflectMomentum(x2[4], x2[5], -vnormx, -vnormy, self.linearInertia/IT)
                
                if self.rotating or other.rotating then
                    local dist = math.sqrt(distSqr)
                    local circum = 2*math.pi*self.radius
                    local I1, I2, I3, I4
                    local IT1 = self.angularInertia + self.linearInertia + other.linearInertia
                    if self.rotating then
                        I1 = (self.angularInertia + self.linearInertia)/IT1
                        I2 = other.linearInertia/IT1
                        local IT2 = self.angularInertia + self.linearInertia
                        I3 = self.linearInertia/IT2
                        I4 = self.angularInertia/IT2
                    else
                        x1, x2 = x2, x1
                        dx, dy = -dx, -dy
                        dvx, dvy = -dvx, -dvy
                        I1 = (other.angularInertia + other.linearInertia)/IT1
                        I2 = self.linearInertia/IT1
                        local IT2 = other.angularInertia + other.linearInertia
                        I3 = other.linearInertia/IT2
                        I4 = other.angularInertia/IT2
                    end
                    local tx, ty = -dy/dist, dx/dist
                    local angVel = x1[6]*circum
                    local angVelx, angVely = angVel*tx, angVel*ty
                    local tandot = dvx*tx + dvy*ty
                    local vtandotx, vtandoty = tandot*tx + angVelx, tandot*ty + angVely
                    local vx2, vy2 = reflectMomentum(x1[4]+angVelx, x1[5]+angVely, vtandotx, vtandoty, I2)
                    x2[4], x2[5] = reflectMomentum(x2[4], x2[5], -vtandotx, -vtandoty, I1)

                    x1[4], x1[5] = reflectMomentum(x1[4], x1[5], vx2, vy2, I4)
                    angVelx, angVely = reflectMomentum(angVelx, angVely, -vx2, -vy2, I3)
                    x1[6] = (angVelx*tx + angVely*ty)/circum
                end
			end
		end
    end
}

return {
    WallCollider = WallCollider,
    CircleCollider = CircleCollider,
    GoalCollider = GoalCollider,
    PhysCircleComponent = PhysCircleComponent
}
