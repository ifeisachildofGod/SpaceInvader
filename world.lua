local ui           =   require 'ui'
local list         =   require 'list'
local Player       =   require 'collisionBodies.characters.player.player' 
local enemies      =   require 'collisionBodies.characters.enemies'
local objects      =   require 'objects'
local calculate    =   require 'calculate'
local celestials   =   require 'collisionBodies.celestials'


---@return table
local function WorldWrapper()
    local world = {}

    local stationaryGunners = {}
    local fighters = {}
    local kamikazees = {}
    local kamikazeeGunners = {}
    local astroids = {}
    local collisionBodies = {}

    local planets = {
        celestials.planet(SCREEN_WIDTH / 2, (SCREEN_HEIGHT / 2) + 4000 + 50, {r=100/255, g=120/255, b=21/255}, 4000, collisionBodies),
        -- celestials.planet(820, 820, {r=0/255, g=255/255, b=201/255}, 200, collisionBodies)
    }

    local player = Player(kamikazees, stationaryGunners, kamikazeeGunners, astroids, collisionBodies, planets)
    

    local environment = objects.spritesManager()
    environment.addSprite({love.graphics.newImage('images/background.png')}, {x=-200, y=-100}, 0)
    
    for _ = 1, 10, 1 do
        environment.addSprite({love.graphics.newImage('images/background.png')}, {x=-math.random(-50000, 50000), y=-math.random(-50000, 50000)}, 0)
    end

    world = {
        zoom = nil,
        minZoom = 0.001,
        maxZoom = 5,
        zoomRate = 0.01,
        screenScaling = 1,
        zoomDMouseX = 0,
        zoomDMouseY = 0,
        zoomMousePrevPos = {x=0, y=0},
        pauseScreenPosOffset = {x=0, y=0},
        origMouseX = love.mouse.getX(),
        origMouseY = love.mouse.getY(),
        mouseZoomDistanceX = love.mouse.getX() - SCREEN_WIDTH / 2,
        mouseZoomDistanceY = love.mouse.getY() - SCREEN_HEIGHT / 2,

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
        totalWorldOffset = {x = 0, y = 0},
        
        nearestOptimizationDistance = 5 * math.sqrt(SCREEN_WIDTH^2 + SCREEN_HEIGHT^2),
        farthestOptimizationDistance = 6 * math.sqrt(SCREEN_WIDTH^2 + SCREEN_HEIGHT^2),
        charactersActivated = false,

        keyPressed = function (self, key)
            if DEBUGGING then
                local x = love.mouse.getX()
                local y = love.mouse.getY()

                if key == 'f' then
                    table.insert(self.fighters, enemies.fighter(x, y, 10, self.player, planets[1], self, {1, 1, 0}))
                elseif key == 'c' then
                    table.insert(self.kamikazeeGunners, enemies.kamikazeeGunner(x, y, 10, self.player, planets[1], self, {1, 0, 0}))
                elseif key == 'r' then
                    table.insert(self.kamikazees, enemies.kamikazee(x, y, 10, self.player, planets[1], self, {0, 1, 0}))
                elseif key == 't' then
                    table.insert(self.stationaryGunners, enemies.stationaryGunner(x, y, 10, self.player, planets[1], self, {0, 0, 1}))
                elseif key == 'q' then
                    self.charactersActivated = not self.charactersActivated
                elseif key == 'escape' then
                    if self.player.gettingDestroyed then
                        STATESMACHINE:setState('restart')
                    end
                end
            end
        end,

        mousePressed = function (self, mouseCode)
            self.player:mousePressed(mouseCode)
        end,
        
        updateCharacterInPlanets = function (character, planet)
            if not character.docked and not character.gettingDestroyed then
                local touchDown = calculate.distance(planet.x, planet.y, character.x, character.y) < planet.radius + character.radius
                character:addEmissionCollisionPlanet(planet)
                
                if touchDown then
                    local angle = calculate.angle(planet.x, planet.y, character.x, character.y)
                    local dAngle = math.abs(calculate.angleBetween(character.angle, angle))

                    local g = calculate.GRAVITATIONAL_CONSTANT * planet.mass / planet.radius^2
                    local escapeVel = math.sqrt(2 * planet.radius * g)
                    
                    if dAngle <= 20 and math.sqrt(character.thrust.x^2 + character.thrust.y^2) < escapeVel then
                        character:dock(planet)
                    else
                        character:destroy()
                    end
                end
            end
        end,

        updateAstroid = function (self)
            if #self.astroids < celestials.ASTROID_MIN_ALLOWED then
                local astroid = celestials.astroid(math.random(SCREEN_WIDTH),
                                        math.random(SCREEN_HEIGHT),
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
                    if astroid ~= character and character.mass ~= nil and calculate.distance(character.x, character.y, astroid.x, astroid.y) < (character.radius + astroid.radius) - 4 and not character.gettingDestroyed then
                        if list.index(self.astroids, astroid) ~= -1 and (character.mass - astroid.mass >= 0 or character.planet ~= nil) then
                            astroid:destroy()
                        end
                        if list.index(self.collisionBodies, character) ~= -1 then
                            if type(character.damage) == "function" then
                                character:damage(astroid.radius / 10)
                            elseif character.damage == nil then
                                if astroid.astroidAmt < 2 then
                                    character.radius = character.radius + math.sqrt(astroid.mass)
                                end
                            end
                        end
                    end

                    if character.bullets ~= nil then
                        for bulletIndex, bullet in ipairs(character.bullets) do
                            if calculate.distance(bullet.x, bullet.y, astroid.x, astroid.y) < astroid.radius and list.index(self.astroids, astroid) ~= -1 then
                                character:removeBullet(bulletIndex)
                                astroid:destroy()
                            end
                        end
                    end
                end
            end
        end,

        updatePlanets = function (self)
            for _, planet in ipairs(self.planets) do
                planet.astroBodies = self.collisionBodies

                planet.farAway = calculate.distance(planet.x, planet.y, self.player.player.x, self.player.player.y) - (self.player.player.radius + planet.radius) > self.nearestOptimizationDistance
                planet.tooFarAway = calculate.distance(planet.x, planet.y, self.player.player.x, self.player.player.y) - (self.player.player.radius + planet.radius) > self.farthestOptimizationDistance
                planet:update()

                for _, body in ipairs(list.add(self.astroids, self.planets)) do
                    if body ~= planet and body.planet ~= nil and calculate.distance(body.x, body.y, planet.x, planet.y) < (body.radius + planet.radius) then
                        local destroyedPlanet = (body.mass - planet.mass) >= 20 and planet or body
                        table.insert(self.destroyedPlanets, destroyedPlanet)
                    end
                end
                
                for _, kamikazee in ipairs(self.kamikazees) do
                    self.updateCharacterInPlanets(kamikazee, planet)
                end

                for _, stationaryGunner in ipairs(self.stationaryGunners) do
                    self.updateCharacterInPlanets(stationaryGunner, planet)
                    for bulletIndex, bullet in ipairs(stationaryGunner.bullets) do
                        if calculate.distance(planet.x, planet.y, bullet.x, bullet.y) <= planet.radius then
                            stationaryGunner:removeBullet(bulletIndex)
                        end 
                    end
                end
                
                for _, kamikazeeGunner in ipairs(self.kamikazeeGunners) do
                    self.updateCharacterInPlanets(kamikazeeGunner, planet)
                    for bulletIndex, bullet in ipairs(kamikazeeGunner.stationaryGunner.bullets) do
                        if calculate.distance(planet.x, planet.y, bullet.x, bullet.y) <= planet.radius then
                            kamikazeeGunner.stationaryGunner:removeBullet(bulletIndex)
                        end 
                    end
                end
                
                for _, fighter in ipairs(self.fighters) do
                    self.updateCharacterInPlanets(fighter, planet)
                    for bulletIndex, bullet in ipairs(fighter.stationaryGunner.bullets) do
                        if calculate.distance(planet.x, planet.y, bullet.x, bullet.y) <= planet.radius then
                            fighter.stationaryGunner:removeBullet(bulletIndex)
                        end 
                    end
                end
                
                self.updateCharacterInPlanets(self.player.spacecraft.player, planet)
                -- self.player:updatePlayerInPlanets(planet)
            end
            -- logger.log(#self.stationaryGunners)
            
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

                table.remove(self.planets, list.index(self.planets, destroyedPlanet))
                table.remove(self.collisionBodies, list.index(self.collisionBodies, destroyedPlanet))
            end
            
            self.destroyedPlanets = {}
        end,
        
        drawHandler = function (drawables)
            for _, character in ipairs(drawables) do
                -- local left = character.x - character.radius
                -- local right = character.x + character.radius
                -- local top = character.y - character.radius
                -- local bottom = character.y + character.radius

                -- local xComparison = (left < 0 and 0 < right) or (character.radius < right and left < SCREEN_WIDTH)
                -- local yComparison = (top < 0 and 0 < bottom) or (character.radius < bottom and top < SCREEN_HEIGHT)
                
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
            if STATESMACHINE.pause or (DEBUGGING and self.player.gettingDestroyed) then
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

            love.graphics.setLineWidth(1)
            love.graphics.setColor(1, 1, 1)
            if STATESMACHINE.pause or (DEBUGGING and self.player.gettingDestroyed) then
                love.graphics.rectangle('fill', calculate.clamp(SCREEN_WIDTH / 2 + self.totalWorldOffset.x, 0, SCREEN_WIDTH - 20), calculate.clamp(SCREEN_HEIGHT / 2 + self.totalWorldOffset.y, 0, SCREEN_HEIGHT - 20), 20, 20)
            end
        end,

        update = function (self)
            self.collisionBodies = list.add(self.stationaryGunners, self.kamikazeeGunners, self.fighters, self.kamikazees, self.astroids, self.planets, {self.player.spacecraft.player}, self.player.spacecraft.player.bullets)
            
            self.userInterface:update()

            if not STATESMACHINE.pause then
                self.totalWorldOffset.x = self.totalWorldOffset.x + WorldDirection.x
                self.totalWorldOffset.y = self.totalWorldOffset.y + WorldDirection.y

                environment.update()
                
                self.player:update()

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

                        for _, bullet in ipairs(fighter.stationaryGunner.bullets) do
                            bullet.x = bullet.x + WorldDirection.x
                            bullet.y = bullet.y + WorldDirection.y
                        end
                    end
                end
                self:updateAstroid()

                -- self.mouseZoomDistanceX = love.mouse.getX() - SCREEN_WIDTH / 2
                -- self.mouseZoomDistanceY = love.mouse.getY() - SCREEN_HEIGHT / 2
            end

            if STATESMACHINE.pause or (DEBUGGING and self.player.gettingDestroyed) then
                if love.mouse.isDown(1) then
                    self.zoomDMouseX = (love.mouse.getX() - self.zoomMousePrevPos.x) / self.screenScaling
                    self.zoomDMouseY = (love.mouse.getY() - self.zoomMousePrevPos.y) / self.screenScaling

                    self.pauseScreenPosOffset.x = self.pauseScreenPosOffset.x + self.zoomDMouseX
                    self.pauseScreenPosOffset.y = self.pauseScreenPosOffset.y + self.zoomDMouseY
                end
                
                self.zoomMousePrevPos.x = love.mouse.getX()
                self.zoomMousePrevPos.y = love.mouse.getY()
            end
        end
    }
    
    local KA = 30
    local KGA = 3
    local SA = 3
    local FA = 3
    
    for _ = 1, 3, 1 do
        local P = celestials.planet(
            math.random(-50000, 50000),
            math.random(-50000, 50000),
            {
                r=math.random(0, 255)/255,
                g=math.random(0, 255)/255,
                b=math.random(0, 255)/255
            },
            math.random(500, 5000),
            collisionBodies--,
            -- {x = math.random(0, 200), y = math.random(0, 200)}
        )

        for kI = 1, KA, 1 do
            local ang = kI * 360 / KA
            local dx, dy = calculate.direction(ang)

           table.insert(kamikazees, enemies.kamikazee(P.x + (dx * P.radius * 1.5), P.y + (dy * P.radius * 1.5), 10, player, P, world, {0, 1, 0}))
        end

        
        for kgI = 1, KGA, 1 do
            local ang = (360 / KA / 2) + (kgI * 360 / KGA)
            local dx, dy = calculate.direction(ang)

           table.insert(kamikazeeGunners, enemies.kamikazeeGunner(P.x + (dx * P.radius * 1.5), P.y + (dy * P.radius * 1.5), 10, player, P, world, {1, 0, 0}))
        end

        for sI = 1, SA, 1 do
            local ang = (360 / KGA / 2) + (360 / KA / 2) + (sI * 360 / SA)
            local dx, dy = calculate.direction(ang)

           table.insert(stationaryGunners, enemies.stationaryGunner(P.x + (dx * P.radius * 1.5), P.y + (dy * P.radius * 1.5), 10, player, P, world, {0, 0, 1}))
        end

        for fI = 1, FA, 1 do
            local ang = (360 / SA / 2) + (360 / KGA / 2) + (360 / KA / 2) + (fI * 360 / FA)
            local dx, dy = calculate.direction(ang)

           table.insert(fighters, enemies.fighter(P.x + (dx * P.radius * 1.5), P.y + (dy * P.radius * 1.5), 10, player, P, world, {0, 1, 1}))
        end
        

        table.insert(planets, P)
    end

    love.wheelmoved = function (_, dy)
        if STATESMACHINE.pause or (DEBUGGING and world.player.gettingDestroyed) then
            if world.zoom == nil then
                world.zoom = 0.5
            end
            world.zoom = calculate.clamp(world.zoom + dy * world.zoomRate, 0, 1)
            world.screenScaling = calculate.interpolation(world.minZoom, world.maxZoom, world.zoom)
            
            if math.abs((world.zoom * 2) - 1) ~= 1 then
                world.mouseZoomDistanceX = calculate.lerp(world.mouseZoomDistanceX, love.mouse.getX(), 0.5)
                world.mouseZoomDistanceY = calculate.lerp(world.mouseZoomDistanceY, love.mouse.getY(), 0.5)
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
