
local function Planet(x, y, color, radius, astroBodies, massConstant)
    local astroBodiesRef = astroBodies
    local MASS_CONSTANT = massConstant or 0.00000000000000000000000000000000001
    
    return {
        x = x,
        y = y,
        radius = radius,
        mass = radius * MASS_CONSTANT,
        astroBodies = astroBodiesRef,
        thrust = {x = 0, y = 0},
        color = {r = color.r or color[1], g = color.g or color[2], b = color.b or color[3]},
        
        draw = function (self)
            love.graphics.setColor(self.color.r, self.color.g, self.color.b)
            love.graphics.circle('fill', self.x, self.y, self.radius)
        end,

        applyPhysics = function (self)
            for _, body in ipairs(self.astroBodies) do
                if CalculateDistance(self.x, self.y, body.x, body.y) <= self.radius^2 and body ~= self then
                    self.thrust.x, self.thrust.y, body.thrust.x, body.thrust.y = CalculateTwoBodyThrust(self, body)
                    
                    self.x = self.x + self.thrust.x * DT
                    self.y = self.y + self.thrust.y * DT
                    
                    if body.docked ~= nil then
                        body.x = body.x + body.thrust.x * DT
                        body.y = body.y + body.thrust.y * DT
                    else
                        if not body.docked then
                            body.x = body.x + body.thrust.x * DT
                            body.y = body.y + body.thrust.y * DT
                        end
                    end
                end
            end
        end,

        update = function (self)
            self:applyPhysics()
            self.x = self.x + worldDirection.x
            self.y = self.y + worldDirection.y
            self.mass = self.radius * MASS_CONSTANT
        end


    }
end

return Planet