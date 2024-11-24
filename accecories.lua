local calculate = require 'calculate'

local accecories = {}

accecories = {
    bullet = function (x, y, angle, radius, vel)
        return {
            x = x,
            y = y,
            angle = angle + 90,
            radius = radius,
            thrust = {x=0, y=0},
            vel = vel,

            dist = 0,

            update = function (self)
                self.thrust.x = math.cos(math.rad(self.angle)) * self.vel
                self.thrust.y = -math.sin(math.rad(self.angle)) * self.vel
                
                self.x = WorldDirection.x + self.x + self.thrust.x
                self.y = WorldDirection.y + self.y + self.thrust.y
                
                self.dist = self.dist + calculate.distance(self.thrust.x, self.thrust.y, 2 * self.thrust.x, 2 * self.thrust.y)
            end,
            
            draw = function (self)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('fill', self.x, self.y, self.radius)
            end,

            getDist = function (self)
                return self.dist
            end
            
            
        }
    end
}

return accecories