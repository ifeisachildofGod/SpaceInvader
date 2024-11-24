require 'os'
require 'global'
local ui = require 'ui'
local objects = require 'objects'
local calculate = require 'calculate'
local characters = require 'collisionBodies.characters'
local celestials = require 'collisionBodies.celestials'


local function World()
    local player = characters.player(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2, 20, true, nil, 'mouse', nil)
    
    local environment = objects.spritesManager()
    environment.addSprite({'images/background.png'}, {x=-200, y=-100}, 0, function (spriteInfo)
        spriteInfo.pos.x = spriteInfo.pos.x + WorldDirection.x
        spriteInfo.pos.y = spriteInfo.pos.y + WorldDirection.y
    end)
    
    local collisionBodies = {}
    local rammers = {}--{characters.rammer(love.graphics.getWidth() / 2, love.graphics.getHeight() + 500, 10, player), characters.rammer(love.graphics.getWidth() / 3, love.graphics.getHeight() + 800, 10, player)}
    local turetts = {}--{characters.turret((love.graphics.getWidth() / 2) + 40, (love.graphics.getHeight() / 2) - 40, 10, player), characters.turret((love.graphics.getWidth() / 2) + 140, (love.graphics.getHeight() / 2) - 30, 10, player)}
    local planets = {celestials.planet(120, 120, {r=100/255, g=120/255, b=21/255}, 100, collisionBodies)}--, celestials.planet(820, 820, {r=0/255, g=255/255, b=201/255}, 40, collisionBodies, 0.5)}
    
    love.wheelmoved = function (_, dy)
        player:acceleratePlayer(dy)
    end

    for _, rammer in ipairs(rammers) do
        table.insert(collisionBodies, rammer)
    end
    for _, turett in ipairs(turetts) do
        table.insert(collisionBodies, turett)
    end
    for _, planet in ipairs(planets) do
        table.insert(collisionBodies, planet)
    end
    table.insert(collisionBodies, player)

    local userInterface = ui.userInterface()

    return {
        player = player,
        rammers = rammers,
        turetts = turetts,
        collisionBodies = collisionBodies,
        planets = planets,
        asteroids = {},
        
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

        updateAstroid = function (self)
            if #self.asteroids < celestials.ASTROID_MIN_ALLOWED then
                local astroid = celestials.astroid(math.random(love.graphics.getWidth()),
                                        math.random(love.graphics.getHeight()),
                                        {r = math.random(0, 255) / 255, g = math.random(0, 255) / 255, b = math.random(0, 255) / 255},
                                        math.random(celestials.ASTROID_MIN_ALLOWED, celestials.ASTROID_MAX_RAD),
                                        math.random(celestials.ASTROID_MIN_SIDES, celestials.ASTROID_MAX_SIDES),
                                        -tonumber(celestials.ASTROID_MAX_RAD / 5),
                                        tonumber(celestials.ASTROID_MAX_RAD / 5) or celestials.ASTROID_MAX_RAD / 5,
                                        celestials.ASTROID_MAX_VEL,
                                        celestials.ASTROID_DEFAULT_AMT,
                                        self)
                table.insert(self.asteroids, astroid)
                table.insert(self.collisionBodies, astroid)
                
            end

            for _, astroid in ipairs(self.asteroids) do
                astroid:update()
                for _, character in ipairs(self.collisionBodies) do
                    if tostring(astroid) ~= tostring(character) then
                        if calculate.distance(character.x, character.y, astroid.x, astroid.y) < (character.radius + astroid.radius) - 4 then
                            if not character.exploding then
                                if ListIndex(self.asteroids, astroid) ~= -1 then
                                    astroid:explode()
                                end
                                if ListIndex(self.collisionBodies, character) ~= -1 then
                                    if character.explode ~= nil then
                                        character:explode()
                                    else
                                        if astroid.astroidAmt < 2 then
                                            character.radius = character.radius + math.sqrt(astroid.mass)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if character.bullets ~= nil then
                        for bulletIndex, bullet in ipairs(character.bullets) do
                            if calculate.distance(bullet.x, bullet.y, astroid.x, astroid.y) < astroid.radius then
                                if ListIndex(self.asteroids, astroid) ~= -1 then
                                    table.remove(character.bullets, bulletIndex)
                                    astroid:explode()
                                end
                            end
                        end
                    end
                end
            end
        end,
        
        updateTurrets = function (self)
            for index, turett in ipairs(self.turetts) do
                turett:update()
                
                for _, planet in ipairs(self.planets) do
                    if calculate.distance(planet.x, planet.y, turett.x, turett.y) <= planet.radius then
                        turett:explode()
                    end
                end
                
                if turett.exploded then
                    table.remove(self.turetts, index)
                end

                for bulletIndex, bullet in ipairs(turett.bullets) do
                    for _, rammer in ipairs(self.rammers) do
                        if calculate.distance(bullet.x, bullet.y, rammer.x, rammer.y) < rammer.radius then
                            rammer:explode()
                            table.remove(turett.bullets, bulletIndex)
                        end
                    end
                end
            end
        end,
        
        updateRammers = function (self)
            for index, rammer in ipairs(self.rammers) do
                rammer:update()
                
                for _, planet in ipairs(self.planets) do
                    if calculate.distance(planet.x, planet.y, rammer.x, rammer.y) <= planet.radius then
                        rammer:explode()
                    end
                end

                if rammer.exploded then
                    table.remove(self.rammers, index)
                end

                for _, turett in ipairs(self.turetts) do
                    if calculate.distance(turett.x, turett.y, rammer.x, rammer.y) < turett.radius then
                        rammer:explode()
                        turett:explode()
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

        updatePlanets = function (self)
            for _, planet in ipairs(self.planets) do
                local distance = calculate.distance(planet.x, planet.y, self.player.x, self.player.y)
                local touchDown = distance <= planet.radius + self.player.radius
                
                planet:update()
                
                if not self.player.exploded then
                    self.player:addEmissionCollisionPlanet(planet)

                    local angle = calculate.angle(planet.x, planet.y, self.player.x, self.player.y) % 360
                    local dAngle = math.abs(self.player.angle - angle)

                    if touchDown then
                        if not self.player.docked then
                            if dAngle >= 20 or math.sqrt(self.player.thrust.x^2 + self.player.thrust.y^2) > self.player.COLLISION_VELOCITY then
                                self.player:explode()
                            else
                                self:playerDocked(planet)
                            end
                        end
                    end
                end
                
                for _, turett in ipairs(self.turetts) do
                    for bulletIndex, bullet in ipairs(turett.bullets) do
                        if calculate.distance(planet.x, planet.y, bullet.x, bullet.y) <= planet.radius then
                            table.remove(turett.bullets, bulletIndex)
                        end 
                    end
                end
            end
        end,

        draw = function (self)
            environment.draw()
            
            self.player:draw()
            
            for _, rammer in ipairs(self.rammers) do
                rammer:draw()
            end
            
            for _, turett in ipairs(self.turetts) do
                turett:draw()
            end
            
            for _, astroid in ipairs(self.asteroids) do
                astroid:draw()
            end
            for _, planet in ipairs(self.planets) do
                planet:draw()
            end

            userInterface:draw()
            LOGGER.write()
            
            love.graphics.setColor(1, 0, 0)
            love.graphics.rectangle('fill', love.graphics.getWidth() - 20, love.graphics.getHeight() - 120, 15, 100)
            love.graphics.setColor(0, 1, 1)
            love.graphics.rectangle('fill', love.graphics.getWidth() - 20, love.graphics.getHeight() - 120, 15, (self.player.forwardThruster.accel / self.player.maxThrusterAccel) * 100)

            LOGGER:DEBUG()

        end,

        update = function (self)
            userInterface:update()

            if not STATESMACHINE.pause then
                environment.update()
                
                self:updatePlanets()
                self.player:update()
                if self.player.exploding then
                    table.remove(self.collisionBodies, ListIndex(self.collisionBodies, self.player))
                end
                
                if self.player.exploded then
                    STATESMACHINE:setState('restart')
                end
                self:updatePlayerBullet()

                self:updateTurrets()
                self:updateRammers()
                self:updateAstroid()
            end
        end
    }
end

return World
