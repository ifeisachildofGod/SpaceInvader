local list        =   require 'list'
local objects     =   require 'objects'
local calculate   =   require 'calculate'

local BULLET_VEL = 20
local MAX_BULLETS_AMT = 15

return {
    ---@param x number
    ---@param y number
    ---@param radius number
    ---@param color? table
    ---@param control? string|table
    ---@param moveUpFunc? fun(): boolean
    ---@param moveDownFunc? fun(): boolean
    ---@param brakesFunc? fun(): boolean
    ---@param shootFunc? fun(): boolean
    ---@param accelAccuracy? number
    ---@param turnSpeedAccuracy? number
    ---@param maxSpeedAccuracy? number
    ---@return table
    playerVehicle = function (x, y, radius, color, control, moveUpFunc, moveDownFunc, brakesFunc, shootFunc, accelAccuracy, turnSpeedAccuracy, maxSpeedAccuracy)
        color = color or {1, 0.8, 0.5}

        accelAccuracy = accelAccuracy or 1
        turnSpeedAccuracy = turnSpeedAccuracy or 1
        maxSpeedAccuracy = maxSpeedAccuracy or 1

        local THRUSTER_ACCEL = calculate.interpolation(0.1, 3, accelAccuracy)
        local MOUSE_TURN_SPEED = calculate.interpolation(0.01, 0.2, turnSpeedAccuracy)
        local KEYBOARD_TURN_SPEED = calculate.interpolation(0.6, 2, turnSpeedAccuracy)
        local ACCEL_RANGE = calculate.interpolation(1, 6, accelAccuracy)
        local BRAKE_FRICTION = 0.2
        local MASS_CONSTANT = 1e-11

        local EXPLODE_DUR = 2
        local FORWARD_THRUSTER_MAX_EMISSION = 50000
        local REVERSE_THRUSTER_MAX_EMISSION = 40000
        
        local movedUp = false
        local movedDown = false
        local moveRightFunc, moveLeftFunc = nil, nil
        local mouseNormalization = 1

        local updatedExplosion = false
        local maxThrusterAccel = THRUSTER_ACCEL + ACCEL_RANGE
        
        local explosionParticles = objects.particleSystem({{image=love.graphics.newImage('images/background.png'), width=10}})
        explosionParticles:setDurationRange(EXPLODE_DUR / 2, EXPLODE_DUR)
        explosionParticles:setSpeedRange(0.5, 1)

        local forwardThrusterParticles = objects.particleSystem({{image=love.graphics.newImage('images/particle.png'), width=8}})
        forwardThrusterParticles:setDurationRange(1, 2)
        
        local reverseThrusterParticles = objects.particleSystem({{image=love.graphics.newImage('images/particle.png'), width=5}})
        reverseThrusterParticles:setDurationRange(1, 2)
        
        if type(control) == 'table' then
            if type(control.right) == 'function' and type(control.left) == 'function' then
                moveRightFunc = control.right
                moveLeftFunc = control.left
            else
                error('Invalid control parameter')
            end
        elseif control ~= 'mouse' and control ~= nil then
            error('Ife, this is an invalid control parameter')
        end
        
        return {
            x = x,
            y = y,
            angle = 0,
            health = 100,
            
            radius = radius,
            mass = MASS_CONSTANT,
            color = {r = color.r or color[1], g = color.g or color[2], b = color.b or color[3]},
            moveUpFunc = moveUpFunc,
            moveDownFunc = moveDownFunc,
            brakesFunc = brakesFunc,
            shootFunc = shootFunc,
            moveRightFunc = moveRightFunc,
            moveLeftFunc = moveLeftFunc,

            mouseAngle = 0,
            yDirection = 0,
            dockedPlanet = nil,
            docked = false,
            undocked = true,
            docking = false,
            destroyed = false,
            undocking = false,
            setDockingAngle = false,

            gettingDestroyed = false,
            explodeTime = 0,
            undockingAngle = 0,
            dockingAngle = 0,
            continueUndocking = true,
            accelAccelerator = 0.05,
            
            maxThrusterAccel = maxThrusterAccel,
            explosionParticles = explosionParticles,

            bullets = {},
            thrust = {x=0, y=0, friction=0.02, maxSpeed=600},
            forwardThruster = {x=0, y=0, accel=THRUSTER_ACCEL, deccel=0.5, particles = forwardThrusterParticles},
            reverseThruster = {x=0, y=0, accel=THRUSTER_ACCEL, deccel=0.5, particles = reverseThrusterParticles},
            mainPlotPoints = {0, 0, 0, 0, 0, 0},

            -- Draw
            draw = function (self)
                self:drawBullets()
                self:drawParticles()
                self:drawPlayer()
            end,
            
            drawParticles = function (self)
                if not self.gettingDestroyed then
                    self.forwardThruster.particles:draw()
                    self.reverseThruster.particles:draw()
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
                if not self.gettingDestroyed then
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
                if not (self.gettingDestroyed or self.destroyed) then
                    if not self.undocked then
                        self:updateDockingProcedure()
                    end
    
                    self:movePlayer()
                end
                self:updateParticles()
                self:updateBullets()
                self:updateExplosionProcedures()
            end,

            updateExplosionProcedures = function (self)
                if self.gettingDestroyed then
                    if not updatedExplosion then
                        self.explosionParticles:setPosition(self.x, self.y)
                        self.explosionParticles:emitOnce(150)
                        updatedExplosion = true
                    end
                    for _, particle in ipairs(self.explosionParticles.particles) do
                        particle.x = particle.x + WorldDirection.x
                        particle.y = particle.y + WorldDirection.y
                    end

                    self.explodeTime = self.explodeTime + DT
                    if self.explodeTime >= EXPLODE_DUR then
                        self.explodeTime = 0
                        self.destroyed = true
                    end
                end
            end,
            
            updateInput = function (self)
                if not self.gettingDestroyed then
                    movedUp = false
                    movedDown = false

                    if not self.docking then
                        if self.moveUpFunc ~= nil and self.moveUpFunc() then
                            self.yDirection = 1
                            movedUp = true
                        end

                        if not self.docked and not self.undocking then
                            if self.moveDownFunc ~= nil and self.moveDownFunc() then
                                self.yDirection = -1
                                movedDown = true
                            end
                        else
                            self:releaseReverseThrusters()
                        end

                        if self.brakesFunc ~= nil and self.brakesFunc() then
                            self:onBrakesPressed()
                        end
                    end
                    
                    if self.undocked then
                        if control == 'mouse' then
                            local normalizationCenterOffset = radius / 2
                            mouseNormalization = math.min((calculate.distance(love.mouse.getX(), love.mouse.getY(), self.x, self.y)) / normalizationCenterOffset, 1)

                            self.mouseAngle = self.mouseAngle - (self.mouseAngle - calculate.angle(self.x, self.y, love.mouse.getX(), love.mouse.getY()) * mouseNormalization)
                            
                            self.angle = calculate.angleLerp(self.angle, self.mouseAngle, MOUSE_TURN_SPEED)
                        else
                            if self.moveLeftFunc ~= nil and self.moveLeftFunc() then
                                self:turnPlayer(1.4)
                            end

                            if self.moveRightFunc ~= nil and self.moveRightFunc() then
                                self:turnPlayer(-1.4)
                            end
                        end
                    end

                    if self.shootFunc ~= nil and self.shootFunc() then
                        if not self.shotBullet then
                            self:addBullet()
                            self.shotBullet = true
                        end
                    else
                        self.shotBullet = false
                    end
                end
            end,
            
            updateParticles = function (self)
                if not self.gettingDestroyed then
                    local fwThrusterAngle = calculate.angle(self.forwardThruster.x, self.forwardThruster.y)
                    local rvThrusterAngle = calculate.angle(self.reverseThruster.x, self.reverseThruster.y)
                    
                    self.forwardThruster.particles:setPosition(self.x + math.cos(math.rad((fwThrusterAngle - 90) % 360)) * self.radius / 2, self.y - math.sin(math.rad((fwThrusterAngle - 90) % 360)) * self.radius / 2)                    
                    self.forwardThruster.particles:emitEverySecond(FORWARD_THRUSTER_MAX_EMISSION * calculate.distance(self.forwardThruster.x, self.forwardThruster.y) / self.thrust.maxSpeed)
                    self.forwardThruster.particles:setAngleRange(fwThrusterAngle - 30 * 1+(self.forwardThruster.accel / self.maxThrusterAccel) * calculate.distance(self.forwardThruster.x, self.forwardThruster.y) / self.thrust.maxSpeed, fwThrusterAngle + 30 * 1+(self.forwardThruster.accel / self.maxThrusterAccel) * calculate.distance(self.forwardThruster.x, self.forwardThruster.y) / self.thrust.maxSpeed)
                    
                    self.forwardThruster.particles:update()
                    
                    local forwardThrusterLeftX = self.x - (math.cos(math.rad((rvThrusterAngle - 90) % 360)) * self.radius / 2) - (math.cos(math.rad((rvThrusterAngle) % 360)) * self.radius / 2)
                    local forwardThrusterLeftY = self.y + (math.sin(math.rad((rvThrusterAngle - 90) % 360)) * self.radius / 2) + (math.sin(math.rad((rvThrusterAngle) % 360)) * self.radius / 2)
                    local forwardThrusterRightX = self.x - (math.cos(math.rad((rvThrusterAngle - 90) % 360)) * self.radius / 2) + (math.cos(math.rad((rvThrusterAngle) % 360)) * self.radius / 2)
                    local forwardThrusterRightY = self.y + (math.sin(math.rad((rvThrusterAngle - 90) % 360)) * self.radius / 2) - (math.sin(math.rad((rvThrusterAngle) % 360)) * self.radius / 2)
                    local emissionAmt = REVERSE_THRUSTER_MAX_EMISSION * math.sqrt((self.reverseThruster.y ^ 2) + (self.reverseThruster.x ^ 2)) / self.thrust.maxSpeed
                    self.reverseThruster.particles:setAngleRange((rvThrusterAngle - 180) - 2, (rvThrusterAngle - 180) + 2)
                    self.reverseThruster.particles:setPosition(forwardThrusterLeftX, forwardThrusterLeftY)
                    self.reverseThruster.particles:emitEverySecond(emissionAmt)
                    self.reverseThruster.particles:setPosition(forwardThrusterRightX, forwardThrusterRightY)
                    self.reverseThruster.particles:emitEverySecond(emissionAmt)
                    
                    self.reverseThruster.particles:update()
                end
                self.explosionParticles:update()
            end,

            updateBullets = function (self)
                for index, bullet in ipairs(self.bullets) do
                    if bullet.dist > calculate.distance(SCREEN_WIDTH, SCREEN_HEIGHT) then
                        self:removeBullet(index)
                    else
                        bullet:update()
                    end
                end
            end,
            
            updateDockingProcedure = function (self)
                local playerPlanetAngle = calculate.angle(self.dockedPlanet.x, self.dockedPlanet.y, self.x, self.y) - 90
                
                if self.docking then
                    local angle = (playerPlanetAngle + 90) % 360
                    
                    self.angle = calculate.angleLerp(self.angle, angle, MOUSE_TURN_SPEED)
                    
                    local dAngle = math.abs(math.floor(self.angle) - math.floor(angle))

                    if dAngle <= 5 then
                        self:onMovePlayer(-1)
                    end
                end

                if self.docked then
                    if self.setDockingAngle then
                        self.dockingAngle = (playerPlanetAngle + 90) % 360
                        self.setDockingAngle = false
                    end
                    
                    self.angle = (playerPlanetAngle + 90) % 360
                    
                    local dx, dy = calculate.direction(self.angle)
                    
                    self.x = self.dockedPlanet.x + dx * (self.dockedPlanet.radius + self.radius)
                    self.y = self.dockedPlanet.y + dy * (self.dockedPlanet.radius + self.radius)

                    self.thrust.x = 0
                    self.thrust.y = 0

                    self.forwardThruster.x = 0
                    self.forwardThruster.y = 0

                    self.reverseThruster.x = 0
                    self.reverseThruster.y = 0
                else
                    self.setDockingAngle = true
                end

                if self.undocking then
                    self.forwardThruster.x = math.cos(math.rad(self.undockingAngle)) * self.forwardThruster.accel
                    self.forwardThruster.y = -math.sin(math.rad(self.undockingAngle)) * self.forwardThruster.accel
                    
                    self.thrust.x = calculate.clamp(self.thrust.x + self.forwardThruster.x, -self.thrust.maxSpeed, self.thrust.maxSpeed)
                    self.thrust.y = calculate.clamp(self.thrust.y + self.forwardThruster.y, -self.thrust.maxSpeed, self.thrust.maxSpeed)

                    self.x = self.x + self.thrust.x * DT
                    self.y = self.y + self.thrust.y * DT
                end
                
                local g = math.min(calculate.GRAVITATIONAL_CONSTANT * self.dockedPlanet.mass / self.dockedPlanet.radius^2, 200)
                if calculate.distance(self.x, self.y, self.dockedPlanet.x, self.dockedPlanet.y) - (self.dockedPlanet.radius + self.radius) > g and not self.docked then
                    self:undock()
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
                self.docking = false
                self.docked = false
            end,
            
            undock = function (self)
                self.undocked = true
                self.undocking = false
                self.docked = false
                self.dockedPlanet = nil
            end,
            
            dock = function (self, planet)
                self.docked = true
                self.undocked = false
                self.docking = false
                self.dockedPlanet = planet
            end,

            -- Bullets
            addBullet = function (self)
                if not self.gettingDestroyed then
                    if #self.bullets <= MAX_BULLETS_AMT then
                        table.insert(self.bullets, objects.bullet(self.x + math.cos(math.rad(self.angle + 90)) + self.forwardThruster.x, self.y - math.sin(math.rad(self.angle + 90)) + self.forwardThruster.y, self.angle, 3, BULLET_VEL))
                    end
                end
            end,
            
            removeBullet = function (self, index)
                table.remove(self.bullets, index)
            end,

            -- Player moveement
            turnPlayer = function (self, dir)
                if not self.gettingDestroyed then
                    self.angle = self.angle + (KEYBOARD_TURN_SPEED * dir)
                end
            end,
            
            movePlayer = function (self)
                self.angle = self.angle % 360

                local xMax = math.sqrt(math.abs(self.thrust.maxSpeed^2 - self.thrust.y^2))
                local yMax = math.sqrt(math.abs(self.thrust.maxSpeed^2 - self.thrust.x^2))
                
                self.thrust.x = calculate.clamp(self.thrust.x + self.forwardThruster.x - self.reverseThruster.x, -xMax, xMax)
                self.thrust.y = calculate.clamp(self.thrust.y + self.forwardThruster.y - self.reverseThruster.y, -yMax, yMax)

                if not self.gettingDestroyed then
                    self.x = self.x + self.thrust.x * DT
                    self.y = self.y + self.thrust.y * DT
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
                    self:onMovePlayer(self.yDirection)
                end
            end,
            
            onMovePlayer = function (self, dir)
                if not self.gettingDestroyed then
                    self.undocking = false
                    if self.docked then
                        if dir > 0 then
                            self:startUndock()
                            if self.continueUndocking then
                                self.undockingAngle = (self.angle + 90) % 360
                                self.continueUndocking = false
                            end
                        end
                    else
                        self.continueUndocking = true
                        if dir > 0 then
                            self.forwardThruster.x = math.cos(math.rad(self.angle + 90)) * self.forwardThruster.accel
                            self.forwardThruster.y = -math.sin(math.rad(self.angle + 90)) * self.forwardThruster.accel
                        else
                            self.reverseThruster.x = math.cos(math.rad(self.angle + 90)) * self.reverseThruster.accel
                            self.reverseThruster.y = -math.sin(math.rad(self.angle + 90)) * self.reverseThruster.accel
                        end
                    end
                    self.forwardThruster.x, self.forwardThruster.y = self.forwardThruster.x * mouseNormalization, self.forwardThruster.y * mouseNormalization
                    self.reverseThruster.x, self.reverseThruster.y = self.reverseThruster.x * mouseNormalization, self.reverseThruster.y * mouseNormalization
                end
            end,

            onBrakesPressed = function (self)
                if not self.gettingDestroyed then
                    self:releaseForwardThrusters()
                    local forwardThruster_x_dir = -(self.forwardThruster.x * (BRAKE_FRICTION + 1)) * self.forwardThruster.deccel
                    local forwardThruster_y_dir = -(self.forwardThruster.y * (BRAKE_FRICTION + 1)) * self.forwardThruster.deccel

                    self.forwardThruster.x = self.forwardThruster.x + forwardThruster_x_dir
                    self.forwardThruster.y = self.forwardThruster.y + forwardThruster_y_dir
                    
                    self:releaseReverseThrusters()
                    local reverseThruster_x_dir = -(self.reverseThruster.x * (BRAKE_FRICTION + 1)) * self.reverseThruster.deccel
                    local reverseThruster_y_dir = -(self.reverseThruster.y * (BRAKE_FRICTION + 1)) * self.reverseThruster.deccel
                    
                    self.reverseThruster.x = self.reverseThruster.x + reverseThruster_x_dir
                    self.reverseThruster.y = self.reverseThruster.y + reverseThruster_y_dir
                    
                    self:releasePlayerThrust()
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
            removeEmissionCollisionPlanet = function (self, planet)
                local particleIndex = list.index(self.explosionParticles.collisionBodies, planet)
                if particleIndex ~= -1 then
                    table.remove(self.explosionParticles.collisionBodies, particleIndex)
                end
                
                particleIndex = list.index(self.forwardThruster.particles.collisionBodies, planet)
                if particleIndex ~= -1 then
                    table.remove(self.forwardThruster.particles.collisionBodies, particleIndex)
                end

                particleIndex = list.index(self.reverseThruster.particles.collisionBodies, planet)
                if particleIndex ~= -1 then
                    table.remove(self.reverseThruster.particles.collisionBodies, particleIndex)
                end
            end,

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
                for _, body in ipairs(self.forwardThruster.particles.collisionBodies) do
                    if body == planet then
                        forwardThrusterContainsItAlready = true
                    end
                end
                if not forwardThrusterContainsItAlready then
                    self.forwardThruster.particles:addCollisionBody(planet) 
                end

                local reverseThrusterContainsItAlready = false
                for _, body in ipairs(self.reverseThruster.particles.collisionBodies) do
                    if body == planet then
                        reverseThrusterContainsItAlready = true
                    end
                end
                if not reverseThrusterContainsItAlready then
                    self.reverseThruster.particles:addCollisionBody(planet) 
                end
            end,

            destroy = function (self)
                self.gettingDestroyed = true
                self.health = 0
            end,
            
            damage = function (self, d)
                self.health = self.health - d

                if self.health <= 0 then
                    self:destroy()
                    self.health = 0
                end
            end,

            acceleratePlayer = function (self, dy)
                self.forwardThruster.accel = calculate.clamp(self.forwardThruster.accel + (dy * ACCEL_RANGE * self.accelAccelerator), 0, self.maxThrusterAccel)
                self.reverseThruster.accel = calculate.clamp(self.reverseThruster.accel + (dy * ACCEL_RANGE * self.accelAccelerator), 0, self.maxThrusterAccel)
            end,

        }
    end,
    
    ---@param x number
    ---@param y number
    ---@param radius number
    ---@param control table
    ---@param planet? table
    ---@param color? table
    ---@param jumpFunc? fun(): boolean
    ---@param shootFunc? fun(): boolean
    ---@return table
    player = function (x, y, radius, control, planet, color, jumpFunc, shootFunc)
        jumpFunc = jumpFunc or function () return false end
        shootFunc = shootFunc or function () return false end

        local MASS_CONSTANT = 100
        
        local prevPos = {x = x, y = y}
        local currPos = {x = x, y = y}

        local explosionDur = 3
        local updatedExplosion = false

        local explosionParticles = objects.particleSystem({{image=love.graphics.newImage('images/background.png'), width=10}})
        explosionParticles:setDurationRange(explosionDur / 2, explosionDur)
        explosionParticles:setSpeedRange(0.5, 1)
        if planet ~= nil then
            explosionParticles:addCollisionBody(planet) 
        end
        
        color = color or {1, 0.4, 0.1}
        
        local moveUpFunc, moveDownFunc, moveRightFunc, moveLeftFunc

        if type(control.up) == 'function' then
            moveUpFunc = control.up
            moveDownFunc = control.down
        elseif type(control.right) == 'function' and type(control.left) == 'function' then
            moveRightFunc = control.right
            moveLeftFunc = control.left
        else
            error('Invalid control parameter')
        end
        
        local player = {}

        player = {
            BULLET_VEL = 40,

            x = x,
            y = y,
            radius = radius,
            mass = radius * MASS_CONSTANT,
            angle = 0,
            health = 100,
            
            bullets = {},

            horizontal = {displacement=0, velocity=0, acceleration=2.5, avgVelocity=400, decceleration=0.5},
            vertical = {displacement=0, velocity=0, acceleration=0, targetAcceleration=2, terminalVelocity=20},
            
            moveUpFunc = moveUpFunc,
            moveDownFunc = moveDownFunc,
            moveRightFunc = moveRightFunc,
            moveLeftFunc = moveLeftFunc,
            jumpFunc = jumpFunc,
            shootFunc = shootFunc,

            shotBullet = false,
            onTheGround = true,
            gettingDestroyed = false,
            hasSetDir = false,
            thrust = {x=0, y=0, speed=27, jumpVel=500, gravity=12},
            playersEdge = {x=0, y=0},
            planetsEdge = {x=0, y=0},
            movementPosition = {x=0, y=0, deccel=0.7},
            movementDirection = {x=0, y=0},
            color = {r = color.r or color[1], g = color.g or color[2], b = color.b or color[3]},
            playerPlanetAngle = 0,
            explodeTime = 0,
            inTheAir = false,
            jumped = false,
            canSetInTheAirVar = true,
            
            explosionParticles = explosionParticles,
            
            move = function (self)
                currPos.x, currPos.y = self.x, self.y

                self.vertical.velocity = calculate.clamp(self.vertical.velocity + self.vertical.acceleration, -self.vertical.terminalVelocity, self.vertical.terminalVelocity)
                self.vertical.displacement = self.vertical.displacement + self.vertical.velocity
                
                if self.vertical.displacement >= self.vertical.targetAcceleration then
                    if self.canSetInTheAirVar then
                        self.inTheAir = true
                        self.canSetInTheAirVar = false
                    end
                else
                    self.canSetInTheAirVar = true
                end
                
                -- if self.vertical.displacement > math.sqrt(2 * self.gravity * self.planet.radius) * 10 then
                --     self.planet = nil
                -- end
                
                if self.planet ~= nil then
                    self.horizontal.displacement = (calculate.angle(self.planet.x, self.planet.y, self.x, self.y) - 90) + self.horizontal.velocity
                    self.horizontal.displacement = self.horizontal.displacement % 360
                    
                    self.planetsEdge.x = self.planet.x + math.cos(math.rad(self.horizontal.displacement + 180)) * (self.planet.radius + self.vertical.displacement)
                    self.planetsEdge.y = self.planet.y - math.sin(math.rad(self.horizontal.displacement + 180)) * (self.planet.radius + self.vertical.displacement)
                    self.playersEdge.x = -math.cos(math.rad(self.horizontal.displacement)) * self.radius
                    self.playersEdge.y = math.sin(math.rad(self.horizontal.displacement)) * self.radius
                    
                    if not self.inTheAir then
                        self.x = self.planetsEdge.x + self.playersEdge.x
                        self.y = self.planetsEdge.y + self.playersEdge.y
                        self.thrust.x = 0
                        self.thrust.y = 0
                        self.vertical.displacement = 0
                    else
                        self.vertical.acceleration = 0
                        self.x = self.x + math.cos(math.rad(self.horizontal.displacement + 180)) * self.vertical.velocity
                        self.y = self.y - math.sin(math.rad(self.horizontal.displacement + 180)) * self.vertical.velocity
                    end
                else
                    if not self.hasSetDir then
                        local dX = currPos.x - prevPos.x
                        local dY = currPos.y - prevPos.y
                        
                        self.thrust.x = dX
                        self.thrust.y = dY

                        self.hasSetDir = true
                    end
                end
                
                self.x = self.x + self.thrust.x
                self.y = self.y + self.thrust.y

                prevPos.x, prevPos.y = self.x, self.y
            end,

            drawBullets = function (self)
                if #self.bullets > 0 then
                    for _, bullet in ipairs(self.bullets) do
                        bullet:draw()
                    end
                end
            end,

            updateBullets = function (self)
                for index, bullet in ipairs(self.bullets) do
                    if bullet.dist > SCREEN_WIDTH * 2 then
                        self:removeBullet(index)
                    else
                        if self.planet ~= nil then
                            local Fx = -self.gravity * math.cos(math.rad(calculate.angle(self.planet.x, self.planet.y, self.x, self.y) + 90))
                            local Fy = self.gravity * math.sin(math.rad(calculate.angle(self.planet.x, self.planet.y, self.x, self.y) + 90))
                            
                            bullet.thrust.x = bullet.thrust.x + Fx
                            bullet.thrust.y = bullet.thrust.y + Fy
                        end
                        bullet:update()
                    end
                end
            end,
            
            removeBullet = function (self, index)
                table.remove(self.bullets, index)
            end,
            
            addBullet = function (self, angle)
                if not self.gettingDestroyed then
                    table.insert(self.bullets, objects.bullet(self.x + math.cos(math.rad(angle)), self.y - math.sin(math.rad(angle)), angle, 3, BULLET_VEL))
                end
            end,

            setPlanet = function (self, newPlanet)
                self.planet = newPlanet
                -- if list.index(self.planet.astroBodies, self) == -1 then
                --     table.insert(self.planet.astroBodies, self)
                -- end
                self.gravity = calculate.gravity(self.planet.mass, self.planet.radius)
            end,

            movePlayerHorizontally = function (self, dir)
                self.horizontal.velocity = calculate.lerp(self.horizontal.velocity, -self.horizontal.avgVelocity * dir / self.planet.radius, self.horizontal.acceleration)
            end,
            
            jumpUp = function (self)
                self.onTheGround = false
                self.vertical.acceleration = self.vertical.targetAcceleration
            end,

            draw = function (self)
                if not self.gettingDestroyed then
                    love.graphics.setColor(self.color.r, self.color.g, self.color.b)
                    love.graphics.circle('fill', self.x, self.y, self.radius)
                end
                self.explosionParticles:draw()
                self:drawBullets()
            end,

            update = function (self)
                if self.planet ~= nil and not (self.gettingDestroyed or self.destroyed) then
                    self:move()
                end
                self:updateExplosionProcedures()
                self:updateBullets()
            end,
            
            destroy = function (self)
                self.gettingDestroyed = true
                self.health = 0
            end,
            
            damage = function (self, d)
                self.health = self.health - d
                
                if self.health <= 0 then
                    self:destroy()
                    self.health = 0
                end
            end,

            updateExplosionProcedures = function (self)
                if self.gettingDestroyed then
                    if not updatedExplosion then
                        self.explosionParticles:setPosition(self.x, self.y)
                        self.explosionParticles:emitOnce(150)
                        updatedExplosion = true
                    end
                    for _, particle in ipairs(self.explosionParticles.particles) do
                        particle.x = particle.x + WorldDirection.x
                        particle.y = particle.y + WorldDirection.y
                    end

                    self.explodeTime = self.explodeTime + DT
                    if self.explodeTime >= explosionDur then
                        self.explodeTime = 0
                        self.destroyed = true
                    end
                end
                self.explosionParticles:update()
            end,
            
            updateInput = function (self)
                if self.planet ~= nil and not self.gettingDestroyed then
                    if self.moveUpFunc ~= nil and self.moveDownFunc ~= nil then
                        local moveUp, upAngle = self:moveUpFunc()
                        local moveDown, downAngle = self:moveDownFunc()
                        
                        self.angle = upAngle

                        if moveUp then
                            self:movePlayerHorizontally(math.sin(math.rad(upAngle)))
                        end
                        
                        if moveDown then
                            self:movePlayerHorizontally(-math.sin(math.rad(downAngle)))
                        end
                        
                        self.horizontal.velocity = calculate.lerp(self.horizontal.velocity, 0, self.horizontal.decceleration)
                    elseif self.moveRightFunc ~= nil and self.moveLeftFunc ~= nil then
                        if self.moveRightFunc() then
                            self:movePlayerHorizontally(1)
                            self.angle = 90
                        elseif self.moveLeftFunc() then
                            self:movePlayerHorizontally(-1)
                            self.angle = -90
                        else
                            self.horizontal.velocity = calculate.lerp(self.horizontal.velocity, 0, self.horizontal.decceleration)
                            self.angle = 0
                        end
                    else
                        error('Wrong arguments were passed in for the functions either moveUpFunc, moveRightFunc or moveLeftFunc')
                    end
    
                    if self.jumpFunc() then
                        if not self.jumped and self.onTheGround then
                            self:jumpUp()
                            self.jumped = true
                        end
                    else
                        self.jumped = false
                    end
                    
                    local shot, shootingAngle = self:shootFunc()
                    if shot then
                        if not self.shotBullet then
                            self:addBullet(shootingAngle - 90)
                            self.shotBullet = true
                        end
                    else
                        self.shotBullet = false
                    end
                end
            end,
        }

        if planet ~= nil then
            player:setPlanet(planet)
        end

        return player
    end
}
