local calculate = require 'calculate'

local celestials = {}

celestials = {
    ASTROID_MIN_ALLOWED = 0,
    ASTROID_MAX_RAD = 90,
    ASTROID_MIN_SIDES = 5,
    ASTROID_MAX_SIDES = 10,
    ASTROID_MAX_VEL = 100,
    ASTROID_DEFAULT_AMT = 3,

    planet = function (x, y, color, radius, astroBodies, massConstant)
        local astroBodiesRef = astroBodies
        local MASS_CONSTANT = massConstant or 5
        
        return {
            x = x,
            y = y,
            planet = true,
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
                    if body ~= self and not body.tooFarAway then
                        local thrust1, thrust2 = calculate.twoBodyThrust(self, body)

                        self.thrust.x, self.thrust.y = thrust1.x, thrust1.y
                        body.thrust.x, body.thrust.y = thrust2.x, thrust2.y

                        self.x = self.x + self.thrust.x * DT
                        self.y = self.y + self.thrust.y * DT
                        
                        body.x = body.x + body.thrust.x * DT
                        body.y = body.y + body.thrust.y * DT
                    end
                end
            end,

            update = function (self)
                if not self.tooFarAway then
                    self:applyPhysics()
                    self.mass = self.radius * MASS_CONSTANT
                end
                
                self.x = self.x + WorldDirection.x
                self.y = self.y + WorldDirection.y
            end
        }
    end,

    ---@param x number
    ---@param y number
    ---@param color table
    ---@param radius number
    ---@param noOfSides integer
    ---@param minOffset number
    ---@param maxOffset number
    ---@param velRange number
    ---@param astroidAmt integer
    ---@param world table
    ---@param angle? number
    ---@return table
    astroid = function (x, y, color, radius, noOfSides, minOffset, maxOffset, velRange, astroidAmt, world, angle)
        local VELOCITY = math.random(velRange)
        local MASS_CONSTANT = 0.000000000000000005

        local myWorld = world
        local polygonPoints = {}
        local pointsOffsets = {}
        if noOfSides < 3 then
            error(noOfSides.." sides is an inappropriate amount of sides")
        end
        for _ = 1, noOfSides, 1 do
            table.insert(pointsOffsets, math.random(minOffset, maxOffset))
            table.insert(pointsOffsets, math.random(minOffset, maxOffset))
        end
        local theAngle = angle or math.random(0, 360)

        return {
            docked = true,
            x = x,
            y = y,
            color = {r = color.r or color[1], g = color.g or color[2], b = color.b or color[3]},
            world = myWorld,
            angle = theAngle,
            mass = radius * MASS_CONSTANT,
            astroidAmt = astroidAmt,
            destroyed = false,
            thrust = {x=math.cos(math.rad(theAngle + 90)) * VELOCITY, y=-math.sin(math.rad(theAngle + 90)) * VELOCITY},
            radius = radius,

            destroy = function (self)
                self.destroyed = true

                local astroidsIndex = ListIndex(self.world.astroids, self)
                local charactersIndex = ListIndex(self.world.collisionBodies, self)

                if astroidsIndex < 0 or charactersIndex < 0 then
                    error('This astroid is somehow not in the list you messed up. Character index is '..charactersIndex..'. celestials.astroid index is '..astroidsIndex)
                end

                if self.radius > 2 then

                    for i = 1, self.astroidAmt do
                        local newRadius = self.radius / self.astroidAmt
                        local newAngle = (self.angle + (i / self.astroidAmt) * 360) % 360
                        
                        local astx = self.x + math.cos(math.rad(newAngle + 90)) * (newRadius * 2)
                        local asty = self.y - math.sin(math.rad(newAngle + 90)) * (newRadius * 2)
                        
                        local astroid = celestials.astroid(astx,
                                                           asty,
                                                           self.color,
                                                           newRadius,
                                                           math.random(celestials.ASTROID_MIN_SIDES, celestials.ASTROID_MAX_SIDES),
                                                           -tonumber(newRadius / 5),
                                                           tonumber(newRadius / 5) or newRadius / 5,
                                                           celestials.ASTROID_MAX_VEL / 2,
                                                           self.astroidAmt,
                                                           self.world,
                                                           newAngle
                                                        )
                        
                        table.insert(self.world.astroids, astroid)
                        table.insert(self.world.collisionBodies, astroid)
                    end
                end
                
                table.remove(self.world.collisionBodies, charactersIndex)
                table.remove(self.world.astroids, astroidsIndex)
            end,
            
            draw = function (self)
                love.graphics.setLineWidth(3)
                
                if #polygonPoints ~= 0 then
                    love.graphics.setColor(color.r, color.g, color.b)
                    love.graphics.polygon('fill', polygonPoints)
                end
                if DEBUGGING then
                    love.graphics.setLineWidth(0.1)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.circle('line', self.x, self.y, self.radius)
                end
            end,

            update = function (self)
                self.x = self.x + WorldDirection.x
                self.y = self.y +WorldDirection.y
                
                if not self.tooFarAway then
                    self.x = self.x + self.thrust.x * DT
                    self.y = self.y + self.thrust.y * DT
                    self.mass = self.radius * MASS_CONSTANT 
                end

                local indexIncrement = 0
                for i = 1, noOfSides, 1 do
                    local ang = (i / noOfSides) * 360

                    polygonPoints[i + indexIncrement] = self.x + (math.cos(math.rad(ang)) * (radius + pointsOffsets[i + indexIncrement]))
                    polygonPoints[i + indexIncrement + 1] = self.y - (math.sin(math.rad(ang)) * (radius + pointsOffsets[i + indexIncrement + 1]))
                    indexIncrement = indexIncrement + 1
                end
            end,

        }
    end
}

return celestials
