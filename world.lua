require 'os'
local enemies = require 'collisionBodies.characters.enemies'
local ui = require 'ui'
local objects = require 'objects'
local calculate = require 'calculate'
local celestials = require 'collisionBodies.celestials'

local CAMERAFOCUSACCEL = 1

---@param planets table
---@param collisionBodies table
---@param sceneFunc fun(rammers: table, turetts: table, planets: table, astroids: table, collisionBodies: table): table
---@return table
local function WorldWrapper(planets, collisionBodies, sceneFunc)
    local turetts = {}
    local rammers = {}

    local astroids = {}

    local setting = sceneFunc(rammers, turetts, planets, astroids, collisionBodies)
    local player = setting.player
    
    table.insert(rammers, enemies.rammer(love.graphics.getWidth() / 2, love.graphics.getHeight() + 500, 10, player))
    table.insert(rammers, enemies.rammer(love.graphics.getWidth() / 3, love.graphics.getHeight() + 800, 10, player))
    table.insert(turetts, enemies.turret((love.graphics.getWidth() / 2) + 40, (love.graphics.getHeight() / 2) - 40, 10, player))
    table.insert(turetts, enemies.turret((love.graphics.getWidth() / 2) + 140, (love.graphics.getHeight() / 2) - 30, 10, player))

    for _, rammer in ipairs(rammers) do
        table.insert(collisionBodies, rammer)
    end
    for _, turett in ipairs(turetts) do
        table.insert(collisionBodies, turett)
    end

    local CameraRefPrev = {x=player.x, y=player.y}
    local CameraRefCurr = {x=player.x, y=player.y}
    
    local environment = objects.spritesManager()
    environment.addSprite({'images/background.png'}, {x=-200, y=-100}, 0,
    function (spriteInfo)
        spriteInfo.pos.x = spriteInfo.pos.x + WorldDirection.x
        spriteInfo.pos.y = spriteInfo.pos.y + WorldDirection.y
    end)

    return {
        screenScaling = 1,
        setting = setting,
        player = player,
        rammers = rammers,
        turetts = turetts,
        collisionBodies = collisionBodies,
        planets = planets,
        userInterface = ui.userInterface(),
        asteroids = astroids,

        keyPressed = function (self, key)
            if self.setting.keyPressed ~= nil then
                self.setting:keyPressed(key) 
            end
        end,

        mousePressed = function (self, mouseCode)
            if self.setting.mousePressed ~= nil then
                self.setting:mousePressed(mouseCode)
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
                
                if calculate.distance(self.player.x, self.player.y, astroid.x, astroid.y) < (self.player.radius + astroid.radius) - 4 then
                    if not self.player.gettingDestroyed then
                        self.player:destroy()
                        if ListIndex(self.asteroids, astroid) ~= -1 then
                            astroid:destroy()
                        end
                    end
                end

                for _, character in ipairs(self.collisionBodies) do
                    if astroid ~= character then
                        if calculate.distance(character.x, character.y, astroid.x, astroid.y) < (character.radius + astroid.radius) - 4 then
                            if not character.gettingDestroyed then
                                if ListIndex(self.asteroids, astroid) ~= -1 then
                                    astroid:destroy()
                                end
                                if ListIndex(self.collisionBodies, character) ~= -1 then
                                    if character.destroy ~= nil then
                                        character:destroy()
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
                                    astroid:destroy()
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
                        turett:destroy()
                    end
                end
                
                if turett.destroyed then
                    table.remove(self.turetts, index)
                end

                for bulletIndex, bullet in ipairs(turett.bullets) do
                    for _, rammer in ipairs(self.rammers) do
                        if calculate.distance(bullet.x, bullet.y, rammer.x, rammer.y) < rammer.radius then
                            rammer:destroy()
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
                        rammer:destroy()
                    end
                end

                if rammer.destroyed then
                    table.remove(self.rammers, index)
                end

                for _, turett in ipairs(self.turetts) do
                    if calculate.distance(turett.x, turett.y, rammer.x, rammer.y) < turett.radius then
                        rammer:destroy()
                        turett:destroy()
                    end
                end
            end
        end,

        updatePlanets = function (self)
            for _, planet in ipairs(self.planets) do
                planet:update()
                
                for _, turett in ipairs(self.turetts) do
                    for bulletIndex, bullet in ipairs(turett.bullets) do
                        if calculate.distance(planet.x, planet.y, bullet.x, bullet.y) <= planet.radius then
                            table.remove(turett.bullets, bulletIndex)
                        end 
                    end
                end

                if self.setting.updatePlayerInPlanets ~= nil then
                    self.setting:updatePlayerInPlanets(planet) 
                end
            end
        end,
        
        updatePlayer = function (self)
            self.player:update()
            if self.player.gettingDestroyed then
                table.remove(self.collisionBodies, ListIndex(self.collisionBodies, self.player))
            end
            
            if self.player.destroyed then
                STATESMACHINE:setState('restart')
            end

            CameraRefPrev.x, CameraRefPrev.y = self.player.x, self.player.y
            
            if not self.player.gettingDestroyed then
                local dx = CameraRefCurr.x - CameraRefPrev.x
                local dy = CameraRefCurr.y - CameraRefPrev.y

                WorldDirection.x = dx * CAMERAFOCUSACCEL
                WorldDirection.y = dy * CAMERAFOCUSACCEL
            else
                WorldDirection.x, WorldDirection.y = 0, 0
            end
            
            self.player.x = self.player.x + WorldDirection.x
            self.player.y = self.player.y + WorldDirection.y

            CameraRefCurr.x, CameraRefCurr.y = self.player.x, self.player.y
        end,

        draw = function (self)
            love.graphics.translate(-love.graphics.getWidth() * (self.screenScaling - 1) / 2, -love.graphics.getHeight() * (self.screenScaling - 1) / 2)
            love.graphics.scale(self.screenScaling, self.screenScaling)
            
            environment.draw()
            
            self.player:draw()
            
            for _, rammer in ipairs(self.rammers) do rammer:draw() end
            for _, turett in ipairs(self.turetts) do turett:draw() end
            for _, astroid in ipairs(self.asteroids) do astroid:draw() end
            for _, planet in ipairs(self.planets) do planet:draw() end
            self.setting:draw()
            
            self.userInterface:draw()
            logger.write()
            logger:DEBUG()
            

        end,

        update = function (self)
            self.userInterface:update()

            if not STATESMACHINE.pause then
                environment.update()
                
                self:updatePlanets()
                self:updatePlayer()
                self:updateTurrets()
                self:updateRammers()
                self:updateAstroid()

                self.setting:update()
            end
        end
    }
end


return WorldWrapper
