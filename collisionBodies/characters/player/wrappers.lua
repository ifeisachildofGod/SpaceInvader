local calculate   =   require 'calculate'

return {
    
    ---@param player table
    ---@param kamikazees table
    ---@param stationaryGunners table
    ---@param kamikazeeGunners table
    ---@param planets table
    ---@param collisionBodies table
    ---@return table
    spacecraft = function (player, kamikazees, stationaryGunners, kamikazeeGunners, planets, collisionBodies)
        local AUTO_DOCKING_DISTANCE = 100
        
        return {
            player = player,
            kamikazees = kamikazees,
            stationaryGunners = stationaryGunners,
            kamikazeeGunners = kamikazeeGunners,
            collisionBodies = collisionBodies,
            planets = planets,
            
            updatePlayerAutoDocking = function (self)
                if self.player.undocked then
                    for _, planet in ipairs(self.planets) do
                        local playerPlanetAngle = calculate.angle(planet.x, planet.y, self.player.x, self.player.y) - 90
                        local planetPlayerAngle = calculate.angle(planet.x, planet.y, self.player.x, self.player.y) + 90
                        local distanceBetweenEnds = calculate.distance(planet.x + math.cos(math.rad(planetPlayerAngle)) * planet.radius,
                                                                planet.y - math.sin(math.rad(planetPlayerAngle)) * planet.radius,
                                                                self.player.x + math.cos(math.rad(playerPlanetAngle)) * self.player.radius,
                                                                self.player.y - math.sin(math.rad(playerPlanetAngle)) * self.player.radius)
                        if distanceBetweenEnds <= AUTO_DOCKING_DISTANCE and self.player.dockedPlanet == nil then
                            self.player:startDock(planet)
                        end
                    end
                end
            end,

            updatePlayerBullet = function (self)
                for index, bullet in ipairs(self.player.bullets) do
                    for _, planet in ipairs(self.planets) do
                        if calculate.distance(planet.x, planet.y, bullet.x, bullet.y) <= planet.radius then
                            self.player:removeBullet(index)
                        end
                    end
                end
            end,

            planetDestroyed = function (self, planet)
                if self.player.dockedPlanet == planet then
                    self.player:undock()
                end
                self.player:removeEmissionCollisionPlanet(planet)
            end,

            draw = function (self)
                love.graphics.setColor(1, 0, 0)
                love.graphics.rectangle('fill', SCREEN_WIDTH - 20, SCREEN_HEIGHT - 120, 15, 100)
                love.graphics.setColor(0, 1, 1)
                love.graphics.rectangle('fill', SCREEN_WIDTH - 20, SCREEN_HEIGHT - 120, 15, (self.player.forwardThruster.accel / self.player.maxThrusterAccel) * 100)
            end,

            update = function (self)
                self:updatePlayerBullet()
            end
        }
    end,

    ---@param player table
    ---@param kamikazees table
    ---@param kamikazeeGunners table
    ---@param stationaryGunners table
    ---@param planets table
    ---@param collisionBodies table
    ---@return table
    character = function (player, kamikazees, stationaryGunners, kamikazeeGunners, planets, collisionBodies)
        

        return {
            player = player,
            kamikazees = kamikazees,
            stationaryGunners = stationaryGunners,
            kamikazeeGunners = kamikazeeGunners,
            collisionBodies = collisionBodies,
            planets = planets,
            
            draw = function (self)

            end,
            
            planetDestroyed = function (self, planet)
                if self.player.planet == planet then
                    self.player.planet = nil 
                end
            end,

            update = function (self)
                if not self.player.onTheGround then
                    for _, planet in ipairs(self.planets) do
                        if not planet.farAway then
                            local Fx, Fy = calculate.twoBodyVector(planet, self.player)
    
                            self.player.thrust.x = self.player.thrust.x + Fx
                            self.player.thrust.y = self.player.thrust.y + Fy
                            
                            self.player.x = self.player.x + self.player.thrust.x * DT
                            self.player.y = self.player.y + self.player.thrust.y * DT
    
                            if self.player.inTheAir and calculate.distance(self.player.x, self.player.y, planet.x, planet.y) - (self.player.radius + planet.radius) <= 0 then
                                self.player.onTheGround = true
                                self.player.inTheAir = false
                                self.player:setPlanet(planet)
                                self.player.vertical.velocity = 0
                                self.player.vertical.acceleration = 0
                                self.player.vertical.displacement = 0
                            end 
                        end
                    end
                end
            end
        }
    end

}