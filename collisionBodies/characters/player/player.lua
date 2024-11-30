local wrappers = require 'collisionBodies.characters.player.wrappers'
local calculate = require 'calculate'
local playerModes = require 'collisionBodies.characters.player.modes'

local CAMERAFOCUSACCEL = 1

local Player = function (kamikazees, stationaryGunners, kamikazeeGunners, astroids, collisionBodies, planets)
    local modes = StateMachine({'character', 'spacecraft'})
    
    modes:setState('spacecraft')
    
    ---@param ... string|integer
    ---@return fun(): boolean
    local inputFunc = function (...)
        local actionOptions = {...}

        return function ()
            for _, actionChr in ipairs(actionOptions) do
                if type(actionChr) == "number" then
                    if love.mouse.isDown(actionChr) then
                        return true
                    end
                elseif type(actionChr) == "string" then
                    if love.keyboard.isDown(actionChr) then
                        return true
                    end
                else
                    error('Invalid input constant '..actionChr)
                end
            end

            return false
        end
    end

    local playerSpacecraft = playerModes.playerVehicle(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2, 20, nil, 'mouse', inputFunc('up', 'w'), inputFunc('down', 's'), inputFunc(2, 'z'), inputFunc(1, 'space'))
    local playerCharacter = playerModes.player(playerSpacecraft.x, playerSpacecraft.y, 7, nil, nil, inputFunc('d'), inputFunc('a'), inputFunc('w'))

    local CameraRefPrev = {x=playerCharacter.x, y=playerCharacter.y}
    local CameraRefCurr = {x=playerCharacter.x, y=playerCharacter.y}

    return {
        player = (modes.spacecraft and playerSpacecraft) or playerCharacter,
        modes = modes,
        character = wrappers.character(playerCharacter, kamikazees, stationaryGunners, kamikazeeGunners, planets, collisionBodies),
        spacecraft = wrappers.spacecraft(playerSpacecraft, kamikazees, stationaryGunners, kamikazeeGunners, planets, collisionBodies),
        kamikazees = kamikazees,
        stationaryGunners = stationaryGunners,
        kamikazeeGunners = kamikazeeGunners,
        astroids = astroids,
        collisionBodies = collisionBodies,
        planets = planets,
        
        mousePressed = function (self, mouseCode)
            if mouseCode == 2 then
                if self.modes.spacecraft then
                    if self.spacecraft.player.docked then
                        self.modes:setState('character')
                        self.character.player:setPlanet(self.spacecraft.player.dockedPlanet)
                        self.character.player.vertical.displacement = 0
                        -- self.character.player:jumpUp()
                    end
                elseif self.modes.character then
                    if calculate.distance(self.spacecraft.player.x, self.spacecraft.player.y, self.character.player.x, self.character.player.y) < self.character.player.radius + self.spacecraft.player.radius then
                        self.modes:setState('spacecraft')
                    end
                end
            end
        end,
        
        updatePlayerInPlanets = function (self, planet)
            self.spacecraft:updatePlayerInPlanets(planet)
        end,

        draw = function (self)
            self.character.player:draw()
            self.spacecraft.player:draw()

            if self.modes.character then
                self.character:draw()
            elseif self.modes.spacecraft then
                self.spacecraft:draw()
            end
        end,
        
        planetDestroyed = function (self, planet)
            self.character:planetDestroyed(planet)
            self.spacecraft:planetDestroyed(planet)
        end,
        
        astroidUpdate = function (self, astroid)
            if calculate.distance(self.character.player.x, self.character.player.y, astroid.x, astroid.y) < (self.character.player.radius + astroid.radius) - 4 then
                if not self.character.player.gettingDestroyed then
                    self.character.player:destroy()
                    if ListIndex(self.astroids, astroid) ~= -1 then
                        astroid:destroy()
                    end
                end
            end
            if calculate.distance(self.spacecraft.player.x, self.spacecraft.player.y, astroid.x, astroid.y) < (self.spacecraft.player.radius + astroid.radius) - 4 then
                if not self.spacecraft.player.gettingDestroyed then
                    self.spacecraft.player:destroy()
                    if ListIndex(self.astroids, astroid) ~= -1 then
                        astroid:destroy()
                    end
                end
            end
        end,

        update = function (self)
            if self.modes.spacecraft then
                self.player = self.spacecraft.player
            else
                self.player = self.character.player
            end

            self.character.player:update()
            self.spacecraft.player:update()

            self.character:update()
            self.spacecraft:update()

            self.gettingDestroyed = (self.character.player.gettingDestroyed and self.modes.character) or (self.spacecraft.player.gettingDestroyed and self.modes.spacecraft)
            
            if self.spacecraft.player.gettingDestroyed and self.modes.spacecraft then
                self.character.player:destroy()
            end
            
            if self.modes.character then
                self.character.player:updateInput()
            elseif self.modes.spacecraft then
                self.spacecraft.player:updateInput()
                self.character.player.x, self.character.player.y = self.spacecraft.player.x, self.spacecraft.player.y
                self.character.player.thrust.x, self.character.player.thrust.y = 0, 0
            end

            if self.character.player.destroyed then
                STATESMACHINE:setState('restart')
            end

            CameraRefPrev.x, CameraRefPrev.y = self.character.player.x, self.character.player.y
            
            if not self.character.player.gettingDestroyed then
                local dx = CameraRefCurr.x - CameraRefPrev.x
                local dy = CameraRefCurr.y - CameraRefPrev.y

                WorldDirection.x = calculate.lerp(WorldDirection.x, dx, CAMERAFOCUSACCEL)
                WorldDirection.y = calculate.lerp(WorldDirection.y, dy, CAMERAFOCUSACCEL)
            else
                WorldDirection.x, WorldDirection.y = 0, 0
            end
            
            self.character.player.x = self.character.player.x + WorldDirection.x
            self.character.player.y = self.character.player.y + WorldDirection.y

            self.spacecraft.player.x = self.spacecraft.player.x + WorldDirection.x
            self.spacecraft.player.y = self.spacecraft.player.y + WorldDirection.y

            CameraRefCurr.x, CameraRefCurr.y = self.character.player.x, self.character.player.y

        end
    }
end

return Player