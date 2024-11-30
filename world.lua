local ui         = require 'ui'
local Player     = require 'collisionBodies.characters.player.player' 
local enemies    = require 'collisionBodies.characters.enemies'
local objects    = require 'objects'
local calculate  = require 'calculate'
local celestials = require 'collisionBodies.celestials'


---@return table
local function WorldWrapper()
    -- local world = {}

    local stationaryGunners = {}
    local fighters = {}
    local kamikazees = {}
    local kamikazeeGunners = {}
    local astroids = {}
    local collisionBodies = {}
    local planets = {
        celestials.planet(love.graphics.getWidth() / 2, (love.graphics.getHeight() / 2) + 200, {r=100/255, g=120/255, b=21/255}, 50, collisionBodies),
        -- celestials.planet(820, 820, {r=0/255, g=255/255, b=201/255}, 200, collisionBodies)
    }
    
    for _, planet in ipairs(planets) do
        table.insert(collisionBodies, planet)
    end

    local player = Player(kamikazees, stationaryGunners, kamikazeeGunners, astroids, collisionBodies, planets)

    for _, kamikazee in ipairs(kamikazees) do
        table.insert(collisionBodies, kamikazee)
    end
    for _, fighter in ipairs(fighters) do
        table.insert(collisionBodies, fighter)
    end
    for _, stationaryGunner in ipairs(stationaryGunners) do
        table.insert(collisionBodies, stationaryGunner)
    end
    for _, kamikazeeGunner in ipairs(kamikazeeGunners) do
        table.insert(collisionBodies, kamikazeeGunner)
    end

    local environment = objects.spritesManager()
    environment.addSprite({love.graphics.newImage('images/background.png')}, {x=-200, y=-100}, 0)
    
    local world = {
        zoom = nil,
        minZoom = 0.2,
        maxZoom = 2,
        zoomRate = 0.01,
        screenScaling = 1,
        zoomDMouseX = 0,
        zoomDMouseY = 0,
        zoomMousePrevPos = {x=0, y=0},
        pauseScreenPosOffset = {x=0, y=0},
        mouseZoomDistanceX = 0,
        mouseZoomDistanceY = 0,

        player = player,
        kamikazees = kamikazees,
        stationaryGunners = stationaryGunners,
        fighters = fighters,
        kamikazeeGunners = kamikazeeGunners,
        collisionBodies = collisionBodies,
        planets = planets,
        userInterface = ui.userInterface(),
        astroids = astroids,
        destroyedPlanets = {},
        
        nearestOptimizationDistance = 1.5 * math.sqrt(love.graphics.getWidth()^2 + love.graphics.getHeight()^2),
        farthestOptimizationDistance = 2 * math.sqrt(love.graphics.getWidth()^2 + love.graphics.getHeight()^2),
        charactersActivated = false,

        keyPressed = function (self, key)
            if key == 'f' then
                table.insert(self.fighters, enemies.fighter(love.mouse.getX(), love.mouse.getY(), 10, self.player, self, {1, 1, 0}))
            elseif key == 'c' then
                table.insert(self.kamikazeeGunners, enemies.kamikazeeGunner(love.mouse.getX(), love.mouse.getY(), 10, self.player, self, {1, 0, 0}))
            elseif key == 'r' then
                table.insert(self.kamikazees, enemies.kamikazee(love.mouse.getX(), love.mouse.getY(), 10, self.player, self, {0, 1, 0}))
            elseif key == 't' then
                table.insert(self.stationaryGunners, enemies.stationaryGunner(love.mouse.getX(), love.mouse.getY(), 10, self.player, self, {0, 0, 1}))
            elseif key == 'q' then
                self.charactersActivated = not self.charactersActivated
            end
        end,

        mousePressed = function (self, mouseCode)
            self.player:mousePressed(mouseCode)
        end,
        
        updateAstroid = function (self)
            if #self.astroids < celestials.ASTROID_MIN_ALLOWED then
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
                table.insert(self.astroids, astroid)
                table.insert(self.collisionBodies, astroid)
                
            end

            for _, astroid in ipairs(self.astroids) do
                astroid.farAway = calculate.distance(astroid.x, astroid.y, self.player.player.x, self.player.player.y) > self.nearestOptimizationDistance
                astroid.tooFarAway = calculate.distance(astroid.x, astroid.y, self.player.player.x, self.player.player.y) > self.farthestOptimizationDistance

                astroid:update()
                if not astroid.farAway then
                    self.player:astroidUpdate(astroid) 
                end

                for _, character in ipairs(self.collisionBodies) do
                    if astroid ~= character and calculate.distance(character.x, character.y, astroid.x, astroid.y) < (character.radius + astroid.radius) - 4 and not character.gettingDestroyed then
                        if ListIndex(self.astroids, astroid) ~= -1 and (character.mass - astroid.mass >= 0 or character.planet ~= nil) then
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

                    if character.bullets ~= nil then
                        for bulletIndex, bullet in ipairs(character.bullets) do
                            if calculate.distance(bullet.x, bullet.y, astroid.x, astroid.y) < astroid.radius and ListIndex(self.astroids, astroid) ~= -1 then
                                table.remove(character.bullets, bulletIndex)
                                astroid:destroy()
                            end
                        end
                    end
                end
            end
        end,

        updatePlanets = function (self)
            for _, planet in ipairs(self.planets) do
                planet.farAway = calculate.distance(planet.x, planet.y, self.player.player.x, self.player.player.y) > self.nearestOptimizationDistance
                planet.tooFarAway = calculate.distance(planet.x, planet.y, self.player.player.x, self.player.player.y) > self.farthestOptimizationDistance
                planet:update()

                for _, body in ipairs(self.collisionBodies) do
                    if body ~= planet and body.planet ~= nil and calculate.distance(body.x, body.y, planet.x, planet.y) < (body.radius + planet.radius) then
                        local destroyedPlanet = (body.mass - planet.mass) >= 20 and planet or body
                        table.insert(self.destroyedPlanets, destroyedPlanet)
                    end
                end
                
                for _, stationaryGunner in ipairs(self.stationaryGunners) do
                    for bulletIndex, bullet in ipairs(stationaryGunner.bullets) do
                        if calculate.distance(planet.x, planet.y, bullet.x, bullet.y) <= planet.radius then
                            table.remove(stationaryGunner.bullets, bulletIndex)
                        end 
                    end
                end
                
                for _, kamikazeeGunner in ipairs(self.kamikazeeGunners) do
                    for bulletIndex, bullet in ipairs(kamikazeeGunner.stationaryGunner.bullets) do
                        if calculate.distance(planet.x, planet.y, bullet.x, bullet.y) <= planet.radius then
                            table.remove(kamikazeeGunner.stationaryGunner.bullets, bulletIndex)
                        end 
                    end
                end
                
                for _, fighter in ipairs(self.fighters) do
                    for bulletIndex, bullet in ipairs(fighter.stationaryGunner.bullets) do
                        if calculate.distance(planet.x, planet.y, bullet.x, bullet.y) <= planet.radius then
                            table.remove(fighter.stationaryGunner.bullets, bulletIndex)
                        end 
                    end
                end
                
                self.player:updatePlayerInPlanets(planet)
            end
            
            for _, destroyedPlanet in ipairs(self.destroyedPlanets) do
                local astroid = celestials.astroid(
                        destroyedPlanet.x,
                        destroyedPlanet.y,
                        destroyedPlanet.color,
                        destroyedPlanet.radius,
                        200,
                        math.floor(-destroyedPlanet.radius / 5),
                        math.ceil(destroyedPlanet.radius / 5),
                        celestials.ASTROID_MAX_VEL,
                        celestials.ASTROID_DEFAULT_AMT,
                        self,
                        90
                    )
                
                table.insert(self.astroids, astroid)
                table.insert(self.collisionBodies, astroid)
                
                astroid:destroy()
                
                self.player:planetDestroyed(destroyedPlanet)

                table.remove(self.planets, ListIndex(self.planets, destroyedPlanet))
                table.remove(self.collisionBodies, ListIndex(self.collisionBodies, destroyedPlanet))
            end
            
            self.destroyedPlanets = {}
        end,
        
        drawHandler = function (drawables)
            for _, character in ipairs(drawables) do
                -- local left = character.x - character.radius
                -- local right = character.x + character.radius
                -- local top = character.y - character.radius
                -- local bottom = character.y + character.radius

                -- local xComparison = (left < 0 and 0 < right) or (character.radius < right and left < love.graphics.getWidth())
                -- local yComparison = (top < 0 and 0 < bottom) or (character.radius < bottom and top < love.graphics.getHeight())
                
                -- if xComparison and yComparison then
                --     character:draw()
                -- end
                character:draw()
            end
            
        end,
        
        updateHandler = function (self, updatables)
            for index, character in ipairs(updatables) do
                character.farAway = calculate.distance(character.x, character.y, self.player.player.x, self.player.player.y) > self.nearestOptimizationDistance
                character.tooFarAway = calculate.distance(character.x, character.y, self.player.player.x, self.player.player.y) > self.farthestOptimizationDistance
                character:update(index)
            end
        end,

        draw = function (self)
            if STATESMACHINE.pause then
                love.graphics.translate(self.pauseScreenPosOffset.x, self.pauseScreenPosOffset.y)
                love.graphics.translate(-(self.mouseZoomDistanceX - self.pauseScreenPosOffset.x) * (self.screenScaling - 1),  -(self.mouseZoomDistanceY - self.pauseScreenPosOffset.y) * (self.screenScaling - 1))
                love.graphics.scale(self.screenScaling, self.screenScaling)
            end
            environment.draw()

            self.drawHandler(self.kamikazees)
            self.drawHandler(self.stationaryGunners)
            self.drawHandler(self.astroids)
            self.drawHandler(self.planets)
            self.drawHandler(self.kamikazeeGunners)
            self.drawHandler(self.fighters)
            
            self.player:draw()
            
            self.userInterface:draw()
            logger.write()
            logger:DEBUG()
        end,

        update = function (self)
            self.userInterface:update()

            if not STATESMACHINE.pause then
                environment.update()
                
                self:updatePlanets()

                if self.charactersActivated or not DEBUGGING then
                    self:updateHandler(self.stationaryGunners)
                    self:updateHandler(self.fighters)
                    self:updateHandler(self.kamikazees)
                    self:updateHandler(self.kamikazeeGunners)
                else
                    for _, kamikazee in ipairs(self.kamikazees) do
                        kamikazee.x = kamikazee.x + WorldDirection.x
                        kamikazee.y = kamikazee.y + WorldDirection.y
                    end
                    
                    for _, stationaryGunner in ipairs(self.stationaryGunners) do
                        stationaryGunner.x = stationaryGunner.x + WorldDirection.x
                        stationaryGunner.y = stationaryGunner.y + WorldDirection.y
                        
                        for _, bullet in ipairs(stationaryGunner.bullets) do
                            bullet.x = bullet.x + WorldDirection.x
                            bullet.y = bullet.y + WorldDirection.y
                        end
                    end
                    
                    for _, kamikazeeGunner in ipairs(self.kamikazeeGunners) do
                        kamikazeeGunner.x = kamikazeeGunner.x + WorldDirection.x
                        kamikazeeGunner.y = kamikazeeGunner.y + WorldDirection.y

                        for _, bullet in ipairs(kamikazeeGunner.bullets) do
                            bullet.x = bullet.x + WorldDirection.x
                            bullet.y = bullet.y + WorldDirection.y
                        end
                    end
                    
                    for _, fighter in ipairs(self.fighters) do
                        fighter.x = fighter.x + WorldDirection.x
                        fighter.y = fighter.y + WorldDirection.y

                        fighter.character.x = fighter.character.x + WorldDirection.x
                        fighter.character.y = fighter.character.y + WorldDirection.y

                        for _, bullet in ipairs(fighter.bullets) do
                            bullet.x = bullet.x + WorldDirection.x
                            bullet.y = bullet.y + WorldDirection.y
                        end
                    end
                end
                self:updateAstroid()

                self.player:update()
                
                self.mouseZoomDistanceX = love.mouse.getX() - love.graphics.getWidth() / 2
                self.mouseZoomDistanceY = love.mouse.getY() - love.graphics.getHeight() / 2
            else
                
                if love.mouse.isDown(1) then
                    self.zoomDMouseX = love.mouse.getX() - self.zoomMousePrevPos.x
                    self.zoomDMouseY = love.mouse.getY() - self.zoomMousePrevPos.y

                    self.pauseScreenPosOffset.x = self.pauseScreenPosOffset.x + self.zoomDMouseX
                    self.pauseScreenPosOffset.y = self.pauseScreenPosOffset.y + self.zoomDMouseY
                end
                
                self.zoomMousePrevPos.x = love.mouse.getX()
                self.zoomMousePrevPos.y = love.mouse.getY()
            end
        end
    }
    
    love.wheelmoved = function (_, dy)
        if STATESMACHINE.pause then
            if world.zoom == nil then
                world.zoom = 0.5
            end
            world.zoom = calculate.clamp(world.zoom + dy * world.zoomRate, 0, 1)
            world.screenScaling = calculate.interpolation(world.minZoom, world.maxZoom, world.zoom)
            
            if math.abs((world.zoom * 2) + 1) ~= 1 then
                world.mouseZoomDistanceX = calculate.lerp(world.mouseZoomDistanceX, love.mouse.getX(), 0.2)
                world.mouseZoomDistanceY = calculate.lerp(world.mouseZoomDistanceY, love.mouse.getY(), 0.2)
            end
        else
            if world.player.modes.spacecraft then
                world.player.spacecraft.player:acceleratePlayer(dy) 
            end 
        end
    end

    return world
end


return WorldWrapper
