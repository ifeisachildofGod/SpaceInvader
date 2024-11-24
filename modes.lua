local characters = require 'collisionBodies.characters.players'
local calculate = require 'calculate'

return {
    ship = function (rammers, turetts, planets, collisionBodies)
        local player = characters.playerVehicle(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2, 20, nil, 'mouse')
        
        table.insert(collisionBodies, player)

        love.wheelmoved = function (_, dy)
            player:acceleratePlayer(dy)
        end

        return {
            player = player,
            rammers = rammers,
            turetts = turetts,
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
                        if distanceBetweenEnds <= self.player.AUTO_DOCKING_DISTANCE and self.player.dockedPlanet == nil then
                            self.player:startDock(planet)
                        end
                    end
                end
            end,

            keyPressed = function (self, key)
                if key == 'space' then
                    self.player:addBullet()
                end
            end,

            mousePressed = function (self, mouseCode)
                if mouseCode == 1 then
                    self.player:addBullet()
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
                            if dAngle >= 20 or math.sqrt(self.player.thrust.x^2 + self.player.thrust.y^2) > self.player.COLLISION_VELOCITY then
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

    ---@param rammers table
    ---@param turetts table
    ---@param planets table
    ---@param collisionBodies table
    ---@return table
    player = function (rammers, turetts, planets, collisionBodies)
        local player = characters.player(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2, 7, planets[1])

        return {
            player = player,
            rammers = rammers,
            turetts = turetts,
            collisionBodies = collisionBodies,
            planets = planets,

            draw = function (self)

            end,

            update = function (self)

            end
        }
    end

}