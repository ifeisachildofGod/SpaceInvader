local list         =   require 'list'
local objects      =   require 'objects'
local calculate    =   require "calculate"
local characters   =   require "collisionBodies.characters.player.modes"

local enemies = {}

enemies =  {
    ---@param x number
    ---@param y number
    ---@param radius number
    ---@param player table
    ---@param homePlanet table
    ---@param world table
    ---@param color? table
    ---@param turnSpeedAccuracy? number
    ---@return table
    stationaryGunner = function (x, y, radius, player, homePlanet, world, color, turnSpeedAccuracy)
        turnSpeedAccuracy = turnSpeedAccuracy or 1

        local currShotTimer = 0
        local prevShotTimer = 0
        
        local enemy = characters.playerVehicle(x, y, radius, color)
        
        enemy.planet = homePlanet or world.planets[1]
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
            for bulletIndex, bullet in ipairs(self.bullets) do
                for _, kamikazee in ipairs(world.kamikazees) do
                    if calculate.distance(bullet.x, bullet.y, kamikazee.x, kamikazee.y) < kamikazee.radius then
                        kamikazee:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end
                
                for _, kamikazeeGunner in ipairs(world.kamikazeeGunners) do
                    if calculate.distance(bullet.x, bullet.y, kamikazeeGunner.x, kamikazeeGunner.y) < kamikazeeGunner.radius and kamikazeeGunner.stationaryGunner ~= self then
                        kamikazeeGunner:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end

                for _, fighter in ipairs(world.fighters) do
                    if calculate.distance(bullet.x, bullet.y, fighter.x, fighter.y) < fighter.radius and fighter.stationaryGunner ~= self then
                        fighter:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                    
                    if calculate.distance(bullet.x, bullet.y, fighter.character.x, fighter.character.y) < fighter.character.radius and fighter.character.stationaryGunner ~= self and fighter.docked then
                        fighter.character:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end
            end
            
            if self.destroyed then
                table.remove(world.stationaryGunners, index)
            end
        end

        enemy.damage = function (self, d)
            self.health = self.health - d

            if self.health <= 0 then
                self:destroy()
                self.health = 0
            end
        end

        enemy.attack = function (self)
            for _, body in ipairs(player.collisionBodies) do
                if calculate.lineIntersection(body.x, body.y, body.radius, self.x, self.y, self.player.x, self.player.y) and body.radius > self.player.radius and body ~= player.spacecraft.player and body ~= self then
                    self.foundPlayer = false
                    return
                end
            end

            if calculate.distance(self.x, self.y, self.player.x, self.player.y) > math.sqrt(SCREEN_WIDTH^2 + SCREEN_HEIGHT^2) then
                self.foundPlayer = false
                return
            end

            local dx = self.player.x - self.x
            local dy = self.y - self.player.y
            
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
            self.targetAngle = self.targetAngle + (math.random() * 6) - 3
            
            local dx = self.player.x - self.x
            local dy = self.y - self.player.y

            local angle = (math.deg(math.atan2(dy,dx)) - 90) % 360
            
            if math.abs(self.angle - angle) < self.fovAngle and calculate.distance(self.x, self.y, self.player.x, self.player.y) < math.sqrt(SCREEN_WIDTH^2 + SCREEN_HEIGHT^2) then
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
                        player.spacecraft.player:damage(bullet.damage)
                    end
                    self:removeBullet(index)
                else
                    if calculate.distance(bullet.x, bullet.y, player.spacecraft.player.x, player.spacecraft.player.y) < player.spacecraft.player.radius then
                        player.spacecraft.player:damage(bullet.damage)
                    end
                end
            end

            if not self.tooFarAway then
                for index, bullet in ipairs(player.spacecraft.player.bullets) do
                    if calculate.distance(bullet.x, bullet.y, self.x, self.y) < self.radius then
                        self:damage(bullet.damage)
                        player.spacecraft.player:removeBullet(index)
                    end
                end
            end
        end

        enemy.conditionalUpdate = function (self)
            if self.farAway then
                self.foundPlayer = false
            end

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

            if self.tooFarAway then
                self.targetAngle = calculate.angle(self.planet.x, self.planet.y, self.x, self.y)
            end
        end

        enemy.unConditionalUpdate = function (self)
            self.x = self.x + WorldDirection.x
            self.y = self.y + WorldDirection.y

            if not self.farAway then
                self:updateParticles()
            end

            self:updateBullets()
            self:updateExplosionProcedures()
            
        end

        enemy.update = function (self, index)
            self.angle = calculate.angleLerp(self.angle, self.targetAngle, self.TURN_SPEED)

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
    ---@param homePlanet? table
    ---@param world table
    ---@param color? table
    ---@return table
    kamikazee = function (x, y, radius, player, homePlanet, world, color, turnSpeedAccuracy, angleContextWindowAccuracy, accelAccuracy, targetPointAccuracy, maxSpeedAccuracy)
        local defaultAccuracy = 1

        angleContextWindowAccuracy = angleContextWindowAccuracy or defaultAccuracy
        turnSpeedAccuracy = turnSpeedAccuracy or defaultAccuracy
        accelAccuracy = accelAccuracy or defaultAccuracy
        targetPointAccuracy = targetPointAccuracy or defaultAccuracy
        maxSpeedAccuracy = maxSpeedAccuracy or defaultAccuracy

        local enemy = characters.playerVehicle(x, y, radius, color)

        enemy.planet = homePlanet or world.planets[1]

        enemy.hasSetAngle = false

        enemy.player = player.spacecraft.player
        enemy.foundPlayer = false
        
        enemy.TURN_SPEED = calculate.interpolation(0.05, 0.8, turnSpeedAccuracy)
        enemy.angleContextWindow = calculate.interpolation(360, 10, angleContextWindowAccuracy)
        enemy.forwardThruster.accel = calculate.interpolation(3, 12.5, accelAccuracy)
        enemy.forwardThruster.wanderingAccel = enemy.forwardThruster.accel / 2
        enemy.thrust.maxSpeed = calculate.interpolation(100, 10000, maxSpeedAccuracy)
        
        enemy.targetAngle = 0
        enemy.fovAngle = 180
        enemy.dockingDistance = 600
        enemy.playerBreakOffDistance = math.sqrt(SCREEN_WIDTH^2 + SCREEN_HEIGHT^2)
        enemy.characterBaseAngle = 20
        enemy.dockingVel = 30
        enemy.searchingForHomePlanet = false
        enemy.hasSetSearchState = false
        enemy.homeCheckpoints = {}

        enemy.forwardThruster.particles:setScale(5)
        enemy.forwardThruster.particles:setDurationRange(0.1, 0.5)
        
        enemy.getPositionSafetyScore = function (prevPosX, prevPosY, checkPosX, checkPosY, target)
            local score = 0
            local CRASH_DISTANCE = 50  -- Adjust based on planet radius
            local DANGER_DISTANCE = 150  -- Distance to start penalizing
            local GRAVITY_WELL_DISTANCE = 300  -- Distance where gravity becomes significant
            
            -- Calculate distance to target planet
            local distToTarget = calculate.distance(checkPosX, checkPosY, target.x, target.y) - target.radius
            local prevDistToTarget = calculate.distance(prevPosX, prevPosY, target.x, target.y) - target.radius
            
            -- ============================================
            -- 1. REWARD: Getting closer to target planet
            -- ============================================
            if distToTarget < prevDistToTarget then
                -- Moving closer is good
                local improvement = prevDistToTarget - distToTarget
                score = score + improvement * 2
            else
                -- Moving away is bad
                local worsening = distToTarget - prevDistToTarget
                score = score - worsening * 1.5
            end
            
            -- ============================================
            -- 2. REWARD: Being close to target (but not too close)
            -- ============================================
            local targetProximityScore = 1000 / (distToTarget + 1)  -- Inverse relationship
            score = score + targetProximityScore
            
            -- ============================================
            -- 3. PENALTY: Dangerous proximity to obstacles
            -- ============================================
            for _, planet in ipairs(world.planets) do
                local distToPlanet = calculate.distance(checkPosX, checkPosY, planet.x, planet.y) - planet.radius
                
                -- Severe penalty for crash course
                if distToPlanet < CRASH_DISTANCE then
                    score = score - 10000  -- Massive penalty
                -- Heavy penalty for danger zone
                elseif distToPlanet < DANGER_DISTANCE then
                    local dangerScore = (DANGER_DISTANCE - distToPlanet) / DANGER_DISTANCE
                    score = score - dangerScore * 500
                -- Moderate penalty for gravity well
                elseif distToPlanet < GRAVITY_WELL_DISTANCE then
                    local gravityScore = (GRAVITY_WELL_DISTANCE - distToPlanet) / GRAVITY_WELL_DISTANCE
                    score = score - gravityScore * 100
                end
            end
            
            -- ============================================
            -- 4. PENALTY: Check trajectory toward obstacles
            -- ============================================
            local velocity = {
                x = checkPosX - prevPosX,
                y = checkPosY - prevPosY
            }
            local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
            
            if speed > 0.1 then  -- Only check if moving
                for _, planet in ipairs(world.planets) do
                    -- Vector from current position to planet
                    local toPlanet = {
                        x = planet.x - checkPosX,
                        y = planet.y - checkPosY
                    }
                    
                    -- Dot product to check if heading toward planet
                    local dot = velocity.x * toPlanet.x + velocity.y * toPlanet.y
                    
                    if dot > 0 then  -- Heading toward planet
                        local distToPlanet = calculate.distance(checkPosX, checkPosY, planet.x, planet.y) - planet.radius
                        -- Normalize dot product
                        local toPlanetDist = calculate.distance(toPlanet.x, toPlanet.y)
                        local alignment = dot / (speed * toPlanetDist)
                        
                        -- More penalty if heading directly at planet and close
                        if alignment > 0.7 and distToPlanet < GRAVITY_WELL_DISTANCE then
                            score = score - alignment * 200
                        end
                    end
                end
            end
            
            -- ============================================
            -- 5. BONUS: Efficient movement (not too fast or slow)
            -- ============================================
            if speed > 0 then
                -- Optimal speed range (adjust based on your game)
                local OPTIMAL_SPEED = 5
                local speedEfficiency = 1 - math.abs(speed - OPTIMAL_SPEED) / OPTIMAL_SPEED
                speedEfficiency = math.max(0, speedEfficiency)
                score = score + speedEfficiency * 50
            end
            
            -- ============================================
            -- 6. BONUS: Clear path to target
            -- ============================================
            local hasCleanPath = true
            for _, planet in ipairs(world.planets) do
                -- Check if any planet is between ship and target
                local distToPlanet = calculate.distance(checkPosX, checkPosY, planet.x, planet.y) - planet.radius
                local distPlanetToTarget = calculate.distance(planet.x, planet.y, target.x, target.y) - planet.radius
                
                -- If planet is roughly between ship and target
                if distToPlanet + distPlanetToTarget < distToTarget * 1.2 then
                    hasCleanPath = false
                    break
                end
            end
            
            if hasCleanPath then
                score = score + 100
            end
            
            return score
        end
        
        enemy.getSafestRoute = function (self, targetPlanet, steps, stepDist, checkPointAmt)
            local angles = {}
            local score = -math.huge

            local step_X, step_Y = self.x, self.y;
            
            local safestStepX, safestStepY = step_X, step_Y

            for _ = 1, steps do
                for turn = 0, checkPointAmt do
                    local angle = turn * 360 / checkPointAmt

                    local dx, dy = calculate.direction(angle)
                    
                    local s_x, s_y = step_X + (dx * stepDist), step_Y + (dy * stepDist)
                    local newScore = self.getPositionSafetyScore(step_X, step_Y, s_x, s_y, targetPlanet)
                    
                    if newScore > score then
                        score = newScore
                        safestStepX, safestStepY = s_x, s_y
                    end
                end
                
                step_X, step_Y = safestStepX, safestStepY

                table.insert(angles, {x=step_X, y=step_Y})
            end

            return angles
        end
        
        enemy.draw = function (self)
            self:drawBullets()
            if not self.farAway then
                self:drawParticles() 
            end
            self:drawPlayer()
        end

        enemy.updateExternalCollisions = function (self, index)
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
                if calculate.distance(kamikazee.x, kamikazee.y, self.x, self.y) < kamikazee.radius and kamikazee ~= self then
                    self.thrust.x = self.thrust.x + ((math.random() * 2) - 1) * (self.forwardThruster.x^2)
                    self.thrust.y = self.thrust.y + ((math.random() * 2) - 1) * (self.forwardThruster.y^2)
                end
            end
        end
        
        enemy.updateDock = function (self, planet)
            self.targetAngle = calculate.angle(planet.x, planet.y, self.x, self.y) % 360
            self.forwardThruster.x = 0
            self.forwardThruster.y = 0
            
            local speed = calculate.distance(self.thrust.x, self.thrust.y)
            
            if speed > self.dockingVel then
                self:onBrakesPressed()
            elseif speed < self.dockingVel then
                self.reverseThruster.x = self.reverseThruster.x + math.cos(math.rad(self.angle + 90)) * self.reverseThruster.accel
                self.reverseThruster.y = self.reverseThruster.y - math.sin(math.rad(self.angle + 90)) * self.reverseThruster.accel
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
            end

            local dx = (self.player.x + self.player.thrust.x * DT) - self.x
            local dy = self.y - (self.player.y + self.player.thrust.y * DT)
            
            local angle = math.deg(math.atan2(dy, dx)) - 90
            
            local rad = self.radius * calculate.interpolation(2, 0, targetPointAccuracy)
            local newDY = dy - (math.sin(math.rad(angle + 90)) * rad)
            local newDX = dx + (math.cos(math.rad(angle + 90)) * rad)
            
            -- if calculate.angleBetween(self.angle, self.targetAngle) <= self.angleContextWindow then
                self.forwardThruster.x = math.cos(math.rad(self.angle + 90)) * self.forwardThruster.accel
                self.forwardThruster.y = -math.sin(math.rad(self.angle + 90)) * self.forwardThruster.accel 
            -- else
            --     self:onBrakesPressed()
            -- end
            
            self.targetAngle = math.deg(math.atan2(newDY, newDX)) - 90
        end

        enemy.search = function (self)
            if math.floor(love.timer.getTime()) % 2 == 0 then
                if not self.hasSetAngle then
                    self.targetAngle = math.random(0, 360)
                    self.hasSetAngle = true
                end
            else
                self.hasSetAngle = false
            end
            
            local dx = (self.player.x + self.player.thrust.x * DT) - self.x
            local dy = self.y - (self.player.y + self.player.thrust.y * DT)
            
            local angle = math.deg(math.atan2(dy, dx)) - 90
            
            if math.abs(self.angle - angle) < self.fovAngle and calculate.distance(self.x, self.y, self.player.x, self.player.y) < self.playerBreakOffDistance then
                self.foundPlayer = true
            end

            self.forwardThruster.x = math.cos(math.rad(self.angle + 90)) * self.forwardThruster.accel
            self.forwardThruster.y = -math.sin(math.rad(self.angle + 90)) * self.forwardThruster.accel
        end

        enemy.updatePlayerDestruction = function (self)
            for index, bullet in ipairs(player.spacecraft.player.bullets) do
                if calculate.distance(bullet.x, bullet.y, self.x, self.y) < self.radius then
                    self:damage(bullet.damage)
                    player.spacecraft.player:removeBullet(index)
                end
            end
            
            if calculate.distance(self.x, self.y, player.character.player.x, player.character.player.y) < player.character.player.radius then
                self:destroy()
                player.character.player:destroy()
            end

            if not self.player.gettingDestroyed then
                if calculate.distance(self.x, self.y, self.player.x, self.player.y) < self.player.radius then
                    self:destroy()
                    self.player:destroy()
                end 
            end
        end
        
        enemy.damage = function (self, d)
            self.health = self.health - d
            if self.health <= 0 then
                self:destroy()
                self.health = 0
            end
        end

        enemy.returnToPlanet = function (self, planet)
            logger.log(self.docking)
            if not self.docked and not self.gettingDestroyed then
                if not self.docking then
                    if #self.homeCheckpoints == 0 then
                        -- Getting the checkpoint route
                        self.homeCheckpoints = self:getSafestRoute(planet, 7, 100, 60)
                    else
                        -- Moving to the checkpoint
                        ---@diagnostic disable-next-line: unbalanced-assignments
                        
                        local cp = self.homeCheckpoints[1]
                        
                        if calculate.distance(self.x, self.y, cp.x, cp.y) <= self.radius + 200 then
                            table.remove(self.homeCheckpoints, 1)
                        else
                            self.targetAngle = calculate.angle(self.x, self.y, cp.x, cp.y)
                        end
                    end
                    
                    if calculate.distance(self.x, self.y, planet.x, planet.y) - (planet.radius + self.radius) <= self.dockingDistance then
                        self.docking = true
                        self.homeCheckpoints = {}
                    else
                        self:releaseReverseThrusters()
                        self.forwardThruster.x = math.cos(math.rad(self.angle + 90)) * self.forwardThruster.accel
                        self.forwardThruster.y = -math.sin(math.rad(self.angle + 90)) * self.forwardThruster.accel
                    end
                    
                else
                    self:updateDock(planet)
                end
            end
        end

        enemy.leavePlanet = function (self, planet)
            local angle = calculate.angle(self.x, self.y, planet.x, planet.y) - 90
            
            self.forwardThruster.x = math.cos(math.rad(angle)) * self.forwardThruster.accel
            self.forwardThruster.y = -math.sin(math.rad(angle)) * self.forwardThruster.accel
            
            self.thrust.x = calculate.clamp(self.thrust.x + self.forwardThruster.x, -self.thrust.maxSpeed, self.thrust.maxSpeed)
            self.thrust.y = calculate.clamp(self.thrust.y + self.forwardThruster.y, -self.thrust.maxSpeed, self.thrust.maxSpeed)

            self.x = self.x + self.thrust.x * DT
            self.y = self.y + self.thrust.y * DT
            
            local g = calculate.GRAVITATIONAL_CONSTANT * planet.mass / planet.radius^2
            local escapeVel = math.sqrt(2 * planet.radius * g)

            self.docked = false
            if calculate.distance(self.x, self.y, planet.x, planet.y) - (self.radius + planet.radius) > escapeVel then
                self:undock()
            end
        end

        enemy.unConditionalUpdate = function (self)
            self.x = self.x + WorldDirection.x
            self.y = self.y + WorldDirection.y
            
            self:movePlayer()
            if not self.tooFarAway then
                self:updateParticles()
            end
            
            if self.dockedPlanet then
                self:updateDockingProcedure()
            end
            self:updateBullets()
            self:updateExplosionProcedures()
        end

        enemy.conditionalUpdate = function (self)
            if self.farAway then
                self.foundPlayer = false
            elseif not self.player.gettingDestroyed then
                self.docking = false
            end
            
            if self.returning and self.docked then
                self.tooFarAway = true
            end

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
            
            self.returning = self.player.gettingDestroyed or self.farAway

            if self.player.gettingDestroyed or self.farAway then
                if not self.hasSetSearchState then
                    self.searchingForHomePlanet = true
                    self.hasSetSearchState = true
                end
                self:returnToPlanet(self.planet)
            end
        end

        enemy.update = function (self, index)
            self.angle = calculate.angleLerp(self.angle, self.targetAngle, self.TURN_SPEED)
            self:conditionalUpdate()
            self:unConditionalUpdate()

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
    ---@param homePlanet? table
    ---@param color? table
    ---@param turnSpeedAccuracy? number
    ---@return table
    kamikazeeGunner = function (x, y, radius, player, homePlanet, world, color, turnSpeedAccuracy, angleContextWindowAccuracy, accelAccuracy, targetPointAccuracy, maxSpeedAccuracy)
        local enemy = enemies.kamikazee(x, y, radius, player, homePlanet, world, color, turnSpeedAccuracy, angleContextWindowAccuracy, accelAccuracy, targetPointAccuracy, maxSpeedAccuracy)
        local stationaryGunner = enemies.stationaryGunner(x, y, radius, player, homePlanet, world, color, turnSpeedAccuracy)
        
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

        enemy.stationaryGunner.updateExternalCollisions = function (self)
            -- for _, planet in ipairs(world.planets) do
            --     if calculate.distance(planet.x, planet.y, self.x, self.y) <= planet.radius then
            --         self:destroy()
            --     end
            -- end
            
            for bulletIndex, bullet in ipairs(self.bullets) do
                for _, kamikazee in ipairs(world.kamikazees) do
                    if calculate.distance(bullet.x, bullet.y, kamikazee.x, kamikazee.y) < kamikazee.radius then
                        kamikazee:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end
                
                for _, fighter in ipairs(world.fighters) do
                    if calculate.distance(bullet.x, bullet.y, fighter.x, fighter.y) < fighter.radius and fighter.stationaryGunner ~= self then
                        fighter:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end

                    if calculate.distance(bullet.x, bullet.y, fighter.character.x, fighter.character.y) < fighter.character.radius and fighter.character.stationaryGunner ~= self and fighter.docked then
                        fighter.character:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end

                for _, stGunner in ipairs(world.stationaryGunners) do
                    if calculate.distance(bullet.x, bullet.y, stGunner.x, stGunner.y) < stGunner.radius then
                        stGunner:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end
            end
        end

        enemy.stationaryGunner.update = function (self)
            if not self.tooFarAway then
                if not player.gettingDestroyed then
                    if calculate.angleBetween(self.angle, self.targetAngle) < self.SHOT_RANGE_ANGLE and self.foundPlayer and enemy.shoot then
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
        
        enemy.updateExternalCollisions = function (self, index)
            for bulletIndex, bullet in ipairs(self.bullets) do
                for _, stationaryGunners in ipairs(world.stationaryGunners) do
                    if calculate.distance(bullet.x, bullet.y, stationaryGunners.x, stationaryGunners.y) < stationaryGunners.radius then
                        stationaryGunners:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end

                for _, kamikazee in ipairs(world.kamikazees) do
                    if calculate.distance(bullet.x, bullet.y, kamikazee.x, kamikazee.y) < kamikazee.radius then
                        kamikazee:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end
                
                for _, kamikazeeGunner in ipairs(world.kamikazeeGunners) do
                    if calculate.distance(bullet.x, bullet.y, kamikazeeGunner.x, kamikazeeGunner.y) < kamikazeeGunner.radius then
                        kamikazeeGunner:damage(bullet.damage)
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
            self.angle = calculate.angleLerp(self.angle, self.targetAngle, self.TURN_SPEED)

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

            self:conditionalUpdate()
            self:unConditionalUpdate()
            
            self.stationaryGunner:update()

            if not self.tooFarAway then
                self:updateExternalCollisions(index)
            end
            
            self.stationaryGunner.angle = self.angle
            
            self.stationaryGunner.targetAngle = self.targetAngle

            self.stationaryGunner.foundPlayer = self.foundPlayer
            self.stationaryGunner.fovAngle = self.fovAngle

            self.stationaryGunner.x = self.x
            self.stationaryGunner.y = self.y
            
            if player.modes.character then
                self.player = player.character.player
            elseif player.modes.spacecraft then
                self.player = player.spacecraft.player
            end
            
        end

        return enemy
    end,

    ---@param x number
    ---@param y number
    ---@param radius number
    ---@param player table
    ---@param world table
    ---@param color? table
    ---@param turnSpeedAccuracy? number
    ---@param angleContextWindowAccuracy? number
    ---@param accelAccuracy? number
    ---@param targetPointAccuracy? number
    ---@param maxSpeedAccuracy? number
    ---@return unknown
    fighter = function (x, y, radius, player, homePlanet, world, color, turnSpeedAccuracy, angleContextWindowAccuracy, accelAccuracy, targetPointAccuracy, maxSpeedAccuracy)
        local nearestPlanet = {distance = 0, planet = nil}
        local enemy = enemies.kamikazeeGunner(x, y, radius, player, homePlanet, world, color, turnSpeedAccuracy, angleContextWindowAccuracy, accelAccuracy, targetPointAccuracy, maxSpeedAccuracy)
        
        local shotsPersecond = 4
        local currShotTimer = 0
        local prevShotTimer = 0
        local shotBullet = false

        local characterMoveFunction = function ()
            local enemyAngle = calculate.angle(enemy.character.x, enemy.character.y, enemy.character.planet.x, enemy.character.planet.y)
            local playerAngle = calculate.angle(player.character.player.x, player.character.player.y, enemy.character.planet.x, enemy.character.planet.y)
            local spacecraftAngle = calculate.angle(enemy.x, enemy.y, enemy.character.planet.x, enemy.character.planet.y)
            
            local angle
            
            if enemy.returning and enemy.docked and enemy.planet == enemy.dockedPlanet then
                angle = (((enemy.characterBaseAngle - 180) - enemyAngle) % 360) - 180
            elseif enemy.leavingThePlanet and enemy.docked then
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

            return function ()
                enemy.character.shotBullet = false
                
                local angleDiff = calculate.angleBetweenAPoint(enemy.player.x, enemy.player.y, enemy.character.x, enemy.character.y, enemy.character.planet.x, enemy.character.planet.y)
                
                local angleLimit = (calculate.angle(enemy.character.planet.x, enemy.character.planet.y, enemy.character.x, enemy.character.y) + 270) % 360
                angle = calculate.clamp(calculate.angle(enemy.player.x, enemy.player.y, enemy.character.x, enemy.character.y), math.min(angleLimit, 360 - angleLimit), math.max(angleLimit, 360 - angleLimit))
                
                local shouldShoot = false
                currShotTimer = currShotTimer + DT * shotsPersecond
                if math.floor(currShotTimer) ~= math.floor(prevShotTimer) then
                    prevShotTimer = currShotTimer
                    if not shotBullet then
                        shouldShoot = true
                        shotBullet = true
                    end
                else
                    shotBullet = false
                end
                
                local shoot = not enemy.leavingThePlanet and enemy.docked and shouldShoot and not enemy.returning

                if math.abs(angleDiff) < enemy.character.planet.radius / 1 then
                    return shoot, angle
                end
                return false
            end
        end
        
        enemy.character = characters.player(x, y, 5, {up = characterMoveFunction, down = function () return false end}, nil, color, nil, characterShootFunction())
        enemy.character.horizontal.acceleration = 0.4
        
        enemy.stationaryGunner.removeBullet = function (self, index)
            table.remove(self.bullets, index)
        end
        
        enemy.stationaryGunner.updateBullets = function (self)
            for index, bullet in ipairs(self.bullets) do
                if bullet.dist > calculate.distance(SCREEN_WIDTH, SCREEN_HEIGHT) then
                    self:removeBullet(index)
                else
                    bullet:update()
                end
            end
        end

        enemy.character.addBullet = function (self, angle)
            if not self.gettingDestroyed then
                local bullet = objects.bullet(self.x + math.cos(math.rad(angle)), self.y - math.sin(math.rad(angle)), angle - 90, 3, 5)

                bullet.update = function (b)
                    if self.planet then
                        local d = calculate.distance(b.x, b.y, self.planet.x, self.planet.y)

                        local a = math.rad(calculate.angle(self.planet.x, self.planet.y, self.x, self.y) + 90)

                        local Fx = -self.gravity * math.cos(a) / d^2
                        local Fy = self.gravity * math.sin(a) / d^2
                        
                        b.thrust.x = b.thrust.x + Fx
                        b.thrust.y = b.thrust.y + Fy
                        
                    end
                    b.x = WorldDirection.x + b.x + b.thrust.x
                    b.y = WorldDirection.y + b.y + b.thrust.y
                    
                    b.dist = b.dist + calculate.distance(b.thrust.x, b.thrust.y)
                end

                table.insert(enemy.stationaryGunner.bullets, bullet)
            end
        end

        enemy.safetyDistance = 10
        enemy.divertionDirection = 1
        enemy.dockingDistance = 200
        enemy.dockingSpeed = 3
        enemy.leavingThePlanet = false

        enemy.reverseThruster.particles:setDurationRange(-0.5, 0.5)
        enemy.reverseThruster.particles:setScaleRange(1, 2)
        
        enemy.draw = function (self)
            if self.docked then
                self.character:draw()
            end

            self:drawPlayer()

            if not self.farAway then
                self:drawParticles() 
            end
            self.stationaryGunner:drawBullets()
            
            for checkPointIndex, checkPoint in ipairs(self.homeCheckpoints) do
                love.graphics.setColor(1, 1, 0)
                love.graphics.circle('fill', checkPoint.x, checkPoint.y, 30)
                love.graphics.setColor(0, 0.5, 0.5)
                love.graphics.print(tostring(checkPointIndex), checkPoint.x - 10, checkPoint.y - 10)
            end
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
            
            self.landOnPlayerPlanet = self.player.planet ~= nil and not self.player.gettingDestroyed and calculate.distance(self.x, self.y, self.player.planet.x, self.player.planet.y) - (self.player.planet.radius + self.radius) < self.dockingDistance and not self.docked

            if not self.docked and not self.docking then
                local dx = self.player.x - self.x
                local dy = self.y - self.player.y
                
                if calculate.distance(self.x, self.y, self.player.x, self.player.y) <= self.safetyDistance then
                    self:onBrakesPressed()
                end
                
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
            else
                if self.docked then
                    if not player.spacecraft.player.docked and calculate.distance(player.spacecraft.player.x, player.spacecraft.player.y, self.dockedPlanet.x, self.dockedPlanet.y) - (self.dockedPlanet.radius + player.spacecraft.player.radius) < self.dockingDistance then
                        self.leavingThePlanet = true
                    end
                end
            end
        end

        enemy.updateExternalCollisions = function (self, index)
            for bulletIndex, bullet in ipairs(self.bullets) do
                for _, stationaryGunners in ipairs(world.stationaryGunners) do
                    if calculate.distance(bullet.x, bullet.y, stationaryGunners.x, stationaryGunners.y) < stationaryGunners.radius then
                        stationaryGunners:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end

                for _, kamikazee in ipairs(world.kamikazees) do
                    if calculate.distance(bullet.x, bullet.y, kamikazee.x, kamikazee.y) < kamikazee.radius then
                        kamikazee:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end
                
                for _, kamikazeeGunner in ipairs(world.kamikazeeGunners) do
                    if calculate.distance(bullet.x, bullet.y, kamikazeeGunner.x, kamikazeeGunner.y) < kamikazeeGunner.radius then
                        kamikazeeGunner:damage(bullet.damage)
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
                        kamikazee:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end
                
                for _, kamikazeeGunner in ipairs(world.kamikazeeGunners) do
                    if calculate.distance(bullet.x, bullet.y, kamikazeeGunner.x, kamikazeeGunner.y) < kamikazeeGunner.radius and kamikazeeGunner.stationaryGunner ~= self then
                        kamikazeeGunner:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end

                for _, stationaryGunner in ipairs(world.stationaryGunners) do
                    if calculate.distance(bullet.x, bullet.y, stationaryGunner.x, stationaryGunner.y) < stationaryGunner.radius then
                        stationaryGunner:damage(bullet.damage)
                        self:removeBullet(bulletIndex)
                    end
                end
            end
        end
        
        enemy.updatePlayerDestruction = function (self)
            for index, bullet in ipairs(player.spacecraft.player.bullets) do
                if calculate.distance(bullet.x, bullet.y, self.x, self.y) < self.radius and not self.gettingDestroyed then
                    self:damage(bullet.damage)
                    player.spacecraft.player:removeBullet(index)
                end
                
                if calculate.distance(bullet.x, bullet.y, self.character.x, self.character.y) < self.character.radius + bullet.radius and not self.character.gettingDestroyed then
                    self.character:damage(bullet.damage)
                    player.spacecraft.player:removeBullet(index)
                end
            end
            
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
        
        enemy.conditionalUpdate = function (self)
            self.returning = self.player.gettingDestroyed or self.farAway

            if self.returning then
                self.leavingThePlanet = self.docked and self.planet ~= self.dockedPlanet
                self.foundPlayer = false
            end

            if not self.docked then
                self.foundPlayer = not self.farAway
            else
                if self.character.planet == nil then
                    self.character:setPlanet(self.dockedPlanet)
                end
            end

            if self.leavingThePlanet and player.spacecraft.player.docked then
                self.leavingThePlanet = false
                if self.undocking then
                    self:startDock(player.spacecraft.player.dockedPlanet)
                end
            end

            self.shoot = not (self.docking or self.docked)
            
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

            if not self.player.gettingDestroyed and not self.gettingDestroyed and not self.character.gettingDestroyed and not player.gettingDestroyed and not self.tooFarAway then
                if self.foundPlayer or self.docked then
                    self:attack()
                else
                    self:search()
                end
            end
            
            if self.undocking then
                self:leavePlanet(self.dockedPlanet)
            end

            if self.landOnPlayerPlanet then
                if not self.undocking then
                    self:returnToPlanet(self.player.planet)
                end
            else
                if not self.farAway and self.character.gettingDestroyed then
                    self.docking = false
                end
            end

            if not (self.gettingDestroyed and self.character.gettingDestroyed) and not self.tooFarAway then
                self:updatePlayerDestruction()
            end
            
            if self.player.gettingDestroyed or self.farAway and not self.undocking then
                if not self.hasSetSearchState then
                    self.searchingForHomePlanet = true
                    self.hasSetSearchState = true
                end
                self:returnToPlanet(self.planet)
            end
            
            if self.leavingThePlanet and self.docked and calculate.distance(self.x, self.y, self.character.x, self.character.y) <= self.radius then
                self.undocking = true
                self.chasingPlayer = false
            end
            
            if nearestPlanet.planet ~= nil then
                self.shoot = false
                self.stationaryGunner.shoot = self.shoot
            end
            
            if self.gettingDestroyed and not self.docked then
                self.character:destroy()
            end
            
            if not self.docked then
                self.character.planet = nil

                self.character.x = self.x
                self.character.y = self.y
            else
                self.character.x = self.character.x + WorldDirection.x
                self.character.y = self.character.y + WorldDirection.y
            end

            if player.modes.character then
                self.player = player.character.player
            elseif player.modes.spacecraft then
                self.player = player.spacecraft.player
            end

            if self.docked and not self.farAway and not self.player.gettingDestroyed then
                self.chasingPlayer = true
            end
            
            if not self.tooFarAway then
                self:updateParticles()
            end
            
            if self.dockedPlanet ~= nil then
                self:updateDockingProcedure()
            end
        end

        enemy.unConditionalUpdate = function (self)
            self.stationaryGunner.angle = self.angle
            
            self.stationaryGunner.targetAngle = self.targetAngle

            self.stationaryGunner.foundPlayer = self.foundPlayer
            self.stationaryGunner.fovAngle = self.fovAngle

            self.stationaryGunner.x = self.x
            self.stationaryGunner.y = self.y
            
            self.stationaryGunner:update()
            self.character:updateInput()
            self.character:update()
            
            self.x = self.x + WorldDirection.x
            self.y = self.y + WorldDirection.y
            
            self:movePlayer()
            
            self:updateBullets()
            self:updateExplosionProcedures()
        end

        enemy.update = function (self, index)
            self.angle = calculate.angleLerp(self.angle, self.targetAngle, self.TURN_SPEED)
            
            if self.returning and self.docked then
                self.tooFarAway = true
            end
            
            self:conditionalUpdate()
            self:unConditionalUpdate()
            
            if self.dockedPlanet ~= nil and not self.undocking then
                self:updateDockingProcedure()
            end

            if not self.tooFarAway then
                self:updateExternalCollisions(index)
            end
        end

        return enemy

    end,
}

return enemies