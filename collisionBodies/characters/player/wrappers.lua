local calculate = require 'calculate'

return {
    
    ---@param player table
    ---@param kamikazees table
    ---@param stationaryGunners table
    ---@param kamikazeeGunners table
    ---@param planets table
    ---@param collisionBodies table
    ---@return table
    spacecraft = function (player, kamikazees, stationaryGunners, kamikazeeGunners, planets, collisionBodies)
        local COLLISION_VELOCITY = 100
        local AUTO_DOCKING_DISTANCE = 100
        
        table.insert(collisionBodies, player)
        
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
                for bulletIndex, bullet in ipairs(self.player.bullets) do
                    for _, planet in ipairs(self.planets) do
                        if calculate.distance(planet.x, planet.y, bullet.x, bullet.y) <= planet.radius then
                            table.remove(self.player.bullets, bulletIndex)
                        end
                    end
                end
            end,
            
            updatePlayerInPlanets = function (self, planet)
                local distance = calculate.distance(planet.x, planet.y, self.player.x, self.player.y)
                local touchDown = distance <= planet.radius + self.player.radius
                
                if not self.player.destroyed then
                    self.player:addEmissionCollisionPlanet(planet)

                    local angle = calculate.angle(planet.x, planet.y, self.player.x, self.player.y) % 360
                    local dAngle = math.abs(self.player.angle - angle)

                    if touchDown then
                        if not self.player.docked then
                            if dAngle >= 30 or math.sqrt(self.player.thrust.x^2 + self.player.thrust.y^2) > COLLISION_VELOCITY then
                                self.player:destroy()
                            else
                                self:playerDocked(planet)
                            end
                        end
                    end
                end
            end,

            playerDocked = function (self, planet)
                self.player.docked = true
                self.player.undocked = false
                self.player.docking = false
                self.player.dockedPlanet = planet
            end,

            planetDestroyed = function (self, planet)
                if self.player.dockedPlanet == planet then
                    self.player:undock()
                end
                self.player:removeEmissionCollisionPlanet(planet)
            end,

            draw = function (self)
                love.graphics.setColor(1, 0, 0)
                love.graphics.rectangle('fill', love.graphics.getWidth() - 20, love.graphics.getHeight() - 120, 15, 100)
                love.graphics.setColor(0, 1, 1)
                love.graphics.rectangle('fill', love.graphics.getWidth() - 20, love.graphics.getHeight() - 120, 15, (self.player.forwardThruster.accel / self.player.maxThrusterAccel) * 100)
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