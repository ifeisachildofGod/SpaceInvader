
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
    local ACCEL_SPEED = 0.05
    local THRUSTER_ACCEL = 0.08
    local MAX_SPEED = 30
    local THRUSTER_MAX_SPEED = 15
    local MOVEMENT_FRICTION = 0.02
    local THRUSTER_DECCEL = 0.1
    local MOUSE_TURN_SPEED = 0.2
    local KEYBOARD_TURN_SPEED = 2
    local BRAKE_FRICTION = 0.2
    local BULLET_VEL = 10
    local MAX_BULLETS_AMT = 15
    local EXPLODE_DUR = 2
    local CAMERAFOCUSACCEL = 1
    local FORWARD_THRUSTER_MAX_EMISSION = 50000
    
    local movedUp = false
    local movedDown = false
    local right, left
    local mouseNormalization = 1

    local CameraRefPrevX = x
    local CameraRefPrevY = y
    local CameraRefNewX = x
    local CameraRefNewY = y

    local explosionParticles = NewParticleSystem({{image=love.graphics.newImage('background.png'), width=10}})
    explosionParticles:setDurationRange(EXPLODE_DUR / 2, EXPLODE_DUR)
    explosionParticles:setSpeedRange(0.5, 1)

    local forwardThrusterParticles = NewParticleSystem({{image=love.graphics.newImage('particle.png'), width=8}})
    forwardThrusterParticles:setDurationRange(1, 2)

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
        afterThrust = 0,
        beforeThrust = 0,
        deccelerating = false,
        accelerating = false,
        inDrive = false,
        inReverse = false,
        dockedPlanet = nil,
        docked = false,
        undocked = true,
        docking = false,
        undocking = false,

        MAX_SPEED = MAX_SPEED,
        MOUSE_TURN_SPEED = MOUSE_TURN_SPEED,
        KEYBOARD_TURN_SPEED = KEYBOARD_TURN_SPEED,
        ACCEL_SPEED = ACCEL_SPEED,
        MAX_BULLETS_AMT = MAX_BULLETS_AMT,
        EXPLODE_DUR = EXPLODE_DUR,

        radius = radius,
        drift = drift or false,
        exploding = false,
        explodeTime = 0,

        bullets = {},
        thrust = {x=0, y=0, friction=MOVEMENT_FRICTION},
        thruster = {x=0, y=0, maxSpeed=THRUSTER_MAX_SPEED, accel=THRUSTER_ACCEL, deccel=THRUSTER_DECCEL},
        mainPlotPoints = {0, 0, 0, 0, 0, 0},
        angle = 0,
        
        color = color or {r = 1, g = 0.8, b = 0.5},

        draw = function (self)
            if #self.bullets > 0 then
                for _, bullet in ipairs(self.bullets) do
                    bullet:draw()
                end
            end
            -- love.graphics.printf(math.ceil(relMouseAngle), 100, 0, 200, 'center')
            if not self.exploding then
                local x_dir = math.cos(math.rad(self.angle + 90))
                local y_dir = math.sin(math.rad(self.angle + 90))

                self.mainPlotPoints = {
                    self.x + ((4 / 3) * self.radius) * x_dir, self.y - ((4 / 3) * self.radius) * y_dir,
                    self.x - self.radius * ((2 / 3) * x_dir + y_dir), self.y + self.radius * ((2 / 3) * y_dir - x_dir),
                    self.x - self.radius * ((2 / 3) * x_dir - y_dir), self.y + self.radius * ((2 / 3) * y_dir + x_dir),
                }
                
                forwardThrusterParticles:draw()
                love.graphics.setColor(self.color.r, self.color.g, self.color.b)
                love.graphics.polygon('fill', self.mainPlotPoints)
            end
            explosionParticles:draw()
            
            if DEBUGGING then
                love.graphics.setLineWidth(1)
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('line', self.x, self.y, self.radius)
            end
        end,

        startDock = function (self, planet)
            self.dockedPlanet = planet
            self.docking = true
            self.undocked = false
        end,

        startUndock = function (self)
            self.undocking = true
            self.docked = false
        end,

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

        turnPlayer = function (self, dir)
            if not self.exploding then
                self.angle = self.angle + (self.KEYBOARD_TURN_SPEED * dir)
            end
        end,
        
        movePlayer = function (self)
            self.angle = self.angle % 360
            
            if not self.exploding then
                self.x = self.x + self.thrust.x
                self.y = self.y + self.thrust.y
            end
        end,
        
        onMovePlayer = function (self, dir)
            if not self.exploding then
                if self.drift then
                    -- self.thrust.x = Clamp(self.thrust.x + (math.cos(math.rad(self.angle + 90)) * (self.thrust.friction + 1) * dir * self.ACCEL_SPEED), -self.MAX_SPEED, self.MAX_SPEED)
                    -- self.thrust.y = Clamp(self.thrust.y - (math.sin(math.rad(self.angle + 90)) * (self.thrust.friction + 1) * dir * self.ACCEL_SPEED), -self.MAX_SPEED, self.MAX_SPEED)
                    self.thruster.x = math.cos(math.rad(self.angle + 90)) * (self.thruster.deccel + 1) * dir * self.thruster.accel--Clamp(self.thruster.x + (math.cos(math.rad(self.angle + 90)) * (self.thruster.deccel + 1) * dir * self.thruster.accel), -self.thruster.maxSpeed, self.thruster.maxSpeed)
                    self.thruster.y = -math.sin(math.rad(self.angle + 90)) * (self.thruster.deccel + 1) * dir * self.thruster.accel--Clamp(self.thruster.y - (math.sin(math.rad(self.angle + 90)) * (self.thruster.deccel + 1) * dir * self.thruster.accel), -self.thruster.maxSpeed, self.thruster.maxSpeed)
                else
                    self.thrust.x = self.MAX_SPEED * math.cos(math.rad(self.angle + 90)) * dir / DT
                    self.thrust.y = -self.MAX_SPEED * math.sin(math.rad(self.angle + 90)) * dir / DT
                end
                -- self.thrust.x = self.thrust.x * mouseNormalization
                -- self.thrust.y = self.thrust.y * mouseNormalization
                self.thruster.x = self.thruster.x * mouseNormalization
                self.thruster.y = self.thruster.y * mouseNormalization

            end
        end,

        onBrakesPressed = function (self)
            if not self.exploding then
                local thruster_x_dir = -(self.thruster.x * (BRAKE_FRICTION + 1)) * self.thruster.deccel
                local thruster_y_dir = -(self.thruster.y * (BRAKE_FRICTION + 1)) * self.thruster.deccel

                self.thruster.x = self.thruster.x + thruster_x_dir
                self.thruster.y = self.thruster.y + thruster_y_dir

                local thrust_x_dir = -(self.thrust.x * (BRAKE_FRICTION + 1)) * self.thrust.friction
                local thrust_y_dir = -(self.thrust.y * (BRAKE_FRICTION + 1)) * self.thrust.friction

                self.thrust.x = self.thrust.x + thrust_x_dir
                self.thrust.y = self.thrust.y + thrust_y_dir
            end
        end,

        onStopPlayer = function (self)
            if not self.exploding then
                local thruster_x_dir = -self.thruster.x * self.thruster.deccel
                local thruster_y_dir = -self.thruster.y * self.thruster.deccel

                self.thruster.x = self.thruster.x + thruster_x_dir
                self.thruster.y = self.thruster.y + thruster_y_dir

                local thrust_x_dir = -self.thrust.x * self.thrust.friction
                local thrust_y_dir = -self.thrust.y * self.thrust.friction

                self.thrust.x = self.thrust.x + thrust_x_dir
                self.thrust.y = self.thrust.y + thrust_y_dir
            end
        end,

        explode = function (self)
            self.exploding = true
        end,
        
        updatePlayerWordlProxy = function (self)
            self.x = self.x + worldDirection.x
            self.y = self.y + worldDirection.y
        end,

        updateWorldDir = function (self)
            CameraRefPrevX = self.x
            CameraRefPrevY = self.y
            
            local dx = CameraRefNewX - CameraRefPrevX
            local dy = CameraRefNewY - CameraRefPrevY
            
            worldDirection.x = dx * CAMERAFOCUSACCEL
            worldDirection.y = dy * CAMERAFOCUSACCEL
            
            self:updatePlayerWordlProxy()
            
            CameraRefNewX = self.x
            CameraRefNewY = self.y
            
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
            local planetPlayerAngle = CalculateAngle(self.dockedPlanet.x, self.dockedPlanet.y, self.x, self.y) + 90
            local distanceBetweenEnds = CalculateDistance(self.dockedPlanet.x + math.cos(math.rad(planetPlayerAngle)) * self.dockedPlanet.radius,
                                                            self.dockedPlanet.y - math.sin(math.rad(planetPlayerAngle)) * self.dockedPlanet.radius,
                                                            self.x + math.cos(math.rad(playerPlanetAngle)) * self.radius,
                                                            self.y - math.sin(math.rad(playerPlanetAngle)) * self.radius)

            if self.docking then
                local distanceBetweenEndAndCenter = CalculateDistance(self.dockedPlanet.x,
                                                                        self.dockedPlanet.y,
                                                                        self.x + math.cos(math.rad(playerPlanetAngle)) * self.radius,
                                                                        self.y - math.sin(math.rad(playerPlanetAngle)) * self.radius)
                
                
                local angle = CalculateAngle(self.dockedPlanet.x, self.dockedPlanet.y, self.x, self.y) % 360
                self.angle = CalculateAngleLerp(self.angle, angle, 0.1)
                local dAngle = math.abs(math.floor(self.angle) - math.floor(angle))

                if dAngle <= 5 then
                    self:onMovePlayer(-1)
                end
                
                if distanceBetweenEnds <= 1 or distanceBetweenEndAndCenter <= self.dockedPlanet.radius then
                    if dAngle >= 20 then
                        self:explode()
                        return
                    end
                    self.docked = true
                    self.undocked = false
                    self.docking = false
                end
            end

            if self.docked then
                self.thrust.x = 0
                self.thrust.y = 0

                local planetsEdgeX = self.dockedPlanet.x + math.cos(math.rad(planetPlayerAngle)) * self.dockedPlanet.radius
                local planetsEdgeY = self.dockedPlanet.y - math.sin(math.rad(planetPlayerAngle)) * self.dockedPlanet.radius
                local playersEdgeX = -math.cos(math.rad(playerPlanetAngle)) * self.radius
                local playersEdgeY = math.sin(math.rad(playerPlanetAngle)) * self.radius
                
                self.x = planetsEdgeX + playersEdgeX
                self.y = planetsEdgeY + playersEdgeY
                self.angle = (playerPlanetAngle + 90) % 360
                
                if love.keyboard.isDown('z') then
                    self:startUndock()
                end
            end

            if self.undocking then
                local Fx, Fy = CalculateTwoBodyVextor(self.dockedPlanet, self)
                
                self.thruster.x = self.thruster.x - Fx
                self.thruster.y = self.thruster.y - Fy

                self.x = self.x + self.thrust.x * DT
                self.y = self.y + self.thrust.y * DT
            end
            
            if distanceBetweenEnds > PLAYER_DOCKING_DISTANCE then
                self.undocked = true
                self.undocking = false
                self.docked = false
                self.dockedPlanet = nil
            end
        end,

        update = function (self)
            movedUp = false
            movedDown = false
            
            self.thrust.x = Clamp(self.thrust.x + self.thruster.x, -self.MAX_SPEED, self.MAX_SPEED)
            self.thrust.y = Clamp(self.thrust.y + self.thruster.y, -self.MAX_SPEED, self.MAX_SPEED)

            forwardThrusterParticles:setPosition(self.x + math.cos(math.rad((self.angle - 90) % 360)) * self.radius / 2, self.y - math.sin(math.rad((self.angle - 90) % 360)) * self.radius / 2)
            forwardThrusterParticles:emitEverySecond(FORWARD_THRUSTER_MAX_EMISSION * math.sqrt((self.thruster.y ^ 2) + (self.thruster.x ^ 2)) / self.thruster.maxSpeed)
            forwardThrusterParticles:setAngleRange(self.angle - 10, self.angle + 10)
            forwardThrusterParticles:update()
            explosionParticles:update()

            if self.undocked or self.undocking then
                for _, ups in ipairs(self.up) do
                    if love.keyboard.isDown(ups)then
                        if not self.inReverse and not self.inDrive then
                            self.inDrive = true
                        end
                        self.yDirection = 1
                        if self.deccelerating and self.accelerating then
                            self.deccelerating = false
                            if self.inReverse then
                                self.inReverse = false
                                self.inDrive = true
                            end
                        end
                        movedUp = true
                        break
                    end
                end
                for _, downs in ipairs(self.down) do
                    if love.keyboard.isDown(downs)then
                        if not self.inReverse and not self.inDrive then
                            self.inReverse = true
                        end
                        self.yDirection = -1
                        if self.deccelerating and self.accelerating then
                            self.deccelerating = false
                            if self.inDrive then
                                self.inReverse = true
                                self.inDrive = false
                            end
                        end
                        movedDown = true
                        break
                    end
                end
            end
            
            if self.afterThrust - self.beforeThrust < 0 then
                self.deccelerating = true
            end

            if not movedUp and not movedDown then
                self:onStopPlayer()
            else
                self.beforeThrust = math.sqrt(self.thrust.x^2 + self.thrust.y^2)
                self:onMovePlayer(self.yDirection)
                self.afterThrust = math.sqrt(self.thrust.x^2 + self.thrust.y^2) 
            end
            
            self.accelerating = self.afterThrust - self.beforeThrust > 0
            
            if self.undocked then
                for _, brakes in ipairs(self.brake) do
                    if love.keyboard.isDown(brakes)then
                        self:onBrakesPressed()
                        break
                    end
                end
            end
            
            if self.undocked then
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
            
            if not self.undocked then
                self:updateDockingProcedure()
            end
            
            if self.exploding then
                explosionParticles:setPosition(self.x, self.y)
                if #explosionParticles.particles == 0 then
                    explosionParticles:emitOnce(150) 
                end
                self.explodeTime = self.explodeTime + DT
                if self.explodeTime >= EXPLODE_DUR then
                    self.explodeTime = 0
                    STATESMACHINE:setState('restart')
                end
            end
            
            self:updateWorldDir()
            if self.undocking or self.undocked or self.docking then
                self:movePlayer()
            end
            self:updateBullets()
        end
    }
end


return Player

