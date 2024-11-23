require 'os'
require 'global'

math.randomseed(os.time())

local Player = require 'player'

local Enemies = require 'enemy'
local Rammer, Turett = Enemies[1], Enemies[2]

local Astroid = require 'astroid'
local UserInterface = require 'ui'.ui
local Planet = require 'planet'

--- Sprite
--- @param frames table This could a list of file paths or a list of love-images
--- @param pos table This is the info concerning the x, y and rotational data of the sprite {x = 0, y = 0, r? = 0}
--- @param fps number How fast the frames go
--- @param updateFunction? fun(spriteInfo: table) How thw sprite interacts with itself
--- @param beforeAnimation? fun(spriteInfo: table) Anything drawing related that occurs before the main animations
--- @param afterAnimation? fun(spriteInfo: table) Anything drawing related that occurs after the main animations
--- @return table
local function Sprite(frames, pos, fps, updateFunction, beforeAnimation, afterAnimation)
    local spriteInfo = {frames=frames, pos=pos, fps=fps, frameIndex=1, updateFunction=updateFunction, before=beforeAnimation, after=afterAnimation}
    for frameIndex, _ in ipairs(spriteInfo.frames) do
        if type(spriteInfo.frames[frameIndex]) == "string" then
            spriteInfo.frames[frameIndex] = love.graphics.newImage(spriteInfo.frames[frameIndex])
        end
    end

    spriteInfo.draw = function (self)
        if self.before ~= nil then
            self:before()
        end

        local finalFrames = self.frames
        local position = self.pos

        if #finalFrames then
            local frameFPS = self.fps

            self.frameIndex = (self.frameIndex + (DT * frameFPS)) % (#finalFrames + 1)
            
            local frame = finalFrames[math.floor(self.frameIndex)]
            love.graphics.draw(frame, position.x, position.y, position.r or 0)
        else
            love.graphics.draw(finalFrames[1], position.x, position.y, position.r or 0)
        end
        
        if self.after ~= nil then
            self:after()
        end
    end

    spriteInfo.update = function(self)
        if self.updateFunction ~= nil then
            self:updateFunction()
        end
    end

    return spriteInfo
end

local function Environment ()
    -- sprite = {frames={f1, f2, f3}, pos={x, y, r}, fps, frameIndex, update?=func(sprite), before?=func(sprite), after?=func(sprite)}
    local sprites = {}

    return {
        draw = function ()
            for _, sprite in ipairs(sprites) do
                sprite:draw()
            end
        end,
        
        update = function ()
            for _, sprite in ipairs(sprites) do
                sprite:update()
            end
        end,

        --- Adding a sprite to the environment
        --- @param frames table This could a list of file paths or a list of love-images
        --- @param posInfo table This is the info concerning the x, y and rotational data of the sprite {x = 0, y = 0, r? = 0}
        --- @param fps number How fast the frames go
        --- @param update? fun(spriteInfo: table) How thw sprite interacts with itself
        --- @param beforeAnimation? fun(spriteInfo: table) Anything drawing related that occurs before the main animations
        --- @param afterAnimation? fun(spriteInfo: table) Anything drawing related that occurs after the main animations
        addSprite = function (frames, posInfo, fps, update, beforeAnimation, afterAnimation)
            table.insert(sprites, Sprite(frames, posInfo, fps, update, beforeAnimation, afterAnimation))
        end

    }
end

local function World()
    local player = Player(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2, 20, true, nil, 'mouse', nil)
    
    local environment = Environment()
    environment.addSprite({'background.png'}, {x=-200, y=-100}, 0, function (spriteInfo)
        spriteInfo.pos.x = spriteInfo.pos.x + worldDirection.x
        spriteInfo.pos.y = spriteInfo.pos.y + worldDirection.y
    end)
    
    local characters = {}
    local rammers = {Rammer(love.graphics.getWidth() / 2, love.graphics.getHeight() + 200, 10, player), Rammer(love.graphics.getWidth() / 3, love.graphics.getHeight() + 200, 10, player)}
    local turetts = {Turett((love.graphics.getWidth() / 2) + 40, (love.graphics.getHeight() / 2) - 40, 10, player), Turett((love.graphics.getWidth() / 2) + 140, (love.graphics.getHeight() / 2) - 30, 10, player)}
    local planets = {Planet(120, 120, {r=100/255, g=120/255, b=21/255}, 100, characters), Planet(820, 820, {r=0/255, g=255/255, b=201/255}, 40, characters, 0.5)}

    for _, rammer in ipairs(rammers) do
        table.insert(characters, rammer)
    end
    for _, turett in ipairs(turetts) do
        table.insert(characters, turett)
    end
    for _, planet in ipairs(planets) do
        table.insert(characters, planet)
    end
    table.insert(characters, player)

    local ui = UserInterface()

    return {
        player = player,
        rammers = rammers,
        turetts = turetts,
        characters = characters,
        planets = planets,
        asteroidTbl = {},
        
        updatePlayerAutoDocking = function (self)
            if self.player.undocked then
                for _, planet in ipairs(self.planets) do
                    local playerPlanetAngle = CalculateAngle(planet.x, planet.y, self.player.x, self.player.y) - 90
                    local planetPlayerAngle = CalculateAngle(planet.x, planet.y, self.player.x, self.player.y) + 90
                    local distanceBetweenEnds = CalculateDistance(planet.x + math.cos(math.rad(planetPlayerAngle)) * planet.radius,
                                                            planet.y - math.sin(math.rad(planetPlayerAngle)) * planet.radius,
                                                            self.player.x + math.cos(math.rad(playerPlanetAngle)) * self.player.radius,
                                                            self.player.y - math.sin(math.rad(playerPlanetAngle)) * self.player.radius)
                    if distanceBetweenEnds <= PLAYER_DOCKING_DISTANCE and self.player.dockedPlanet == nil then
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
                for _, astroid in ipairs(self.asteroidTbl) do
                    if CalculateDistance(bullet.x, bullet.y, astroid.x, astroid.y) < math.max(bullet.radius, astroid.radius) then
                        self.player:removeBullet(bulletIndex)
                        astroid:explode()
                    end 
                end
                for _, planet in ipairs(self.planets) do
                    if CalculateDistance(planet.x, planet.y, bullet.x, bullet.y) <= planet.radius then
                        table.remove(self.player.bullets, bulletIndex)
                    end
                end
            end
        end,

        updateAstroid = function (self)
            if #self.asteroidTbl < ASTROID_MIN_ALLOWED then
                local astroid = Astroid(math.random(love.graphics.getWidth()),
                                        math.random(love.graphics.getHeight()),
                                        {r = math.random(0, 255) / 255, g = math.random(0, 255) / 255, b = math.random(0, 255) / 255},
                                        math.random(ASTROID_MIN_RAD, ASTROID_MAX_RAD),
                                        math.random(ASTROID_MIN_SIDES, ASTROID_MAX_SIDES),
                                        -tonumber(ASTROID_MAX_RAD / 5),
                                        tonumber(ASTROID_MAX_RAD / 5) or ASTROID_MAX_RAD / 5,
                                        ASTROID_MAX_VEL,
                                        ASTROID_DEFAULT_AMT,
                                        self)
                table.insert(self.asteroidTbl, astroid)
                table.insert(self.characters, astroid)
                
            end

            for _, astroid in ipairs(self.asteroidTbl) do
                astroid:update()
                for _, character in ipairs(self.characters) do
                    if tostring(astroid) ~= tostring(character) then
                        if CalculateDistance(character.x, character.y, astroid.x, astroid.y) < (character.radius + astroid.radius) - 4 then
                            if not character.exploding then
                                if ListIndex(self.asteroidTbl, astroid) ~= -1 then
                                    astroid:explode()
                                end
                                if ListIndex(self.characters, character) ~= -1 then
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
                end
            end
        end,
        
        updateTurrets = function (self)
            for index, turett in ipairs(self.turetts) do
                turett:update()
                
                for _, planet in ipairs(self.planets) do
                    if CalculateDistance(planet.x, planet.y, turett.x, turett.y) <= planet.radius then
                        turett:explode()
                    end
                end
                
                if turett.exploded then
                    table.remove(self.turetts, index)
                end

                for bulletIndex, bullet in ipairs(turett.bullets) do
                    for _, rammer in ipairs(self.rammers) do
                        if CalculateDistance(bullet.x, bullet.y, rammer.x, rammer.y) < rammer.radius then
                            rammer:explode()
                            table.remove(turett.bullets, bulletIndex)
                        end
                        for _, planet in ipairs(self.planets) do
                            if CalculateDistance(planet.x, planet.y, bullet.x, bullet.y) <= planet.radius then
                                table.remove(turett.bullets, bulletIndex)
                            end
                        end
                    end
                end
            end
        end,
        
        updateRammers = function (self)
            for index, rammer in ipairs(self.rammers) do
                rammer:update()
                
                for _, planet in ipairs(self.planets) do
                    if CalculateDistance(planet.x, planet.y, rammer.x, rammer.y) <= planet.radius then
                        rammer:explode()
                    end
                end

                if rammer.exploded then
                    table.remove(self.rammers, index)
                end

                for _, turett in ipairs(self.turetts) do
                    if CalculateDistance(turett.x, turett.y, rammer.x, rammer.y) < turett.radius then
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
                local distance = CalculateDistance(planet.x, planet.y, self.player.x, self.player.y)
                local touchDown = distance <= planet.radius + self.player.radius
                
                planet:update()
                
                self.player:addEmissionCollisionPlanet(planet)
                
                local angle = CalculateAngle(planet.x, planet.y, self.player.x, self.player.y) % 360
                local dAngle = math.abs(self.player.angle - angle)

                if touchDown then
                    if dAngle >= 20 or math.sqrt(self.player.thrust.x^2 + self.player.thrust.y^2) > self.player.COLLISION_VELOCITY then
                        self.player:explode()
                        return
                    else
                        self:playerDocked(planet)
                    end
                end
                
            end
        end,

        draw = function (self)
            environment.draw()
            LoggerOutput:write()
            
            self.player:draw()
            
            for _, rammer in ipairs(self.rammers) do
                rammer:draw()
            end
            
            for _, turett in ipairs(self.turetts) do
                turett:draw()
            end
            
            for _, astroid in ipairs(self.asteroidTbl) do
                astroid:draw()
            end
            for _, planet in ipairs(self.planets) do
                planet:draw()
            end

            ui:draw()

        end,

        update = function (self)
            ui:update()
            
            if not STATESMACHINE.pause then
                environment.update()
                
                self:updatePlanets()
                self.player:update()
                if self.player.exploding then
                    table.remove(self.characters, ListIndex(self.characters, self.player))
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
