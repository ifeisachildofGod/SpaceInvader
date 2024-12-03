local calculate = require "calculate"
local characters= require "collisionBodies.characters.player.modes"
local accecories = require 'accecories'

local enemies = {}

enemies =  {
    ---@param x number
    ---@param y number
    ---@param radius number
    ---@param player table
    ---@param world table
    ---@param color? table
    ---@param turnSpeedAccuracy? number
    ---@return table
    stationaryGunner = function (x, y, radius, player, world, color, turnSpeedAccuracy)
        turnSpeedAccuracy = turnSpeedAccuracy or 1

        local currShotTimer = 0
        local prevShotTimer = 0
        
        local dummyFunc = function () return false end
        local enemy = characters.playerVehicle(x, y, radius, color, 'mouse', dummyFunc, dummyFunc, dummyFunc, dummyFunc)
        
        enemy.foundPlayer = false
        enemy.player = player.character.player
        enemy.TURN_SPEED = calculate.interpolation(0.03, 0.9, turnSpeedAccuracy)
        enemy.SHOT_RANGE_ANGLE = 45
        enemy.shotsPerSecond = 5
        enemy.targetAngle = 0
        enemy.fovAngle = 180
        
        enemy.draw = function (self)
            self:drawBullets()
            if not self.farAway then
                self:drawParticles() 
            end
            self:drawPlayer()
        end

        enemy.updateExternalCollisions = function (self, index)
            for _, planet in ipairs(world.planets) do
                if calculate.distance(planet.x, planet.y, self.x, self.y) <= planet.radius then
                    self:destroy()
                end
            end
            
            for bulletIndex, bullet in ipairs(self.bullets) do
                for _, kamikazee in ipairs(world.kamikazees) do
                    if calculate.distance(bullet.x, bullet.y, kamikazee.x, kamikazee.y) < kamikazee.radius then
                        kamikazee:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end
                
                for _, kamikazeeGunner in ipairs(world.kamikazeeGunners) do
                    if calculate.distance(bullet.x, bullet.y, kamikazeeGunner.x, kamikazeeGunner.y) < kamikazeeGunner.radius and kamikazeeGunner.stationaryGunner ~= self then
                        kamikazeeGunner:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end

                for _, fighter in ipairs(world.fighters) do
                    if calculate.distance(bullet.x, bullet.y, fighter.x, fighter.y) < fighter.radius and fighter.stationaryGunner ~= self then
                        fighter:destroy()
                        self:removeBullet(bulletIndex)
                    end
                    
                    if calculate.distance(bullet.x, bullet.y, fighter.character.x, fighter.character.y) < fighter.character.radius and fighter.character.stationaryGunner ~= self and fighter.docked then
                        fighter.character:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end
            end
            
            if self.destroyed then
                table.remove(world.stationaryGunners, index)
            end
        end

        enemy.attack = function (self)
            for _, body in ipairs(player.collisionBodies) do
                if calculate.lineIntersection(body.x, body.y, body.radius, self.x, self.y, self.player.x, self.player.y) and body.radius > self.player.radius and body ~= player.spacecraft.player and body ~= self then
                    self.foundPlayer = false
                    return
                end
            end

            if calculate.distance(self.x, self.y, self.player.x, self.player.y) > math.sqrt(love.graphics.getWidth()^2 + love.graphics.getHeight()^2) then
                self.foundPlayer = false
                return
            end

            local dx = self.player.x - self.x
            local dy = self.y - self.player.y

            self.angle = calculate.angleLerp(self.angle, self.targetAngle, self.TURN_SPEED)
            
            if self.targetAngle - self.SHOT_RANGE_ANGLE < self.angle and self.angle < self.targetAngle + self.SHOT_RANGE_ANGLE then
                currShotTimer = currShotTimer + DT * self.shotsPerSecond
                if math.floor(currShotTimer) ~= math.floor(prevShotTimer) then
                    prevShotTimer = currShotTimer
                    if not self.farAway then
                        for _, kamikazee in ipairs(player.kamikazees) do
                            if calculate.lineIntersection(kamikazee.x, kamikazee.y, kamikazee.radius, self.x, self.y, self.player.x, self.player.y) then
                                return
                            end
                        end 
                    end

                    self:addBullet()
                end
            end
            
            self.targetAngle = (math.deg(math.atan2(dy,dx)) - 90) % 360
        end

        enemy.search = function (self)
            self.angle = (self.angle + (math.random() * 2) - 1) % 360
            
            local dx = self.player.x - self.x
            local dy = self.y - self.player.y

            local angle = (math.deg(math.atan2(dy,dx)) - 90) % 360
            
            if math.abs(self.angle - angle) < self.fovAngle and calculate.distance(self.x, self.y, self.player.x, self.player.y) < math.sqrt(love.graphics.getWidth()^2 + love.graphics.getHeight()^2) then
                self.foundPlayer = true
            end
        end

        enemy.updatePlayerDestruction = function (self)
            for index, bullet in ipairs(self.bullets) do
                local kilCondition
                
                if player.modes.spacecraft then
                    kilCondition = calculate.distance(bullet.x, bullet.y, player.spacecraft.player.x, player.spacecraft.player.y) < player.spacecraft.player.radius
                elseif player.modes.character then
                    kilCondition = calculate.distance(bullet.x, bullet.y, self.player.x, self.player.y) < self.player.radius
                end
                
                if kilCondition then
                    self.player:destroy()
                    if player.modes.spacecraft then
                        player.spacecraft.player:destroy() 
                    end
                    self:removeBullet(index)
                else
                    if calculate.distance(bullet.x, bullet.y, player.spacecraft.player.x, player.spacecraft.player.y) < player.spacecraft.player.radius then
                        player.spacecraft.player:destroy()
                    end
                end
            end

            for index, bullet in ipairs(player.spacecraft.player.bullets) do
                if calculate.distance(bullet.x, bullet.y, self.x, self.y) < self.radius then
                    self:destroy()
                    player.spacecraft.player:removeBullet(index)
                end
            end
        end

        enemy.conditionalUpdate = function (self)
            if not self.player.gettingDestroyed and not self.gettingDestroyed and not player.gettingDestroyed and not self.tooFarAway then
                if self.foundPlayer then
                    self:attack()
                else
                    self:search()
                end
                
                if not self.gettingDestroyed and not self.farAway then
                    self:updatePlayerDestruction()
                end
            end
        end

        enemy.unConditionalUpdate = function (self)
            self.x = self.x + WorldDirection.x
            self.y = self.y + WorldDirection.y

            if not self.farAway then
                self:updateParticles()
            end

            self:updateBullets()

            if not self.tooFarAway then
                self:updateExplosionProcedures() 
            end
            
        end

        enemy.update = function (self, index)
            self:conditionalUpdate()
            self:unConditionalUpdate()
            self:updateExternalCollisions(index)
        end

        return enemy

    end,

    ---@param x number
    ---@param y number
    ---@param radius number
    ---@param player table
    ---@param world table
    ---@param color? table
    ---@return table
    kamikazee = function (x, y, radius, player, world, color, turnSpeedAccuracy, angleContextWindowAccuracy, accelAccuracy, targetPointAccuracy, maxSpeedAccuracy)
        local defaultAccuracy = 1

        angleContextWindowAccuracy = angleContextWindowAccuracy or defaultAccuracy
        turnSpeedAccuracy = turnSpeedAccuracy or defaultAccuracy
        accelAccuracy = accelAccuracy or defaultAccuracy
        targetPointAccuracy = targetPointAccuracy or defaultAccuracy
        maxSpeedAccuracy = maxSpeedAccuracy or defaultAccuracy
        
        local searchAngle = math.random(0, 360)

        local dummyFunc = function () return false end
        local enemy = characters.playerVehicle(x, y, radius, color, 'mouse', dummyFunc, dummyFunc, dummyFunc, dummyFunc)

        enemy.hasSetAngle = false

        enemy.player = player.spacecraft.player
        enemy.foundPlayer = false
        
        enemy.TURN_SPEED = calculate.interpolation(0.05, 1, turnSpeedAccuracy)
        enemy.angleContextWindow = calculate.interpolation(360, 10, angleContextWindowAccuracy)
        enemy.forwardThruster.accel = calculate.interpolation(3, 12.5, accelAccuracy)
        enemy.forwardThruster.wanderingAccel = enemy.forwardThruster.accel / 2
        enemy.thrust.maxSpeed = calculate.interpolation(100, 10000, maxSpeedAccuracy)
        enemy.targetAngle = 0
        enemy.fovAngle = 180
        
        enemy.forwardThruster.particles:setScale(5)
        enemy.forwardThruster.particles:setDurationRange(0.1, 0.5)
        
        enemy.draw = function (self)
            self:drawBullets()
            if not self.farAway then
                self:drawParticles() 
            end
            self:drawPlayer()
        end

        enemy.updateExternalCollisions = function (self, index)
            for _, planet in ipairs(world.planets) do
                if calculate.distance(planet.x, planet.y, self.x, self.y) <= planet.radius then
                    self:destroy()
                end
            end

            if self.destroyed then
                table.remove(world.kamikazees, index)
            end

            for _, stationaryGunner in ipairs(world.stationaryGunners) do
                if calculate.distance(stationaryGunner.x, stationaryGunner.y, self.x, self.y) < stationaryGunner.radius then
                    self:destroy()
                    stationaryGunner:destroy()
                end
            end
            
            for _, kamikazeeGunner in ipairs(world.kamikazeeGunners) do
                if calculate.distance(kamikazeeGunner.x, kamikazeeGunner.y, self.x, self.y) < kamikazeeGunner.radius then
                    self:destroy()
                    kamikazeeGunner:destroy()
                end
            end
            
            for _, fighter in ipairs(world.fighters) do
                if calculate.distance(fighter.x, fighter.y, self.x, self.y) < fighter.radius then
                    self:destroy()
                    fighter:destroy()
                end
            end

            for _, kamikazee in ipairs(world.kamikazees) do
                if calculate.distance(kamikazee.x, kamikazee.y, self.x, self.y) < kamikazee.radius then
                    self.thrust.x = self.thrust.x + ((math.random() * 2) - 1) * (self.forwardThruster.x^2)
                    self.thrust.y = self.thrust.y + ((math.random() * 2) - 1) * (self.forwardThruster.y^2)
                end
            end
        end

        enemy.attack = function (self)
            if not self.farAway then
                for _, body in ipairs(player.collisionBodies) do
                    if calculate.lineIntersection(body.x, body.y, body.radius, self.x, self.y, self.player.x, self.player.y) and body.radius > self.player.radius and body ~= player.spacecraft.player and body ~= self then
                        self.foundPlayer = false
                        return
                    end
                end

                if calculate.distance(self.x, self.y, self.player.x, self.player.y) > math.sqrt(love.graphics.getWidth()^2 + love.graphics.getHeight()^2) then
                    self.foundPlayer = false
                    return
                end 
            end

            local dx = (self.player.x + self.player.thrust.x * DT) - self.x
            local dy = self.y - (self.player.y + self.player.thrust.y * DT)
            
            local angle = math.deg(math.atan2(dy, dx)) - 90
            
            local rad = self.radius * calculate.interpolation(2, 0, targetPointAccuracy)
            local newDY = dy - (math.sin(math.rad(angle + 90)) * rad)
            local newDX = dx + (math.cos(math.rad(angle + 90)) * rad)
            
            self.angle = calculate.angleLerp(self.angle, self.targetAngle, self.TURN_SPEED)
            
            if calculate.angleBetween(self.angle, self.targetAngle) <= self.angleContextWindow then
                self.forwardThruster.x = math.cos(math.rad(self.angle + 90)) * self.forwardThruster.accel
                self.forwardThruster.y = -math.sin(math.rad(self.angle + 90)) * self.forwardThruster.accel 
            else
                self:onBrakesPressed()
            end
            
            self.targetAngle = math.deg(math.atan2(newDY, newDX)) - 90
        end

        enemy.search = function (self)
            if math.floor(love.timer.getTime()) % 2 == 0 then
                if not self.hasSetAngle then
                    searchAngle = math.random(0, 360)
                    self.hasSetAngle = true
                end
            else
                self.hasSetAngle = false
            end
            
            self.angle = calculate.angleLerp(self.angle, searchAngle, self.TURN_SPEED)
            
            local dx = (self.player.x + self.player.thrust.x * DT) - self.x
            local dy = self.y - (self.player.y + self.player.thrust.y * DT)
            
            local angle = math.deg(math.atan2(dy, dx)) - 90
            
            if math.abs(self.angle - angle) < self.fovAngle and calculate.distance(self.x, self.y, self.player.x, self.player.y) < math.sqrt(love.graphics.getWidth()^2 + love.graphics.getHeight()^2) then
                self.foundPlayer = true
            end

            self.forwardThruster.x = math.cos(math.rad(self.angle + 90)) * self.forwardThruster.accel
            self.forwardThruster.y = -math.sin(math.rad(self.angle + 90)) * self.forwardThruster.accel
        end

        enemy.updatePlayerDestruction = function (self)
            for index, bullet in ipairs(player.spacecraft.player.bullets) do
                if calculate.distance(bullet.x, bullet.y, self.x, self.y) < self.radius then
                    self:destroy()
                    player.spacecraft.player:removeBullet(index)
                end
            end
            
            if calculate.distance(self.x, self.y, player.character.player.x, player.character.player.y) < player.character.player.radius then
                self:destroy()
                player.character.player:destroy()
            end

            if not (self.player.destroyed or self.player.gettingDestroyed) then
                if calculate.distance(self.x, self.y, self.player.x, self.player.y) < self.player.radius then
                    self:destroy()
                    self.player:destroy()
                end 
            end
        end

        enemy.unConditonalUpdate = function (self)
            self.x = self.x + WorldDirection.x
            self.y = self.y + WorldDirection.y
            
            if not self.tooFarAway then
                self.thrust.x = calculate.clamp(self.thrust.x + self.forwardThruster.x - self.reverseThruster.x, -self.thrust.maxSpeed, self.thrust.maxSpeed)
                self.thrust.y = calculate.clamp(self.thrust.y + self.forwardThruster.y - self.reverseThruster.y, -self.thrust.maxSpeed, self.thrust.maxSpeed)
                
                self:movePlayer()
                if not self.farAway then
                    self:updateParticles()
                end
            end
            
            self:updateBullets()
            self:updateExplosionProcedures()
        end

        enemy.wander = function (self)
            if math.floor(love.timer.getTime()) % 2 == 0 then
                if not self.hasSetAngle then
                    while true do
                        searchAngle = math.random(0, 360)
                        if self.farAway then
                            break
                        end
                        local intersected = false
                        
                        for _, planet in ipairs(world.planets) do
                            if calculate.lineIntersection(planet.x, planet.y, planet.radius, self.x, self.y, self.x + math.cos(math.rad(searchAngle)) * 200, self.y - math.sin(math.rad(searchAngle)) * 200) and planet.radius > self.player.radius then
                                intersected = true
                                break
                            end
                        end
                        
                        if not intersected then
                            break
                        end
                    end
                    self.hasSetAngle = true
                end
            else
                self.hasSetAngle = false
            end
            
            self.angle = calculate.angleLerp(self.angle, searchAngle, self.TURN_SPEED)
            
            self.forwardThruster.x = math.cos(math.rad(self.angle + 90)) * self.forwardThruster.accel
            self.forwardThruster.y = -math.sin(math.rad(self.angle + 90)) * self.forwardThruster.accel
        end

        enemy.conditonalUpdate = function (self)
            if not self.player.gettingDestroyed and not self.gettingDestroyed and not player.gettingDestroyed and not self.tooFarAway then
                if self.foundPlayer then
                    self:attack()
                else
                    self:search()
                end
            end

            if not self.gettingDestroyed and not self.tooFarAway then
                self:updatePlayerDestruction() 
            end

            if self.player.gettingDestroyed and not self.tooFarAway then
                self:wander()
            end

            if self.tooFarAway then
                self.forwardThruster.x = 0
                self.forwardThruster.y = 0
            end
            
        end

        enemy.update = function (self, index)
            self:conditonalUpdate()
            self:unConditonalUpdate()

            if not self.tooFarAway then
                self:updateExternalCollisions(index)
            end
        end

        return enemy

    end,
    
    ---@param x number
    ---@param y number
    ---@param radius number
    ---@param player table
    ---@param color? table
    ---@param turnSpeedAccuracy? number
    ---@return table
    kamikazeeGunner = function (x, y, radius, player, world, color, turnSpeedAccuracy, angleContextWindowAccuracy, accelAccuracy, targetPointAccuracy, maxSpeedAccuracy)
        local enemy = enemies.kamikazee(x, y, radius, player, world, color, turnSpeedAccuracy, angleContextWindowAccuracy, accelAccuracy, targetPointAccuracy, maxSpeedAccuracy)
        local stationaryGunner = enemies.stationaryGunner(x, y, radius, player, world, color, turnSpeedAccuracy)
        
        local prevShotTimer = 0
        local currShotTimer = 0

        enemy.stationaryGunner = stationaryGunner
        enemy.stationaryGunner.SHOT_RANGE_ANGLE = 100
        enemy.shoot = true

        enemy.draw = function (self)
            self:drawPlayer()
            if not self.farAway then
                self:drawParticles() 
            end
            self.stationaryGunner:drawBullets()
        end

        enemy.stationaryGunner.update = function (self)
            if not self.tooFarAway then
                if not player.gettingDestroyed then
                    if math.abs(self.angle - self.targetAngle) < self.SHOT_RANGE_ANGLE and self.foundPlayer and enemy.shoot then
                        currShotTimer = currShotTimer + DT * self.shotsPerSecond
                        if math.floor(currShotTimer) ~= math.floor(prevShotTimer) then
                            prevShotTimer = currShotTimer
                            if not self.farAway then
                                for _, kamikazee in ipairs(player.kamikazees) do
                                    if calculate.lineIntersection(kamikazee.x, kamikazee.y, kamikazee.radius, self.x, self.y, self.player.x, self.player.y) then
                                        return
                                    end
                                end
                            end
                            self:addBullet()
                        end
                    end
                end
            end
            
            self:updateBullets()
            
            if not self.tooFarAway then
                self.destroyed = false
                self:updateExternalCollisions() 
            end
        end

        enemy.stationaryGunner.updateExternalCollisions = function (self)
            for _, planet in ipairs(world.planets) do
                if calculate.distance(planet.x, planet.y, self.x, self.y) <= planet.radius then
                    self:destroy()
                end
            end
            
            for bulletIndex, bullet in ipairs(self.bullets) do
                for _, kamikazee in ipairs(world.kamikazees) do
                    if calculate.distance(bullet.x, bullet.y, kamikazee.x, kamikazee.y) < kamikazee.radius then
                        kamikazee:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end
                
                for _, fighter in ipairs(world.fighters) do
                    if calculate.distance(bullet.x, bullet.y, fighter.x, fighter.y) < fighter.radius and fighter.stationaryGunner ~= self then
                        fighter:destroy()
                        self:removeBullet(bulletIndex)
                    end

                    if calculate.distance(bullet.x, bullet.y, fighter.character.x, fighter.character.y) < fighter.character.radius and fighter.character.stationaryGunner ~= self and fighter.docked then
                        fighter.character:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end

                for _, stGunner in ipairs(world.stationaryGunners) do
                    if calculate.distance(bullet.x, bullet.y, stGunner.x, stGunner.y) < stGunner.radius then
                        stGunner:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end
            end
        end
        
        enemy.updateExternalCollisions = function (self, index)
            for _, planet in ipairs(world.planets) do
                if calculate.distance(planet.x, planet.y, self.x, self.y) <= planet.radius then
                    self:destroy()
                end
            end
            
            for bulletIndex, bullet in ipairs(self.bullets) do
                for _, stationaryGunners in ipairs(world.stationaryGunners) do
                    if calculate.distance(bullet.x, bullet.y, stationaryGunners.x, stationaryGunners.y) < stationaryGunners.radius then
                        stationaryGunners:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end

                for _, kamikazee in ipairs(world.kamikazees) do
                    if calculate.distance(bullet.x, bullet.y, kamikazee.x, kamikazee.y) < kamikazee.radius then
                        kamikazee:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end
                
                for _, kamikazeeGunner in ipairs(world.kamikazeeGunners) do
                    if calculate.distance(bullet.x, bullet.y, kamikazeeGunner.x, kamikazeeGunner.y) < kamikazeeGunner.radius then
                        kamikazeeGunner:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end
            end
            
            for _, kamikazeeGunner in ipairs(world.kamikazeeGunners) do
                if calculate.distance(kamikazeeGunner.x, kamikazeeGunner.y, self.x, self.y) < kamikazeeGunner.radius and kamikazeeGunner ~= self then
                    self.thrust.x = self.thrust.x + ((math.random() * 2) - 1) * (self.forwardThruster.x^2)
                    self.thrust.y = self.thrust.y + ((math.random() * 2) - 1) * (self.forwardThruster.y^2)
                end
            end

            if self.destroyed then
                table.remove(world.kamikazeeGunners, index)
            end
        end
        
        enemy.update = function (self, index)
            self.stationaryGunner.tooFarAway = self.tooFarAway
            self.stationaryGunner.farAway = self.farAway

            if self.gettingDestroyed then
                self.stationaryGunner:destroy()
            elseif self.stationaryGunner.gettingDestroyed then
                self:destroy()
            end
            if not self.farAway then
                self.stationaryGunner:updatePlayerDestruction()
            end

            self:conditonalUpdate()
            self:unConditonalUpdate()
            
            self.stationaryGunner:update()

            if not self.tooFarAway then
                self:updateExternalCollisions(index)
                
                self.angle = self.angle % 360
                self.stationaryGunner.angle = self.angle
                
                self.targetAngle = self.targetAngle % 360
                self.stationaryGunner.targetAngle = self.targetAngle

                self.stationaryGunner.foundPlayer = self.foundPlayer
                self.stationaryGunner.fovAngle = self.fovAngle

                self.stationaryGunner.x = self.x
                self.stationaryGunner.y = self.y
            end
            
            if player.modes.character then
                self.player = player.character.player
            elseif player.modes.spacecraft then
                self.player = player.spacecraft.player
            end
            
        end

        return enemy
    end,
    
    fighter = function (x, y, radius, player, world, color, turnSpeedAccuracy, angleContextWindowAccuracy, accelAccuracy, targetPointAccuracy, maxSpeedAccuracy)
        local prevPos = {x = x, y = y}
        local currPos = {x = x, y = y}
        
        local nearestPlanet = {distance = 0, planet = nil}
        local enemy = enemies.kamikazeeGunner(x, y, radius, player, world, color, turnSpeedAccuracy, angleContextWindowAccuracy, accelAccuracy, targetPointAccuracy, maxSpeedAccuracy)
        
        local shotsPersecond = 4
        local currShotTimer = 0
        local prevShotTimer = 0
        local shotBullet = false

        local characterMoveFunction = function ()
            local enemyAngle = calculate.angle(enemy.character.x, enemy.character.y, enemy.character.planet.x, enemy.character.planet.y)
            local playerAngle = calculate.angle(player.character.player.x, player.character.player.y, enemy.character.planet.x, enemy.character.planet.y)
            local spacecraftAngle = calculate.angle(enemy.x, enemy.y, enemy.character.planet.x, enemy.character.planet.y)
            
            local angle

            if enemy.leavingThePlanet and enemy.docked then
                angle = ((spacecraftAngle - enemyAngle) % 360) - 180
            else
                angle = ((playerAngle - enemyAngle) % 360) - 180
            end
            
            local finalAngle

            if angle > 0 then
                finalAngle = 90
            else
                finalAngle = 270
            end
            
            return true, finalAngle
        end
        
        local characterShootFunction = function ()
            local angle = 90
            local stepRate = 0.1

            return function ()
                enemy.character.shotBullet = false
                
                local angleDiff = calculate.angleBetweenAPoint(enemy.player.x, enemy.player.y, enemy.character.x, enemy.character.y, enemy.character.planet.x, enemy.character.planet.y)
                angle = 180 - (angleDiff - 90)
                logger.log(enemy.bulletPlayerDist)
                local shoot = false
                currShotTimer = currShotTimer + DT * shotsPersecond
                if math.floor(currShotTimer) ~= math.floor(prevShotTimer) then
                    prevShotTimer = currShotTimer
                    if not shotBullet then
                        shoot = true
                        shotBullet = true
                    end
                else
                    shotBullet = false
                end
                
                if math.abs(angleDiff) < enemy.character.planet.radius / 1 then
                    return not enemy.leavingThePlanet and enemy.docked and shoot, angle
                end
                return false
            end
        end
        
        
        enemy.minBulletPos = {x=0, y=0}
        enemy.bulletPlayerMinDistTracker = math.huge

        enemy.bulletPlayerDist = 0
        enemy.character = characters.player(x, y, 5, {up = characterMoveFunction, down = function () return false end}, nil, color, nil, characterShootFunction())
        enemy.character.horizontal.acceleration = 0.1

        enemy.stationaryGunner.removeBullet = function (self, index)
            if enemy.docked then
                enemy.bulletPlayerDist = calculate.angleBetweenAPoint(enemy.minBulletPos.x, enemy.minBulletPos.y, enemy.character.x, enemy.character.y, enemy.dockedPlanet.x, enemy.dockedPlanet.y)
            end
            table.remove(self.bullets, index)
        end
        
        enemy.stationaryGunner.updateBullets = function (self)
            for index, bullet in ipairs(self.bullets) do
                if bullet.dist > calculate.distance(love.graphics.getWidth(), love.graphics.getHeight()) then
                    self:removeBullet(index)
                else
                    bullet:update()
                    if enemy.docked then
                        local dist = calculate.distance(bullet.x, bullet.y, player.character.player.x, player.character.player.y)
                        if dist < enemy.bulletPlayerMinDistTracker then
                            enemy.minBulletPos.x = bullet.x
                            enemy.minBulletPos.y = bullet.y
                            enemy.bulletPlayerMinDistTracker = dist
                        end
                    end
                end
            end
        end

        enemy.character.addBullet = function (self, angle)
            if not self.gettingDestroyed then
                local bullet = accecories.bullet(self.x + math.cos(math.rad(angle)), self.y - math.sin(math.rad(angle)), angle - 90, 3, 5)

                bullet.update = function (b)
                    local d = calculate.distance(b.x, b.y, self.planet.x, self.planet.y)
    
                    local Fx = -self.gravity * math.cos(math.rad(calculate.angle(self.planet.x, self.planet.y, self.x, self.y) + 90)) / d^2
                    local Fy = self.gravity * math.sin(math.rad(calculate.angle(self.planet.x, self.planet.y, self.x, self.y) + 90)) / d^2
                    
                    b.thrust.x = b.thrust.x + Fx
                    b.thrust.y = b.thrust.y + Fy
    
                    b.x = WorldDirection.x + b.x + b.thrust.x
                    b.y = WorldDirection.y + b.y + b.thrust.y
                    
                    b.dist = b.dist + calculate.distance(b.thrust.x, b.thrust.y)
                end

                table.insert(enemy.stationaryGunner.bullets, bullet)
                -- table.insert(enemy.character.bullets, bullet)
            end
        end

        enemy.safetyDistance = 10
        enemy.divertionDirection = 1
        enemy.dockingDistance = 200
        enemy.dockingSpeed = 3
        
        enemy.reverseThruster.particles:setDurationRange(-0.5, 0.5)
        enemy.reverseThruster.particles:setScaleRange(1, 2)
        
        enemy.draw = function (self)
            self.character:draw()
            self:drawPlayer()
            if not self.farAway then
                self:drawParticles() 
            end
            self.stationaryGunner:drawBullets()
        end

        enemy.attack = function (self)
            nearestPlanet = {distance = 0, planet = nil}
            
            if not self.farAway then
                for _, planet in ipairs(world.planets) do
                    if calculate.lineIntersection(planet.x, planet.y, planet.radius, self.x, self.y, self.player.x, self.player.y) and planet.radius > self.player.radius then
                        nearestPlanet.planet = planet
                        
                        if calculate.distance(self.player.x, self.player.y, planet.x, planet.y) < nearestPlanet.distance then
                            nearestPlanet.planet = planet
                            nearestPlanet.distance = calculate.distance(self.player.x, self.player.y, planet.x, planet.y)
                        end
                    end
                end

                if nearestPlanet.planet == nil then
                    self.divertionDirection = (math.random() * 2) - 1
                    self.divertionDirection = self.divertionDirection + ((self.divertionDirection == 0 and 0.5) or 0)
                end
            end
            
            if not self.docked then
                self.leavingThePlanet = false

                if not self.docking then
                    self.landOnPlayerPlanet = self.player.planet ~= nil and not self.player.gettingDestroyed
    
                    local dx = ((self.landOnPlayerPlanet and self.player.planet.x) or self.player.x) - self.x
                    local dy = self.y - ((self.landOnPlayerPlanet and self.player.planet.y) or self.player.y)
                    
                    if calculate.distance(self.x, self.y, self.player.x, self.player.y) <= self.safetyDistance then
                        self:onBrakesPressed()
                    end
                    
                    self.angle = calculate.angleLerp(self.angle, self.targetAngle, self.TURN_SPEED)
                    self.targetAngle = math.deg(math.atan2(dy, dx)) - 90
                    
                    if nearestPlanet.planet ~= nil then
                        self.targetAngle = self.targetAngle + 90 * self.divertionDirection
                        
                        ---@diagnostic disable-next-line: undefined-field
                        if calculate.lineIntersection(nearestPlanet.planet.x, nearestPlanet.planet.y, nearestPlanet.planet.radius, self.x + self.thrust.x, self.y + self.thrust.y, self.player.x, self.player.y) then
                            self:onBrakesPressed()
                        end
                    end
    
                    if calculate.angleBetween(self.angle, self.targetAngle) <= self.angleContextWindow then
                        self.forwardThruster.x = math.cos(math.rad(self.angle + 90)) * self.forwardThruster.accel
                        self.forwardThruster.y = -math.sin(math.rad(self.angle + 90)) * self.forwardThruster.accel
                    else
                        self:onBrakesPressed()
                    end
                    
                    prevPos.x, prevPos.y = self.x, self.y
                    self.inDockingPosition = false
                    if self.landOnPlayerPlanet then
                        if calculate.distance(self.x, self.y, self.player.planet.x, self.player.planet.y) - (self.player.planet.radius + self.radius) < self.dockingDistance then
                            self.docking = true
                            self.dockedPlanet = self.player.planet
                        end
                    else
                        self.docking = false
                    end
                    currPos.x, currPos.y = self.x, self.y
                    
                end
                
            else
                self:updateDockingProcedure()
                if self.docked and not player.spacecraft.player.docked and calculate.distance(player.spacecraft.player.x, player.spacecraft.player.y, self.dockedPlanet.x, self.dockedPlanet.y) - (self.dockedPlanet.radius + player.spacecraft.player.radius) < self.dockingDistance then
                    self.leavingThePlanet = true
                end
                if not self.undocking then
                    self.thrust.x = 0
                    self.thrust.y = 0
                    self.forwardThruster.x = 0
                    self.forwardThruster.y = 0
                end
            end
            
            if self.docking then
                self.targetAngle = calculate.angle(self.dockedPlanet.x, self.dockedPlanet.y, self.x, self.y)
                self.angle = calculate.angleLerp(self.angle, self.targetAngle, self.TURN_SPEED)
                
                self.inDockingPosition = calculate.angleBetween(self.angle, self.targetAngle) < 6

                local speed = math.sqrt((currPos.x - prevPos.x)^2 + (currPos.y - prevPos.y)^2)
                
                if speed > self.dockingSpeed then
                    self:onBrakesPressed()
                end
                
                if speed < self.dockingSpeed and self.docking then
                    self.reverseThruster.x = math.cos(math.rad(self.angle + 90)) * self.reverseThruster.accel
                    self.reverseThruster.y = -math.sin(math.rad(self.angle + 90)) * self.reverseThruster.accel
                else
                    self:releaseReverseThrusters()
                end

                if calculate.distance(self.x, self.y, self.dockedPlanet.x, self.dockedPlanet.y) <= self.radius + self.dockedPlanet.radius then
                    self.docked = true
                    self.docking = false
                    self.character:setPlanet(self.dockedPlanet)
                    self.character.vertical.displacement = 0
                end
            end
        end

        enemy.updateExternalCollisions = function (self, index)
            for _, planet in ipairs(world.planets) do
                if calculate.distance(planet.x, planet.y, self.x, self.y) <= planet.radius and not self.docked then
                    self:destroy()
                end
            end
            
            for bulletIndex, bullet in ipairs(self.bullets) do
                for _, stationaryGunners in ipairs(world.stationaryGunners) do
                    if calculate.distance(bullet.x, bullet.y, stationaryGunners.x, stationaryGunners.y) < stationaryGunners.radius then
                        stationaryGunners:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end

                for _, kamikazee in ipairs(world.kamikazees) do
                    if calculate.distance(bullet.x, bullet.y, kamikazee.x, kamikazee.y) < kamikazee.radius then
                        kamikazee:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end
                
                for _, kamikazeeGunner in ipairs(world.kamikazeeGunners) do
                    if calculate.distance(bullet.x, bullet.y, kamikazeeGunner.x, kamikazeeGunner.y) < kamikazeeGunner.radius then
                        kamikazeeGunner:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end
            end
            
            for _, stationaryGunner in ipairs(world.stationaryGunners) do
                if calculate.distance(stationaryGunner.x, stationaryGunner.y, self.x, self.y) < stationaryGunner.radius then
                    self:destroy()
                    stationaryGunner:destroy()
                end
                if calculate.distance(stationaryGunner.x, stationaryGunner.y, self.character.x, self.character.y) < stationaryGunner.radius and self.docked then
                    self.character:destroy()
                end
            end
            
            for _, kamikazeeGunner in ipairs(world.kamikazeeGunners) do
                if calculate.distance(kamikazeeGunner.x, kamikazeeGunner.y, self.x, self.y) < kamikazeeGunner.radius then
                    self:destroy()
                    kamikazeeGunner:destroy()
                end
                
                if calculate.distance(kamikazeeGunner.x, kamikazeeGunner.y, self.character.x, self.character.y) < kamikazeeGunner.radius and self.docked then
                    self.character:destroy()
                end
            end
            
            for _, kamikazee in ipairs(world.kamikazees) do
                if calculate.distance(kamikazee.x, kamikazee.y, self.x, self.y) < kamikazee.radius then
                    self:destroy()
                    kamikazee:destroy()
                end
                
                if calculate.distance(kamikazee.x, kamikazee.y, self.character.x, self.character.y) < kamikazee.radius and self.docked then
                    self.character:destroy()
                end

            end

            for _, fighter in ipairs(world.fighters) do
                if calculate.distance(fighter.x, fighter.y, self.x, self.y) < fighter.radius and fighter ~= self then
                    self.thrust.x = self.thrust.x + ((math.random() * 2) - 1) * (self.forwardThruster.x^2)
                    self.thrust.y = self.thrust.y + ((math.random() * 2) - 1) * (self.forwardThruster.y^2)
                end

                if calculate.distance(fighter.character.x, fighter.character.y, self.character.x, self.character.y) < fighter.character.radius and fighter.character ~= self.character and self.docked then
                    self.character.horizontal.displacement = self.character.horizontal.displacement + ((math.random() * 2) - 1) * self.character.horizontal.velocity
                end

                if calculate.distance(fighter.x, fighter.y, self.character.x, self.character.y) < fighter.radius and fighter ~= self and self.docked and not fighter.docked then
                    self.character:destroy()
                end
            end
            
            if self.gettingDestroyed and not self.docked then
                self.character:destroy()
            end

            if self.destroyed and self.character.destroyed then
                table.remove(world.fighters, index)
            end
        end
        
        enemy.stationaryGunner.updatePlayerDestruction = function (self)
            for index, bullet in ipairs(self.bullets) do
                local kilCondition
                
                if player.modes.spacecraft then
                    kilCondition = calculate.distance(bullet.x, bullet.y, player.spacecraft.player.x, player.spacecraft.player.y) < player.spacecraft.player.radius and not player.spacecraft.player.gettingDestroyed
                elseif player.modes.character then
                    kilCondition = calculate.distance(bullet.x, bullet.y, self.player.x, self.player.y) < self.player.radius and not player.character.player.gettingDestroyed
                end
                
                if kilCondition then
                    enemy.leavingThePlanet = true

                    self.player:destroy()
                    if player.modes.spacecraft then
                        player.spacecraft.player:destroy()
                    end
                    self:removeBullet(index)
                else
                    if calculate.distance(bullet.x, bullet.y, player.spacecraft.player.x, player.spacecraft.player.y) < player.spacecraft.player.radius then
                        player.spacecraft.player:destroy()
                    end
                end
            end
        end

        enemy.stationaryGunner.updateExternalCollisions = function (self)
            for bulletIndex, bullet in ipairs(self.bullets) do
                for _, kamikazee in ipairs(world.kamikazees) do
                    if calculate.distance(bullet.x, bullet.y, kamikazee.x, kamikazee.y) < kamikazee.radius then
                        kamikazee:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end
                
                for _, kamikazeeGunner in ipairs(world.kamikazeeGunners) do
                    if calculate.distance(bullet.x, bullet.y, kamikazeeGunner.x, kamikazeeGunner.y) < kamikazeeGunner.radius and kamikazeeGunner.stationaryGunner ~= self then
                        kamikazeeGunner:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end

                for _, stationaryGunner in ipairs(world.stationaryGunners) do
                    if calculate.distance(bullet.x, bullet.y, stationaryGunner.x, stationaryGunner.y) < stationaryGunner.radius then
                        stationaryGunner:destroy()
                        self:removeBullet(bulletIndex)
                    end
                end
            end
        end
        
        enemy.updatePlayerDestruction = function (self)
            for index, bullet in ipairs(player.spacecraft.player.bullets) do
                if calculate.distance(bullet.x, bullet.y, self.x, self.y) < self.radius and not (self.gettingDestroyed or self.destroyed) then
                    self:destroy()
                    player.spacecraft.player:removeBullet(index)
                end
                
                if calculate.distance(bullet.x, bullet.y, self.character.x, self.character.y) < self.character.radius + bullet.radius and not (self.character.gettingDestroyed or self.character.destroyed) then
                    self.character:destroy()
                    player.spacecraft.player:removeBullet(index)
                end
            end
            
            -- if calculate.distance(self.x, self.y, player.character.player.x, player.character.player.y) < player.character.player.radius and not self.docked then
            --     self:destroy()
            --     player.character.player:destroy()
            -- end
            
            -- if calculate.distance(self.character.x, self.character.y, player.character.player.x, player.character.player.y) < player.character.player.radius and not player.spacecraft.player.docked then
            --     self.character:destroy()
            --     player.character.player:destroy()
            -- end
            if not player.spacecraft.player.gettingDestroyed then
                if calculate.distance(self.x, self.y, player.spacecraft.player.x, player.spacecraft.player.y) < player.spacecraft.player.radius then
                    self:destroy()
                    player.spacecraft.player:destroy()
                end
                
                if calculate.distance(self.character.x, self.character.y, player.spacecraft.player.x, player.spacecraft.player.y) < player.spacecraft.player.radius and not player.spacecraft.player.docked then
                    self.character:destroy()
                    -- player.spacecraft.player:destroy()
                end

            end
        end
        
        enemy.conditonalUpdate = function (self)
            if not self.player.gettingDestroyed and not self.gettingDestroyed and not self.character.gettingDestroyed and not player.gettingDestroyed and not self.tooFarAway then
                if self.foundPlayer or self.docked then
                    self:attack()
                else
                    self:search()
                end
            end

            if not (self.gettingDestroyed and self.character.gettingDestroyed) and not self.tooFarAway then
                self:updatePlayerDestruction()
            end
            
            if self.player.destroyed and not self.tooFarAway and not self.docked then
                self:wander()
            end

            if self.tooFarAway then
                self.forwardThruster.x = 0
                self.forwardThruster.y = 0
            end
            
        end

        enemy.update = function (self, index)
            if self.docked then
                self.farAway = false
                self.tooFarAway = false
            end

            if self.leavingThePlanet and self.docked then
                if calculate.distance(self.x, self.y, self.character.x, self.character.y) <= self.radius then
                    self:startUndock()
                end
            end

            self.shoot = not (self.docking or self.docked)
            
            if self.farAway then
                self.foundPlayer = false
                return
            else
                self.foundPlayer = true
            end
            
            self.stationaryGunner.tooFarAway = self.tooFarAway
            self.stationaryGunner.farAway = self.farAway

            if self.gettingDestroyed then
                self.stationaryGunner:destroy()
            elseif self.stationaryGunner.gettingDestroyed then
                self:destroy()
            end
            if not self.farAway then
                self.stationaryGunner:updatePlayerDestruction()
            end

            self:conditonalUpdate()
            self:unConditonalUpdate()
            
            if nearestPlanet.planet ~= nil then
                self.shoot = false
                self.stationaryGunner.shoot = self.shoot
            end

            self.stationaryGunner:update()

            if not self.tooFarAway then
                self:updateExternalCollisions(index)
                
                self.angle = self.angle % 360
                self.stationaryGunner.angle = self.angle
                
                self.targetAngle = self.targetAngle % 360
                self.stationaryGunner.targetAngle = self.targetAngle

                self.stationaryGunner.foundPlayer = self.foundPlayer
                self.stationaryGunner.fovAngle = self.fovAngle

                self.stationaryGunner.x = self.x
                self.stationaryGunner.y = self.y
            end
            
            self.character.x = self.character.x + WorldDirection.x
            self.character.y = self.character.y + WorldDirection.y

            if self.gettingDestroyed and not self.docked then
                self.character:destroy()
            end

            self.character:updateInput()
            self.character:update()

            if not self.docked then
                self.character.x = self.x
                self.character.y = self.y
            end

            if player.modes.character then
                self.player = player.character.player
            elseif player.modes.spacecraft then
                self.player = player.spacecraft.player
            end
            
        end

        return enemy

    end,
}

return enemies