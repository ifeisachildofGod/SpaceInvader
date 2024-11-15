
---comment
---@param x number
---@param y number
---@param radius number
---@param noOfSides integer
---@param minOffset number
---@param maxOffset number
---@param velRange number
---@param astroidAmt integer
---@param world table
---@param angle? number
---@return table
local function Astroid(x, y, radius, noOfSides, minOffset, maxOffset, velRange, astroidAmt, world, angle)
    local VELOCITY = 0
    while true do
        VELOCITY = math.random(-velRange, velRange)
        if VELOCITY ~= 0 then
            break
        end
    end

    local myWorld = world
    local polygonPoints = {}
    local pointsOffsets = {}
    for _ = 1, noOfSides, 1 do
        table.insert(pointsOffsets, math.random(minOffset, maxOffset))
        table.insert(pointsOffsets, math.random(minOffset, maxOffset))
    end

    return {
        x = x,
        y = y,
        world = myWorld,
        angle = angle or math.random(0, 360),
        astroidAmt = astroidAmt,
        destroyed = false,
        thrust = {x=0, y=0},
        radius = radius,

        explode = function (self)
            self.destroyed = true
            
            local index
            for i, ast in ipairs(self.world.asteroidTbl) do
                if ast == self then
                    index = i
                    break
                end
            end
            if index == nil then
                error('Astroid is somehow not in the list you messed up')
            end

            if self.astroidAmt ~= 1 then
                for i = 1, self.astroidAmt, 1 do
                    local newAstroidAmt = self.astroidAmt - 1
                    local newRadius = (self.radius / newAstroidAmt) / 2
                    local newAngle = self.angle + (i / self.astroidAmt) * 360

                    local astx = self.x + math.cos(math.rad(self.angle)) * ((newRadius * (i - 1)) - (newRadius * newAstroidAmt) / 2)
                    local asty = self.y - math.sin(math.rad(self.angle)) * ((newRadius * (i - 1)) - (newRadius * newAstroidAmt) / 2)
                    
                    table.insert(self.world.asteroidTbl,
                                Astroid(astx,
                                        asty,
                                        newRadius,
                                        math.random(ASTROID_MIN_SIDES, ASTROID_MAX_SIDES),
                                        -tonumber(newRadius / 5),
                                        tonumber(newRadius / 5) or newRadius / 5,
                                        ASTROID_MAX_VEL / 2,
                                        newAstroidAmt,
                                        self.world,
                                        newAngle))
                    
                end
            end

            for i, ast in ipairs(self.world.characters) do
                if ast == self then
                    table.remove(self.world.characters, i)
                end
            end

            table.remove(self.world.asteroidTbl, index)
        end,
        
        draw = function (self)
            love.graphics.setLineWidth(3)
            love.graphics.setColor(1, 0.4279180, 0.318790192837445)
            
            if #polygonPoints ~= 0 then
                love.graphics.polygon('line', polygonPoints)
            end
            if DEBUGGING then
                love.graphics.setLineWidth(0.1)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('line', self.x, self.y, self.radius)
            end
        end,

        update = function (self)
            self.thrust.x = math.cos(math.rad(self.angle + 90))
            self.thrust.y = -math.sin(math.rad(self.angle + 90))

            self.x = worldDirection.x + self.x + (self.thrust.x * VELOCITY)
            self.y = worldDirection.y + self.y + (self.thrust.y * VELOCITY)
            
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
