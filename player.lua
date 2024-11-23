
local Bullet = require 'bullet'
local NewParticleSystem = require 'particleSystem'

---@param x number
---@param y number
---@param radius number
---@param up? table
---@param down? table
---@param control? table|string
---@param drift? boolean
---@param color? string
---@param brake? table
---@return table
local function Player(x, y, radius, drift, color, control, up, down, brake)
    local ACCEL_SPEED = 0.5
    local THRUSTER_ACCEL = 1
    local MAX_SPEED = 600
    local THRUSTER_MAX_SPEED = 150
    local MOVEMENT_FRICTION = 0.02
    local THRUSTER_DECCEL = 0.5
    local MOUSE_TURN_SPEED = 0.2
    local KEYBOARD_TURN_SPEED = 2
    local BRAKE_FRICTION = 0.2
    local BULLET_VEL = 10
    local MAX_BULLETS_AMT = 15
    local EXPLODE_DUR = 2
    local CAMERAFOCUSACCEL = 1
    local FORWARD_THRUSTER_MAX_EMISSION = 50000
    local REVERSE_THRUSTER_MAX_EMISSION = 40000
    local MASS_CONSTANT = 0.1
    
    local movedUp = false
    local movedDown = false
    local right, left
    local mouseNormalization = 1

    local CameraRefPrevX = x
    local CameraRefPrevY = y
    local CameraRefNewX = x
    local CameraRefNewY = y

    local updatedExplosion = false
    
    local explosionParticles = NewParticleSystem({{image=love.graphics.newImage('background.png'), width=10}})
    explosionParticles:setDurationRange(EXPLODE_DUR / 2, EXPLODE_DUR)
    explosionParticles:setSpeedRange(0.5, 1)

    local forwardThrusterParticles = NewParticleSystem({{image=love.graphics.newImage('particle.png'), width=8}})
    forwardThrusterParticles:setDurationRange(1, 2)
    
    local reverseThrusterParticles = NewParticleSystem({{image=love.graphics.newImage('particle.png'), width=5}})
    reverseThrusterParticles:setDurationRange(1, 2)

    if type(control) == 'table' then
        right = control.right
        left = control.left
    elseif type(control) == "nil" then
        right = {'right', 'd'}
        left = {'left', 'a'}
    elseif control ~= 'mouse' then
        error('Invalid control parameter')
    end
    
    return {
        x = x,
        y = y,
        up = up or {'up', 'w'},
        down = down or {'down', 's'},
        right = right,
        left = left,
        brake = brake or {'x'},
        mouseAngle = 0,
        yDirection = 0,
        dockedPlanet = nil,
        docked = false,
        undocked = true,
        docking = false,
        exploded = false,
        undocking = false,

        MAX_SPEED = MAX_SPEED,
        MOUSE_TURN_SPEED = MOUSE_TURN_SPEED,
        KEYBOARD_TURN_SPEED = KEYBOARD_TURN_SPEED,
        ACCEL_SPEED = ACCEL_SPEED,
        MAX_BULLETS_AMT = MAX_BULLETS_AMT,
        EXPLODE_DUR = EXPLODE_DUR,
        COLLISION_VELOCITY = 100,

        radius = radius,
        drift = drift or false,
        exploding = false,
        explodeTime = 0,
        undockingAngle = 0,
        continueUndocking = true,
        
        explosionParticles = explosionParticles,
        forwardThrusterParticles = forwardThrusterParticles,
        reverseThrusterParticles = reverseThrusterParticles,

        bullets = {},
        thrust = {x=0, y=0, friction=MOVEMENT_FRICTION},
        forwardThruster = {x=0, y=0, maxSpeed=THRUSTER_MAX_SPEED, accel=THRUSTER_ACCEL, deccel=THRUSTER_DECCEL},
        reverseThruster = {x=0, y=0, maxSpeed=THRUSTER_MAX_SPEED, accel=THRUSTER_ACCEL, deccel=THRUSTER_DECCEL},
        mainPlotPoints = {0, 0, 0, 0, 0, 0},
        mass = radius * MASS_CONSTANT,
        angle = 0,
        
        color = color or {r = 1, g = 0.8, b = 0.5},

        -- Draw
        draw = function (self)
            self:drawBullets()
            self:drawParticles()
            self:drawPlayer()
        end,
        
        drawParticles = function (self)
            if not self.exploding then
                self.forwardThrusterParticles:draw()
                self.reverseThrusterParticles:draw()
            end
            self.explosionParticles:draw()
        end,
        
        drawBullets = function (self)
            if #self.bullets > 0 then
                for _, bullet in ipairs(self.bullets) do
                    bullet:draw()
                end
            end
        end,
        
        drawPlayer = function (self)
            if not self.exploding then
                local x_dir = math.cos(math.rad(self.angle + 90))
                local y_dir = math.sin(math.rad(self.angle + 90))

                self.mainPlotPoints = {
                    self.x + ((4 / 3) * self.radius) * x_dir, self.y - ((4 / 3) * self.radius) * y_dir,
                    self.x - self.radius * ((2 / 3) * x_dir + y_dir), self.y + self.radius * ((2 / 3) * y_dir - x_dir),
                    self.x - self.radius * ((2 / 3) * x_dir - y_dir), self.y + self.radius * ((2 / 3) * y_dir + x_dir),
                }
                
                love.graphics.setColor(self.color.r, self.color.g, self.color.b)
                love.graphics.polygon('fill', self.mainPlotPoints)
                
                if DEBUGGING then
                    love.graphics.setLineWidth(1)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.circle('line', self.x, self.y, self.radius)
                end
            end
        end,

        -- Update
        update = function (self)
            self.thrust.x = Clamp(self.thrust.x + self.forwardThruster.x - self.reverseThruster.x, -self.MAX_SPEED, self.MAX_SPEED)
            self.thrust.y = Clamp(self.thrust.y + self.forwardThruster.y - self.reverseThruster.y, -self.MAX_SPEED, self.MAX_SPEED)
            
            if not self.undocked then
                self:updateDockingProcedure()
            end
            
            if not self.docked then
                self:movePlayer()
            end

            self:updateParticles()
            self:updateInput()
            self:updateWorldDir()
            self:updateBullets()
            self:updateExplosionProcedures()
        end,
        
        updatePlayerWorldProxy = function (self)
            self.x = self.x + worldDirection.x
            self.y = self.y + worldDirection.y
        end,

        updateExplosionProcedures = function (self)
            if self.exploding then
                
                if not updatedExplosion then
                    self.explosionParticles:setPosition(self.x, self.y)
                    self.explosionParticles:emitOnce(150)
                    updatedExplosion = true
                end
                for _, particle in ipairs(self.explosionParticles.particles) do
                    particle.x = particle.x + worldDirection.x
                    particle.y = particle.y + worldDirection.y
                end

                self.explodeTime = self.explodeTime + DT
                if self.explodeTime >= EXPLODE_DUR then
                    self.explodeTime = 0
                    self.exploded = true
                end
            end
        end,

        updateWorldDir = function (self)
            CameraRefPrevX = self.x
            CameraRefPrevY = self.y
            
            local dx = CameraRefNewX - CameraRefPrevX
            local dy = CameraRefNewY - CameraRefPrevY
            
            worldDirection.x = dx * CAMERAFOCUSACCEL
            worldDirection.y = dy * CAMERAFOCUSACCEL
            
            self:updatePlayerWorldProxy()
            
            CameraRefNewX = self.x
            CameraRefNewY = self.y
            
        end,
        
        updateInput = function (self)
            if not self.exploding then
                movedUp = false
                movedDown = false

                if self.undocked or self.undocking or self.docked then
                    for _, ups in ipairs(self.up) do
                        if love.keyboard.isDown(ups)then
                            self.yDirection = 1
                            movedUp = true
                            break
                        end
                    end
                    for _, downs in ipairs(self.down) do
                        if love.keyboard.isDown(downs)then
                            self.yDirection = -1
                            movedDown = true
                            break
                        end
                    end
                end

                if not movedUp then
                    self:releaseForwardThrusters()
                end

                if not movedDown then
                    self:releaseReverseThrusters()
                end

                if not movedUp and not movedDown then
                    self:releasePlayerThrust()
                else
                    if not self.undocking then
                        self:onMovePlayer(self.yDirection) 
                    end
                end
                
                if self.undocked then
                    for _, brakes in ipairs(self.brake) do
                        if love.keyboard.isDown(brakes)then
                            self:onBrakesPressed()
                            break
                        end
                    end
                
                    mouseNormalization = 1
                    if control == 'mouse' then
                        local normalizationCenterOffset = radius / 2
                        mouseNormalization = math.min((CalculateDistance(love.mouse.getX(), love.mouse.getY(), self.x, self.y)) / normalizationCenterOffset, 1)
        
                        local dx = love.mouse.getX() - self.x
                        local dy = self.y - love.mouse.getY()
            
                        ---@diagnostic disable-next-line: deprecated
                        self.mouseAngle = self.mouseAngle - ((self.mouseAngle - ((math.deg(math.atan2(dy,dx)) - 90) % 360)) * mouseNormalization)
                        self.angle = CalculateAngleLerp(self.angle, self.mouseAngle, MOUSE_TURN_SPEED)
                    else
                        for _, lefts in ipairs(self.left) do
                            if love.keyboard.isDown(lefts)then
                                self:turnPlayer(1)
                                break
                            end
                        end
        
                        for _, rights in ipairs(self.right) do
                            if love.keyboard.isDown(rights)then
                                self:turnPlayer(-1)
                                break
                            end
                        end
        
                    end
                end
            end
        end,
        
        updateParticles = function (self)
            if not self.exploding then
                self.forwardThrusterParticles:setPosition(self.x + math.cos(math.rad((self.angle - 90) % 360)) * self.radius / 2, self.y - math.sin(math.rad((self.angle - 90) % 360)) * self.radius / 2)
                self.forwardThrusterParticles:emitEverySecond(FORWARD_THRUSTER_MAX_EMISSION * math.sqrt((self.forwardThruster.y ^ 2) + (self.forwardThruster.x ^ 2)) / self.forwardThruster.maxSpeed)
                self.forwardThrusterParticles:setAngleRange(self.angle - 10, self.angle + 10)
                
                self.forwardThrusterParticles:update()
                
                local forwardThrusterLeftX = self.x - (math.cos(math.rad((self.angle - 90) % 360)) * self.radius / 2) - (math.cos(math.rad((self.angle) % 360)) * self.radius / 2)
                local forwardThrusterLeftY = self.y + (math.sin(math.rad((self.angle - 90) % 360)) * self.radius / 2) + (math.sin(math.rad((self.angle) % 360)) * self.radius / 2)
                local forwardThrusterRightX = self.x - (math.cos(math.rad((self.angle - 90) % 360)) * self.radius / 2) + (math.cos(math.rad((self.angle) % 360)) * self.radius / 2)
                local forwardThrusterRightY = self.y + (math.sin(math.rad((self.angle - 90) % 360)) * self.radius / 2) - (math.sin(math.rad((self.angle) % 360)) * self.radius / 2)
                local emissionAmt = REVERSE_THRUSTER_MAX_EMISSION * math.sqrt((self.reverseThruster.y ^ 2) + (self.reverseThruster.x ^ 2)) / self.reverseThruster.maxSpeed
                self.reverseThrusterParticles:setAngleRange((self.angle - 180) - 2, (self.angle - 180) + 2)
                self.reverseThrusterParticles:setPosition(forwardThrusterLeftX, forwardThrusterLeftY)
                self.reverseThrusterParticles:emitEverySecond(emissionAmt)
                self.reverseThrusterParticles:setPosition(forwardThrusterRightX, forwardThrusterRightY)
                self.reverseThrusterParticles:emitEverySecond(emissionAmt)
                
                self.reverseThrusterParticles:update()
            end
            self.explosionParticles:update()
        end,

        updateBullets = function (self)
            if #self.bullets > 0 then
                for index, bullet in ipairs(self.bullets) do
                    if bullet:getDist() > love.graphics.getWidth() * 1.5 then
                        self:removeBullet(index)
                    else
                        bullet:update(worldDirection)
                    end
                end
            end
        end,
        
        updateDockingProcedure = function (self)
            local playerPlanetAngle = CalculateAngle(self.dockedPlanet.x, self.dockedPlanet.y, self.x, self.y) - 90
            
            if self.docking then
                local angle = (playerPlanetAngle + 90) % 360
                self.angle = CalculateAngleLerp(self.angle, angle, 0.1)
                local dAngle = math.abs(math.floor(self.angle) - math.floor(angle))

                if dAngle <= 5 then
                    self:onMovePlayer(-1)
                end
            end

            if self.docked then
                local planetPlayerAngle = playerPlanetAngle + 180

                local planetsEdgeX = self.dockedPlanet.x + math.cos(math.rad(planetPlayerAngle)) * self.dockedPlanet.radius
                local planetsEdgeY = self.dockedPlanet.y - math.sin(math.rad(planetPlayerAngle)) * self.dockedPlanet.radius
                local playersEdgeX = -math.cos(math.rad(playerPlanetAngle)) * self.radius
                local playersEdgeY = math.sin(math.rad(playerPlanetAngle)) * self.radius
                
                self.x = planetsEdgeX + playersEdgeX
                self.y = planetsEdgeY + playersEdgeY
                
                self.angle = (playerPlanetAngle + 90) % 360
            end

            if self.undocking then
                -- local Fx, Fy = CalculateTwoBodyVector(self.dockedPlanet, self)
                local escapeVel = CalculaterEscapeVelocity(self.dockedPlanet)
                -- local planetGravity = GRAVITATIONAL_CONSTANT * self.dockedPlanet.mass / self.dockedPlanet.radius^2
                
                self.forwardThruster.x = math.cos(math.rad(self.undockingAngle)) * (escapeVel + math.abs(self.dockedPlanet.thrust.x))
                self.forwardThruster.y = -math.sin(math.rad(self.undockingAngle)) * (escapeVel + math.abs(self.dockedPlanet.thrust.y))
                
                self.x = self.x + self.thrust.x * DT
                self.y = self.y + self.thrust.y * DT
            end
            
            if CalculateDistance(self.x, self.y, self.dockedPlanet.x, self.dockedPlanet.y) - (self.dockedPlanet.radius + self.radius) > 200 then
                self.undocked = true
                self.undocking = false
                self.docked = false
                self.dockedPlanet = nil
            end
        end,

        -- Docking
        startDock = function (self, planet)
            self.dockedPlanet = planet
            self.docking = true
            self.undocked = false
        end,

        startUndock = function (self)
            self.undocking = true
            self.docked = false
            self.undockingAngle = (self.angle + 90) % 360
            -- LOGGER:log(self.undockingAngle)
        end,

        -- Bullets
        removeBullet = function (self, index)
            table.remove(self.bullets, index)
        end,

        addBullet = function (self)
            if not self.exploding then
                if #self.bullets <= self.MAX_BULLETS_AMT then
                    table.insert(self.bullets, Bullet(self.x + math.cos(math.rad(self.angle + 90)), self.y - math.sin(math.rad(self.angle + 90)), self.angle, 3, BULLET_VEL))
                end
            end
        end,

        -- Player moveement
        turnPlayer = function (self, dir)
            if not self.exploding then
                self.angle = self.angle + (self.KEYBOARD_TURN_SPEED * dir)
            end
        end,
        
        movePlayer = function (self)
            self.angle = self.angle % 360
            
            if not self.exploding then
                self.x = self.x + self.thrust.x * DT
                self.y = self.y + self.thrust.y * DT
            end
        end,
        
        onMovePlayer = function (self, dir)
            if not self.exploding then
                if self.drift then
                    if self.docked then
                        if dir > 0 then
                            if self.continueUndocking then
                                self:startUndock() 
                                self.continueUndocking = false
                            end
                        end
                    else
                        self.continueUndocking = true
                        if dir > 0 then
                            self.forwardThruster.x = math.cos(math.rad(self.angle + 90)) * (self.forwardThruster.deccel + 1) * self.forwardThruster.accel
                            self.forwardThruster.y = -math.sin(math.rad(self.angle + 90)) * (self.forwardThruster.deccel + 1) * self.forwardThruster.accel
                        else
                            self.reverseThruster.x = math.cos(math.rad(self.angle + 90)) * (self.reverseThruster.deccel + 1) * self.reverseThruster.accel
                            self.reverseThruster.y = -math.sin(math.rad(self.angle + 90)) * (self.reverseThruster.deccel + 1) * self.reverseThruster.accel
                        end
                    end
                else
                    self.thrust.x = self.MAX_SPEED * math.cos(math.rad(self.angle + 90)) * dir / DT
                    self.thrust.y = -self.MAX_SPEED * math.sin(math.rad(self.angle + 90)) * dir / DT
                end
                self.forwardThruster.x = self.forwardThruster.x * mouseNormalization
                self.forwardThruster.y = self.forwardThruster.y * mouseNormalization
                self.reverseThruster.x = self.reverseThruster.x * mouseNormalization
                self.reverseThruster.y = self.reverseThruster.y * mouseNormalization
            end
        end,

        onBrakesPressed = function (self)
            if not self.exploding then
                local forwardThruster_x_dir = -(self.forwardThruster.x * (BRAKE_FRICTION + 1)) * self.forwardThruster.deccel
                local forwardThruster_y_dir = -(self.forwardThruster.y * (BRAKE_FRICTION + 1)) * self.forwardThruster.deccel

                self.forwardThruster.x = self.forwardThruster.x + forwardThruster_x_dir
                self.forwardThruster.y = self.forwardThruster.y + forwardThruster_y_dir

                local reverseThruster_x_dir = -(self.reverseThruster.x * (BRAKE_FRICTION + 1)) * self.reverseThruster.deccel
                local reverseThruster_y_dir = -(self.reverseThruster.y * (BRAKE_FRICTION + 1)) * self.reverseThruster.deccel

                self.reverseThruster.x = self.reverseThruster.x + reverseThruster_x_dir
                self.reverseThruster.y = self.reverseThruster.y + reverseThruster_y_dir

                local thrust_x_dir = -(self.thrust.x * (BRAKE_FRICTION + 1)) * self.thrust.friction
                local thrust_y_dir = -(self.thrust.y * (BRAKE_FRICTION + 1)) * self.thrust.friction

                self.thrust.x = self.thrust.x + thrust_x_dir
                self.thrust.y = self.thrust.y + thrust_y_dir
            end
        end,

        -- Releasing thrusters
        releasePlayerThrust = function (self)
            local thrust_x_dir = -self.thrust.x * self.thrust.friction
            local thrust_y_dir = -self.thrust.y * self.thrust.friction

            self.thrust.x = self.thrust.x + thrust_x_dir
            self.thrust.y = self.thrust.y + thrust_y_dir
        end,

        releaseForwardThrusters = function (self)
            local forwardThruster_x_dir = -self.forwardThruster.x * self.forwardThruster.deccel
            local forwardThruster_y_dir = -self.forwardThruster.y * self.forwardThruster.deccel

            self.forwardThruster.x = self.forwardThruster.x + forwardThruster_x_dir
            self.forwardThruster.y = self.forwardThruster.y + forwardThruster_y_dir
        end,
        
        releaseReverseThrusters = function (self)
            local reverseThruster_x_dir = -self.reverseThruster.x * self.reverseThruster.deccel
            local reverseThruster_y_dir = -self.reverseThruster.y * self.reverseThruster.deccel

            self.reverseThruster.x = self.reverseThruster.x + reverseThruster_x_dir
            self.reverseThruster.y = self.reverseThruster.y + reverseThruster_y_dir
        end,

        -- Misc
        addEmissionCollisionPlanet = function (self, planet)
            local explosionContainsItAlready = false
            for _, body in ipairs(self.explosionParticles.collisionBodies) do
                if body == planet then
                    explosionContainsItAlready = true
                end
            end
            if not explosionContainsItAlready then
                self.explosionParticles:addCollisionBody(planet) 
            end

            local forwardThrusterContainsItAlready = false
            for _, body in ipairs(self.forwardThrusterParticles.collisionBodies) do
                if body == planet then
                    forwardThrusterContainsItAlready = true
                end
            end
            if not forwardThrusterContainsItAlready then
                self.forwardThrusterParticles:addCollisionBody(planet) 
            end

            local reverseThrusterContainsItAlready = false
            for _, body in ipairs(self.reverseThrusterParticles.collisionBodies) do
                if body == planet then
                    reverseThrusterContainsItAlready = true
                end
            end
            if not reverseThrusterContainsItAlready then
                self.reverseThrusterParticles:addCollisionBody(planet) 
            end
        end,

        explode = function (self)
            self.exploding = true
        end,
        

    }
end


return Player

