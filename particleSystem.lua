

local particleSystem = function (images)
    local CurrTime = 0
    local PrevTime = 0
    return {
        particles = {},
        
        x = nil,
        y = nil,
        images = images,
        gravity = 0,
        rotSpeed = 0,
        collisionBodies = {},
        scalingVariation = {min=0.5, max=1},
        particleSpeedRange = {min=12, max=20},
        durationRange = {min=1, max=3},
        particleOriginMaxOffset = 1,
        dirAngleOffsetRange = nil,
        userUpdateCallback = nil,
        userDrawBeforeCallback = nil,
        userDrawAfterCallback = nil,

        draw = function (self)
            for _, particle in ipairs(self.particles) do
                self:drawParticle(particle)
            end
        end,
        
        update = function (self)
            for particleIndex, particle in ipairs(self.particles) do
                self.updateParticle(particle)
                for _, body in ipairs(self.collisionBodies) do
                    if CalculateDistance(body.x, body.y, particle.x, particle.y) <= body.radius then
                        table.remove(self.particles, particleIndex)
                    end
                end
                if particle.t >= particle.duration then
                    table.remove(self.particles, particleIndex)
                end
            end
        end,

        add = function (self)
            if self.x == nil or self.y == nil then
                error("X and Y have not been set to values, Use the setPositon function to set X and Y values")
            end

            local angle
            if self.dirAngleOffsetRange == nil then
                angle = self.randomNumber(0, 360)
            else
                angle = math.rad(self.dirAngleOffsetRange.min + self.randomNumber(0, self.dirAngleOffsetRange.max - self.dirAngleOffsetRange.min) - 90)
            end
            
            local offsetAngle = math.rad(self.randomNumber(0, 360))
            local speed = self.randomNumber(self.particleSpeedRange.min, self.particleSpeedRange.max)

            local xOffset = math.cos(offsetAngle) * self.randomNumber(self.particleOriginMaxOffset)
            local yOffset = -math.sin(offsetAngle) * self.randomNumber(self.particleOriginMaxOffset)

            local x_dir = math.cos(angle) * speed
            local y_dir = -math.sin(angle) * speed

            local x = self.x + xOffset
            local y = self.y + yOffset
            
            local imageData = self.images[math.floor(math.random(#self.images))]
            if imageData.image == nil then
                error('Wrong Image format')
            end

            local particle = {
                image = imageData.image,
                x = x,
                y = y,
                xDir = x_dir,
                yDir = y_dir,
                scale = (imageData.width or imageData.image:getWidth()) / imageData.image:getWidth(),
                gravMotion = 0,
                rotMotion = 0,
                g = self.randomNumber(self.gravity - (self.gravity / 4), self.gravity),
                r = self.randomNumber(self.rotSpeed - (self.rotSpeed / 4), self.rotSpeed),
                t = 0,
                duration = self.randomNumber(self.durationRange.min, self.durationRange.max),
                userUpdate = self.userUpdateCallback,
                userDrawBefore = self.userDrawBeforeCallback,
                userDrawAfter = self.userDrawAfterCallback,
            }
            
            table.insert(self.particles, particle)
        end,
        
        ---@overload fun(): number
        ---@overload fun(n: number): number
        ---@param min number
        ---@param max number
        ---@return number
        randomNumber = function (min, max)
            local accuracy = 1000

            if max == nil then
                local randRange = math.random(accuracy) / accuracy
                if min == nil then
                    return randRange
                end
                return randRange * min
            end
            
            local minMaxDifference = max - min
            return (math.random(0, accuracy) * minMaxDifference / accuracy) + min
        end,

        ---@param particle table
        drawParticle = function (self, particle)
            if particle.userDrawBefore ~= nil then
                particle:userDrawBefore()
            end

            local scale = math.random(self.scalingVariation.min, self.scalingVariation.max) * particle.scale
            love.graphics.draw(particle.image, particle.x, particle.y, particle.rotMotion, scale, scale)
            
            if particle.userDrawAfter ~= nil then
                particle:userDrawAfter()
            end
        end,

        ---@param particle table
        updateParticle = function (particle)
            particle.x = particle.x + particle.xDir
            particle.y = particle.y + particle.yDir
            
            particle.gravMotion = particle.gravMotion + particle.g * DT
            particle.y = particle.y + particle.gravMotion
            
            particle.rotMotion = particle.rotMotion * particle.r
            
            particle.t = particle.t + DT
            
            if particle.userUpdate ~= nil then
                particle:userUpdate()
            end
        end,

        ---@param perSecond number
        emitEverySecond = function (self, perSecond)
            CurrTime = CurrTime + DT * perSecond
            if math.floor(CurrTime) ~= math.floor(PrevTime) then
                self:add()
                -- LOGGER:log(CurrTime)
                PrevTime = CurrTime
            end
        end,
        
        ---@param emitionAmount integer
        emitOnce = function (self, emitionAmount)
            for _ = 1, emitionAmount do
                self:add()
            end
        end,

        ---@overload fun(self, width: number)
        ---@param width number
        ---@param index? integer
        ---@return number
        setScale = function (self, width, index)
            if index ~= nil then
                self.images[index].width = width
            else
                for _, imageData in ipairs(self.images) do
                    imageData.width = width
                end
            end
        end,

        ---@param grav number
        setGravity = function (self, grav)
            self.gravity = grav
        end,

        ---@param min number
        ---@param max number
        setScalingVariation = function (self, min, max)
            self.scalingVariation.min = min
            self.scalingVariation.max = max
        end,

        ---@param min number
        ---@param max number
        setAngleRange = function (self, min, max)
            self.dirAngleOffsetRange = {min=min, max=max}
        end,
        
        ---@param min number
        ---@param max number
        setDurationRange = function (self, min, max)
            self.durationRange.min = min
            self.durationRange.max = max
        end,

        ---@param min number
        ---@param max number
        setSpeedRange = function (self, min, max)
            self.particleSpeedRange.min = min
            self.particleSpeedRange.max = max
        end,

        ---@param offset number
        setOffsetRange = function (self, offset)
            self.particleOriginMaxOffset = offset
        end,

        ---@param rot number
        setRotation = function (self, rot)
            self.rotSpeed = rot
        end,
        
        ---@param func fun(self: table)
        setUserUpdateCallback = function (self, func)
            self.userUpdateCallback = func
        end,
        
        ---@param func fun(self: table)
        setUserDrawBeforeCallback = function (self, func)
            self.userDrawBeforeCallback = func
        end,
        
        ---@param func fun(self: table)
        setUserDrawAfterCallback = function (self, func)
            self.userDrawAfterCallback = func
        end,

        ---@param x number
        ---@param y number
        setPosition = function (self, x, y)
            self.x = x
            self.y = y
        end,

        ---@param bodies table
        setCollisionBodies = function (self, bodies)
            self.collisionBodies = bodies
        end,

        ---@param body table
        addCollisionBody = function (self, body)
            table.insert(self.collisionBodies, body)
        end,

        ---@param index integer
        removeCollisionBody = function (self, index)
            table.remove(self.collisionBodies, index)
        end
    }
end


return particleSystem