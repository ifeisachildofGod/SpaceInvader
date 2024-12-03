local calculate = require 'calculate'

local accecories = {}

accecories = {
    bullet = function (x, y, angle, radius, vel)
        return {
            x = x,
            y = y,
            angle = angle + 90,
            radius = radius,
            thrust = {x=math.cos(math.rad(angle+90)) * vel, y=-math.sin(math.rad(angle+90)) * vel},
            vel = vel,

            dist = 0,

            update = function (self)
                self.x = WorldDirection.x + self.x + self.thrust.x
                self.y = WorldDirection.y + self.y + self.thrust.y
                
                self.dist = self.dist + calculate.distance(self.thrust.x, self.thrust.y)
            end,
            
            draw = function (self)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('fill', self.x, self.y, self.radius)
            end
        }
    end
}

return accecories