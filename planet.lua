
local function Planet(x, y, color, radius, astroBodies)
    local astroBodiesRef = astroBodies
    return {
        x = x,
        y = y,
        radius = radius,
        astroBodies = astroBodiesRef,
        thrust = {x = 0, y = 0},
        color = {r = color.r or color[1], g = color.g or color[2], b = color.b or color[3]},
        
        draw = function (self)
            love.graphics.setColor(self.color.r, self.color.g, self.color.b)
            love.graphics.circle('fill', self.x, self.y, self.radius)
        end,

        applyPhysics = function (self)
            local dt = love.timer.getDelta()

            for _, body in ipairs(self.astroBodies) do
                if CalculateDistance(self.x, self.y, body.x, body.y) <= self.radius^3 and body ~= self then
                    local bodyFx, bodyFy =  CalculateTwoBodyVextor(self, body)
                    local myFx, myFy =  CalculateTwoBodyVextor(body, self)
                    
                    self.thrust.x = self.thrust.x + myFx
                    self.thrust.y = self.thrust.y + myFy
    
                    self.x = self.x + self.thrust.x * dt
                    self.y = self.y + self.thrust.y * dt
                    
                    body.thrust.x = body.thrust.x + bodyFx
                    body.thrust.y = body.thrust.y + bodyFy

                    body.x = body.x + body.thrust.x * dt
                    body.y = body.y + body.thrust.y * dt
                end
            end
        end,

        update = function (self)
            self.x = self.x + worldDirection.x
            self.y = self.y + worldDirection.y
            self:applyPhysics()
        end


    }
end

return Planet