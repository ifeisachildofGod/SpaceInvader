require 'os'
require 'global'

math.randomseed(os.time())

local Player = require 'player'

local Enemies = require 'enemy'
local Rammer, Turett = Enemies[1], Enemies[2]

local Astroid = require 'astroid'
local Text = require 'text'
local Planet = require 'planet'



local function Environment ()
    -- sprite = {frames={f1, f2, f3}, pos={x, y, r}, fps, frameIndex, update?=func(sprite), before?=func(sprite), after?=func(sprite)}
    local sprites = {}

    return {
        draw = function ()
            for _, spriteInfo in ipairs(sprites) do
                if spriteInfo.before ~= nil then
                    spriteInfo.before(spriteInfo, DT) 
                end

                local frames = spriteInfo.frames
                local pos = spriteInfo.pos

                if #frames then
                    local frameFPS = spriteInfo.fps

                    spriteInfo.frameIndex = (spriteInfo.frameIndex + (DT * frameFPS)) % (#frames + 1)
                    
                    local frame = frames[math.floor(spriteInfo.frameIndex)]
                    love.graphics.draw(frame, pos.x, pos.y, pos.r or 0)
                else
                    love.graphics.draw(frames[1], pos.x, pos.y, pos.r or 0)
                end
                
                if spriteInfo.after ~= nil then
                    spriteInfo.after(spriteInfo, DT) 
                end
            end
        end,
        
        update = function ()
            for _, spriteInfo in ipairs(sprites) do
                if spriteInfo.update ~= nil then
                    spriteInfo.update(spriteInfo, DT)
                end
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
            local spriteInfo = {frames=frames, pos=posInfo, fps=fps, frameIndex=1, update=update, before=beforeAnimation, after=afterAnimation}
            for frameIndex, _ in ipairs(spriteInfo.frames) do
                if type(spriteInfo.frames[frameIndex]) == "string" then
                    spriteInfo.frames[frameIndex] = love.graphics.newImage(spriteInfo.frames[frameIndex])
                end
            end
            table.insert(sprites, spriteInfo)
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
    local planets = {Planet(120, 120, {r=100/255, g=120/255, b=21/255}, 100, characters), Planet(820, 820, {r=0/255, g=255/255, b=201/255}, 40, characters)}

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

    return {
        player = player,
        rammers = rammers,
        turetts = turetts,
        characters = characters,
        planets = planets,
        asteroidTbl = {},
        pausedText = Text(love.graphics.getWidth() / 2, 0, 'h5', {r = 0.9, g = 0.9, b = 0.9}),
        
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

            if key == 'escape' then
                if STATESMACHINE.pause then
                    STATESMACHINE:setState('normal')
                else
                    STATESMACHINE:setState('pause')
                end
            end
        end,

        mousePressed = function (self, mouseCode)
            if mouseCode == 1 then
                self.player:addBullet()
            end
        end,

        paused = function (self)
            self.pausedText:setText('Paused')
            self.pausedText:write()
        end,

        updatePlayerBullet = function (self)
            for bulletIndex, bullet in ipairs(self.player.bullets) do
                for _, astroid in ipairs(self.asteroidTbl) do
                    if CalculateDistance(bullet.x, bullet.y, astroid.x, astroid.y) < math.max(bullet.radius, astroid.radius) then
                        self.player:removeBullet(bulletIndex)
                        astroid:explode()
                    end 
                end
            end
        end,

        updateAstroid = function (self)
            if #self.asteroidTbl < ASTROID_MIN_ALLOWED then
                table.insert(self.asteroidTbl,
                            Astroid(math.random(love.graphics.getWidth()),
                                    math.random(love.graphics.getHeight()),
                                    math.random(ASTROID_MIN_RAD, ASTROID_MAX_RAD),
                                    math.random(ASTROID_MIN_SIDES, ASTROID_MAX_SIDES),
                                    -tonumber(ASTROID_MAX_RAD / 5),
                                    tonumber(ASTROID_MAX_RAD / 5) or ASTROID_MAX_RAD / 5,
                                    ASTROID_MAX_VEL,
                                    ASTROID_DEFAULT_AMT,
                                    self))
                
            end

            for _, astroid in ipairs(self.asteroidTbl) do
                astroid:update()
                for _, character in ipairs(self.characters) do
                    if CalculateDistance(character.x, character.y, astroid.x, astroid.y) < math.max(character.radius, astroid.radius) then
                        if not character.exploding then
                            if character.explode ~= nil then
                                character:explode() 
                            end
                            astroid:explode()
                        end
                    end
                end
            end
        end,
        
        updateTurrets = function (self)
            for index, turett in ipairs(self.turetts) do
                turett:update()
                    
                if turett.exploding then
                    turett.explodeTime = turett.explodeTime - turett.EXPLODE_DUR
                    if turett.explodeTime < 0 then
                        turett.explodeTime = 0
                        table.remove(self.turetts, index)
                    end
                end
                for bulletIndex, bullet in ipairs(turett.bullets) do
                    for _, rammer in ipairs(self.rammers) do
                        if CalculateDistance(bullet.x, bullet.y, rammer.x, rammer.y) < rammer.radius then
                            rammer:explode()
                            table.remove(turett.bullets, bulletIndex)
                        end
                        for _, planet in ipairs(self.planets) do
                            
                        end
                    end
                end
            end
        end,
        
        updateRammers = function (self)
            for index, rammer in ipairs(self.rammers) do
                rammer:update()
                
                if rammer.exploding then
                    rammer.explodeTime = rammer.explodeTime - rammer.EXPLODE_DUR
                    if rammer.explodeTime < 0 then
                        rammer.explodeTime = 0
                        table.remove(self.rammers, index)
                    end
                end
                for turretIndex, turett in ipairs(self.turetts) do
                    if CalculateDistance(turett.x, turett.y, rammer.x, rammer.y) < turett.radius then
                        rammer:explode()
                        turett:explode()
                        table.remove(self.rammers, index)
                        table.remove(self.turetts, turretIndex)
                    end
                end
            end
        end,

        updatePlanets = function (self)
            for _, planet in ipairs(self.planets) do
                planet:update()
            end
        end,

        draw = function (self)
            if STATESMACHINE.pause then
                self:paused()
            end
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

        end,

        update = function (self)
            if not STATESMACHINE.pause then
                environment.update()

                self.player:update()
                self:updatePlayerBullet()
                self:updatePlayerAutoDocking()

                self:updateTurrets()
                self:updateRammers()
                self:updateAstroid()
                self:updatePlanets()
            end
        end
    }
end

return World
