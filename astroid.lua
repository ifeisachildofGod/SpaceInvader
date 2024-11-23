
---comment
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
local function Astroid(x, y, color, radius, noOfSides, minOffset, maxOffset, velRange, astroidAmt, world, angle)
    local VELOCITY = math.random(velRange)
    local MASS_CONSTANT = 0.05

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

        explode = function (self)
            self.destroyed = true

            local astroidsIndex = ListIndex(self.world.asteroidTbl, self)
            local charactersIndex = ListIndex(self.world.characters, self)

            if astroidsIndex < 0 or charactersIndex < 0 then
                error('This astroid is somehow not in the list you messed up. Character index is '..charactersIndex..'. Astroid index is '..astroidsIndex)
            end

            if self.radius > 2 then

                for i = 1, self.astroidAmt do
                    local newRadius = self.radius / self.astroidAmt
                    local newAngle = (self.angle + (i / self.astroidAmt) * 360) % 360
                    
                    local astx = self.x + math.cos(math.rad(newAngle + 90)) * (newRadius * 2)
                    local asty = self.y - math.sin(math.rad(newAngle + 90)) * (newRadius * 2)
                    
                    local astroid = Astroid(astx,
                                            asty,
                                            self.color,
                                            newRadius,
                                            math.random(ASTROID_MIN_SIDES, ASTROID_MAX_SIDES),
                                            -tonumber(newRadius / 5),
                                            tonumber(newRadius / 5) or newRadius / 5,
                                            ASTROID_MAX_VEL / 2,
                                            self.astroidAmt,
                                            self.world,
                                            newAngle)
                    
                    table.insert(self.world.asteroidTbl, astroid)
                    table.insert(self.world.characters, astroid)
                end
            end
            
            table.remove(self.world.characters, charactersIndex)
            table.remove(self.world.asteroidTbl, astroidsIndex)
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
            self.x = worldDirection.x + self.x + self.thrust.x * DT
            self.y = worldDirection.y + self.y + self.thrust.y * DT
            self.mass = self.radius * MASS_CONSTANT

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


return Astroid
