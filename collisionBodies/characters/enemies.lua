local calculate = require "calculate"
local characters= require "collisionBodies.characters.players"

return {
    ---@param x number
    ---@param y number
    ---@param radius number
    ---@param player table
    ---@return table
    rammer = function (x, y, radius, player, turnSpeedAccuracy, angleContextWindowAccuracy, accelAccuracy, targetPointAccuracy, maxSpeedAccuracy)
        local defaultAccuracy = 0

        angleContextWindowAccuracy = angleContextWindowAccuracy or defaultAccuracy
        turnSpeedAccuracy = turnSpeedAccuracy or defaultAccuracy
        accelAccuracy = accelAccuracy or defaultAccuracy
        targetPointAccuracy = targetPointAccuracy or defaultAccuracy
        maxSpeedAccuracy = maxSpeedAccuracy or defaultAccuracy

        local enemy = characters.playerVehicle(x, y, radius)

        enemy.player = player
        
        enemy.TURN_SPEED = calculate.interpolation(0.05, 1.5, turnSpeedAccuracy)
        enemy.angleContextWindow = calculate.interpolation(360, 10, angleContextWindowAccuracy)
        enemy.forwardThruster.accel = calculate.interpolation(enemy.forwardThruster.accel, enemy.forwardThruster.accel * 4.5, accelAccuracy)
        enemy.thrust.maxSpeed = calculate.interpolation(100, 10000, maxSpeedAccuracy)
        
        enemy.forwardThruster.particles:setScale(4)
        
        enemy.update = function (self)
            if not self.player.gettingDestroyed and not self.gettingDestroyed then
                local dx = (self.player.x + self.player.thrust.x * DT) - self.x
                local dy = self.y - (self.player.y + self.player.thrust.y * DT)
                
                ---@diagnostic disable-next-line: deprecated
                local angle = math.deg(math.atan2(dy, dx)) - 90
                
                local rad = self.radius * calculate.interpolation(2, 0, targetPointAccuracy)
                local newDY = dy - (math.sin(math.rad(angle + 90)) * rad)
                local newDX = dx + (math.cos(math.rad(angle + 90)) * rad)
                
                ---@diagnostic disable-next-line: deprecated
                angle = math.deg(math.atan2(newDY, newDX)) - 90
                
                self.angle = calculate.angleLerp(self.angle, angle, self.TURN_SPEED)
                if calculate.angleBetween(self.angle, angle) <= self.angleContextWindow then
                    self.forwardThruster.x = math.cos(math.rad(self.angle + 90)) * self.forwardThruster.accel
                    self.forwardThruster.y = -math.sin(math.rad(self.angle + 90)) * self.forwardThruster.accel 
                else
                    self:onBrakesPressed()
                end
                
                self.thrust.x = calculate.clamp(self.thrust.x + self.forwardThruster.x, -self.thrust.maxSpeed, self.thrust.maxSpeed)
                self.thrust.y = calculate.clamp(self.thrust.y + self.forwardThruster.y, -self.thrust.maxSpeed, self.thrust.maxSpeed)

                if calculate.distance(self.x, self.y, self.player.x, self.player.y) < self.player.radius then
                    self:destroy()
                    self.player:destroy()
                end
                
                if self.player.bullets ~= nil then
                    for index, bullet in ipairs(self.player.bullets) do
                        if calculate.distance(bullet.x, bullet.y, self.x, self.y) < self.radius then
                            self:destroy()
                            table.remove(self.player.bullets, index)
                        end
                    end
                end
            end

            self.x = self.x + WorldDirection.x
            self.y = self.y + WorldDirection.y

            self:movePlayer()
            self:updateParticles()
            self:updateBullets()
            self:updateExplosionProcedures()
        end

        return enemy

    end,

    turret = function (x, y, radius, player)
        local enemy = characters.playerVehicle(x, y, radius)
        
        enemy.player = player
        enemy.TURN_SPEED = 0.05
        enemy.MAX_BULLETS_AMT = tonumber(enemy.MAX_BULLETS_AMT / 3)
        enemy.SHOT_RANGE_ANGLE = 45

        enemy.update = function (self)
            if not self.player.gettingDestroyed and not self.gettingDestroyed then
                self:movePlayer(WorldDirection)
                local dx = self.player.x - self.x
                local dy = self.y - self.player.y

                ---@diagnostic disable-next-line: deprecated
                local angle = (math.deg(math.atan2(dy,dx)) - 90) % 360
                self.angle = calculate.angleLerp(self.angle, angle, self.TURN_SPEED)
                
                if angle - self.SHOT_RANGE_ANGLE < self.angle and self.angle < angle + self.SHOT_RANGE_ANGLE then
                    self:addBullet()
                end
                
            end

            for index, bullet in ipairs(self.bullets) do
                if calculate.distance(bullet.x, bullet.y, self.player.x, self.player.y) < self.player.radius then
                    self.player:destroy()
                    table.remove(self.bullets, index)
                end
            end

            if self.player.bullets ~= nil then
                for index, bullet in ipairs(self.player.bullets) do
                    if calculate.distance(bullet.x, bullet.y, self.x, self.y) < self.radius then
                        self:destroy()
                        table.remove(self.player.bullets, index)
                    end
                end
            end
            
            self.x = self.x + WorldDirection.x
            self.y = self.y + WorldDirection.y

            self:updateParticles()
            self:updateBullets()
            self:updateExplosionProcedures()
        end

        return enemy

    end
}