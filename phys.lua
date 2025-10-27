
local class = require("class")

local WallCollider = class {
    init = function(self, x1, y1, x2, y2)
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.dx = x2-x1
        self.dy = y2-y1
    end,
    checkCollision = function(self, x1, y1, x2, y2)
    end,
    doCollision = function(self, x1, y1, x2, y2, t)
    end
}

local CircleCollider = class {
    init = function(self, x, y, r)
        self.x = x
        self.y = y
        self.r = r
    end,
    checkCollision = function(self, x1, y1, x2, y2)
    end,
    doCollision = function(self, x1, y1, x2, y2, t)
    end
}

local PaddleCollider = class {
    init = function(self, paddle, r)
        self.state = paddle.state
    end,
    checkCollision = function(self, x1, y1, x2, y2)
    end,
    doCollision = function(self, x1, y1, x2, y2, t)
    end
}

return {
    WallCollider = WallCollider,
    CircleCollider = CircleCollider,
    PaddleCollider = PaddleCollider,
}
