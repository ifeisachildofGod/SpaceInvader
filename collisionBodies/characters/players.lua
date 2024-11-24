local objects = require 'objects'
local calculate = require 'calculate'
local accecories = require 'accecories'

return {
    ---@param x number
    ---@param y number
    ---@param radius number
    ---@param up? table
    ---@param down? table
    ---@param control? table|string
    ---@param color? string
    ---@param brake? table
    ---@param accelAccuracy? number
    ---@param turnSpeedAccuracy? number
    ---@param maxSpeedAccuracy? number
    ---@return table
    playerVehicle = function (x, y, radius, color, control, up, down, brake, accelAccuracy, turnSpeedAccuracy, maxSpeedAccuracy)
        local defaultAccuracy = 1
        
        accelAccuracy = accelAccuracy or defaultAccuracy
        turnSpeedAccuracy = turnSpeedAccuracy or defaultAccuracy
        maxSpeedAccuracy = maxSpeedAccuracy or defaultAccuracy

        local MAX_SPEED = calculate.interpolation(100, 600, maxSpeedAccuracy)
        local THRUSTER_ACCEL = calculate.interpolation(1, 3, accelAccuracy)
        local THRUSTER_MAX_SPEED = calculate.interpolation(50, 150, maxSpeedAccuracy)
        local MOUSE_TURN_SPEED = calculate.interpolation(0.04, 0.2, turnSpeedAccuracy)
        local KEYBOARD_TURN_SPEED = calculate.interpolation(0.6, 2, turnSpeedAccuracy)
        local ACCEL_RANGE = 200
        local MOVEMENT_FRICTION = 0.02
        local THRUSTER_DECCEL = 0.5
        local BRAKE_FRICTION = 0.2
        local BULLET_VEL = 10
        local MAX_BULLETS_AMT = 15
        local EXPLODE_DUR = 2
        local FORWARD_THRUSTER_MAX_EMISSION = 50000
        local REVERSE_THRUSTER_MAX_EMISSION = 40000
        local MASS_CONSTANT = 0.0000000000000000000001
        
        local movedUp = false
        local movedDown = false
        local right, left
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
            angle = 0,
            radius = radius,
            mass = radius * MASS_CONSTANT,
            color = color or {r = 1, g = 0.8, b = 0.5},
            
            up = up or {'up', 'w'},
            down = down or {'down', 's'},
            right = right,
            left = left,
            brake = brake or {2},
            mouseAngle = 0,
            yDirection = 0,
            dockedPlanet = nil,
            docked = false,
            undocked = true,
            docking = false,
            destroyed = false,
            undocking = false,

            MOUSE_TURN_SPEED = MOUSE_TURN_SPEED,
            KEYBOARD_TURN_SPEED = KEYBOARD_TURN_SPEED,
            MAX_BULLETS_AMT = MAX_BULLETS_AMT,
            EXPLODE_DUR = EXPLODE_DUR,
            COLLISION_VELOCITY = 100,
            AUTO_DOCKING_DISTANCE = 100,

            gettingDestroyed = false,
            explodeTime = 0,
            undockingAngle = 0,
            continueUndocking = true,
            
            maxThrusterAccel = maxThrusterAccel,
            explosionParticles = explosionParticles,

            bullets = {},
            thrust = {x=0, y=0, friction=MOVEMENT_FRICTION, maxSpeed=MAX_SPEED},
            forwardThruster = {x=0, y=0, maxSpeed=THRUSTER_MAX_SPEED, accel=THRUSTER_ACCEL, deccel=THRUSTER_DECCEL, particles = forwardThrusterParticles, accelAccelerator=9},
            reverseThruster = {x=0, y=0, maxSpeed=THRUSTER_MAX_SPEED, accel=THRUSTER_ACCEL, deccel=THRUSTER_DECCEL, particles = reverseThrusterParticles},
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
                self.thrust.x = calculate.clamp(self.thrust.x + self.forwardThruster.x - self.reverseThruster.x, -self.thrust.maxSpeed, self.thrust.maxSpeed)
                self.thrust.y = calculate.clamp(self.thrust.y + self.forwardThruster.y - self.reverseThruster.y, -self.thrust.maxSpeed, self.thrust.maxSpeed)
                
                if not self.undocked then
                    self:updateDockingProcedure()
                end

                self:movePlayer()

                self:updateParticles()
                self:updateInput()
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
                    
                    local condition

                    if not self.docking then
                        for _, ups in ipairs(self.up) do
                            if type(ups) == "number" then
                                condition = love.mouse.isDown(ups)
                            elseif type(ups) == "string" then
                                condition = love.keyboard.isDown(ups)
                            else
                                error('Invalid input constant '..ups)
                            end
                            
                            if condition then
                                self.yDirection = 1
                                movedUp = true
                                break
                            end
                        end
                        
                        if not self.docked and not self.undocking then
                            for _, downs in ipairs(self.down) do
                                if type(downs) == "number" then
                                    condition = love.mouse.isDown(downs)
                                elseif type(downs) == "string" then
                                    condition = love.keyboard.isDown(downs)
                                else
                                    error('Invalid input constant '..downs)
                                end
        
                                if condition then
                                    self.yDirection = -1
                                    movedDown = true
                                    break
                                end
                            end 
                        else
                            self:releaseReverseThrusters()
                        end

                        for _, brakes in ipairs(self.brake) do
                            if type(brakes) == "number" then
                                condition = love.mouse.isDown(brakes)
                            elseif type(brakes) == "string" then
                                condition = love.keyboard.isDown(brakes)
                            else
                                error('Invalid input constant '..brakes)
                            end
        
                            if condition then
                                self:onBrakesPressed()
                                break
                            end
                        end
                    end
                    
                    if self.undocked then
                        if control == 'mouse' then
                            local normalizationCenterOffset = radius / 2
                            mouseNormalization = math.min((calculate.distance(love.mouse.getX(), love.mouse.getY(), self.x, self.y)) / normalizationCenterOffset, 1)
            
                            local dx = love.mouse.getX() - self.x
                            local dy = self.y - love.mouse.getY()
                
                            ---@diagnostic disable-next-line: deprecated
                            self.mouseAngle = self.mouseAngle - ((self.mouseAngle - ((math.deg(math.atan2(dy,dx)) - 90) % 360)) * mouseNormalization)
                            self.angle = calculate.angleLerp(self.angle, self.mouseAngle, MOUSE_TURN_SPEED)
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
                if not self.gettingDestroyed then
                    self.forwardThruster.particles:setPosition(self.x + math.cos(math.rad((self.angle - 90) % 360)) * self.radius / 4, self.y - math.sin(math.rad((self.angle - 90) % 360)) * self.radius / 4)
                    self.forwardThruster.particles:emitEverySecond(FORWARD_THRUSTER_MAX_EMISSION * math.sqrt((self.forwardThruster.y ^ 2) + (self.forwardThruster.x ^ 2)) / self.forwardThruster.maxSpeed)
                    self.forwardThruster.particles:setAngleRange(self.angle - 10, self.angle + 10)
                    
                    self.forwardThruster.particles:update()
                    
                    local forwardThrusterLeftX = self.x - (math.cos(math.rad((self.angle - 90) % 360)) * self.radius / 2) - (math.cos(math.rad((self.angle) % 360)) * self.radius / 2)
                    local forwardThrusterLeftY = self.y + (math.sin(math.rad((self.angle - 90) % 360)) * self.radius / 2) + (math.sin(math.rad((self.angle) % 360)) * self.radius / 2)
                    local forwardThrusterRightX = self.x - (math.cos(math.rad((self.angle - 90) % 360)) * self.radius / 2) + (math.cos(math.rad((self.angle) % 360)) * self.radius / 2)
                    local forwardThrusterRightY = self.y + (math.sin(math.rad((self.angle - 90) % 360)) * self.radius / 2) - (math.sin(math.rad((self.angle) % 360)) * self.radius / 2)
                    local emissionAmt = REVERSE_THRUSTER_MAX_EMISSION * math.sqrt((self.reverseThruster.y ^ 2) + (self.reverseThruster.x ^ 2)) / self.reverseThruster.maxSpeed
                    self.reverseThruster.particles:setAngleRange((self.angle - 180) - 2, (self.angle - 180) + 2)
                    self.reverseThruster.particles:setPosition(forwardThrusterLeftX, forwardThrusterLeftY)
                    self.reverseThruster.particles:emitEverySecond(emissionAmt)
                    self.reverseThruster.particles:setPosition(forwardThrusterRightX, forwardThrusterRightY)
                    self.reverseThruster.particles:emitEverySecond(emissionAmt)
                    
                    self.reverseThruster.particles:update()
                end
                self.explosionParticles:update()
            end,

            updateBullets = function (self)
                if #self.bullets > 0 then
                    for index, bullet in ipairs(self.bullets) do
                        if bullet:getDist() > love.graphics.getWidth() * 1.5 then
                            self:removeBullet(index)
                        else
                            bullet:update(WorldDirection)
                        end
                    end
                end
            end,
            
            updateDockingProcedure = function (self)
                local playerPlanetAngle = calculate.angle(self.dockedPlanet.x, self.dockedPlanet.y, self.x, self.y) - 90
                
                if self.docking then
                    local angle = (playerPlanetAngle + 90) % 360
                    self.angle = calculate.angleLerp(self.angle, angle, 0.1)
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
                    
                    self.thrust.x = 0
                    self.thrust.y = 0
                end

                if self.undocking then
                    self.forwardThruster.x = math.cos(math.rad(self.undockingAngle)) * self.forwardThruster.accel
                    self.forwardThruster.y = -math.sin(math.rad(self.undockingAngle)) * self.forwardThruster.accel
                    
                    self.thrust.x = calculate.clamp(self.thrust.x + self.forwardThruster.x, -self.thrust.maxSpeed, self.thrust.maxSpeed)
                    self.thrust.y = calculate.clamp(self.thrust.y + self.forwardThruster.y, -self.thrust.maxSpeed, self.thrust.maxSpeed)

                    self.x = self.x + self.thrust.x * DT
                    self.y = self.y + self.thrust.y * DT
                end

                if calculate.distance(self.x, self.y, self.dockedPlanet.x, self.dockedPlanet.y) - (self.dockedPlanet.radius + self.radius) > 4 then
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
            end,

            -- Bullets
            removeBullet = function (self, index)
                table.remove(self.bullets, index)
            end,

            addBullet = function (self)
                if not self.gettingDestroyed then
                    if #self.bullets <= self.MAX_BULLETS_AMT then
                        table.insert(self.bullets, accecories.bullet(self.x + math.cos(math.rad(self.angle + 90)), self.y - math.sin(math.rad(self.angle + 90)), self.angle, 3, BULLET_VEL))
                    end
                end
            end,

            -- Player moveement
            turnPlayer = function (self, dir)
                if not self.gettingDestroyed then
                    self.angle = self.angle + (self.KEYBOARD_TURN_SPEED * dir)
                end
            end,
            
            movePlayer = function (self)
                self.angle = self.angle % 360
                
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

                    self.forwardThruster.x = self.forwardThruster.x * mouseNormalization
                    self.forwardThruster.y = self.forwardThruster.y * mouseNormalization
                    self.reverseThruster.x = self.reverseThruster.x * mouseNormalization
                    self.reverseThruster.y = self.reverseThruster.y * mouseNormalization
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
            end,
            
            acceleratePlayer = function (self, dy)
                self.forwardThruster.accel = calculate.clamp(self.forwardThruster.accel + (dy * ACCEL_RANGE / self.forwardThruster.accelAccelerator), 0, self.maxThrusterAccel)
                self.reverseThruster.accel = calculate.clamp(self.reverseThruster.accel + (dy * ACCEL_RANGE / self.forwardThruster.accelAccelerator), 0, self.maxThrusterAccel)
            end

        }
    end,
    
    ---@param x number
    ---@param y number
    ---@param radius number
    ---@param planet table
    ---@param color? table
    ---@return table
    player = function (x, y, radius, planet, color)
        local MASS_CONSTANT = 100

        local explosionDur = 3
        local updatedExplosion = false

        local explosionParticles = objects.particleSystem({{image=love.graphics.newImage('images/background.png'), width=10}})
        explosionParticles:setDurationRange(explosionDur / 2, explosionDur)
        explosionParticles:setSpeedRange(0.5, 1)
        explosionParticles:addCollisionBody(planet)

        color = color or {1, 0.4, 0.1}
        
        local player = {}

        player = {
            x = x,
            y = y,
            radius = radius,
            mass = radius * MASS_CONSTANT,
            angle = {displacement=0, velocity=0, acceleration=0.09, avgVelocity=400},
            jump = {velocity=0, acceleration=0, targetAcceleration=6, terminalVelocity=20},
            planetDisplacement = 0,

            onTheGround = true,
            gettingDestroyed = false,
            thrust = {x=0, y=0, speed=27, jumpVel=500, gravity=12},
            playersEdge = {x=0, y=0},
            planetsEdge = {x=0, y=0},
            movementPosition = {x=0, y=0, deccel=0.7},
            movementDirection = {x=0, y=0},
            color = {r = color.r or color[1], g = color.g or color[2], b = color.b or color[3]},
            playerPlanetAngle = 0,
            explodeTime = 0,
            
            explosionParticles = explosionParticles,
            
            move = function (self)
                self.jump.velocity = calculate.clamp(self.jump.velocity + self.jump.acceleration, -self.jump.terminalVelocity, self.jump.terminalVelocity)
                self.planetDisplacement = self.planetDisplacement + self.jump.velocity

                self.angle.displacement = (calculate.angle(self.planet.x, self.planet.y, self.x, self.y) - 90) + self.angle.velocity
                self.angle.displacement = self.angle.displacement % 360

                self.planetsEdge.x = self.planet.x + math.cos(math.rad(self.angle.displacement + 180)) * (self.planet.radius + self.planetDisplacement)
                self.planetsEdge.y = self.planet.y - math.sin(math.rad(self.angle.displacement + 180)) * (self.planet.radius + self.planetDisplacement)
                self.playersEdge.x = -math.cos(math.rad(self.angle.displacement)) * self.radius
                self.playersEdge.y = math.sin(math.rad(self.angle.displacement)) * self.radius
                
                self.movementPosition.x = self.movementPosition.x + self.thrust.x * DT
                self.movementPosition.y = self.movementPosition.y + self.thrust.y * DT
                
                self.x = self.planetsEdge.x + self.playersEdge.x
                self.y = self.planetsEdge.y + self.playersEdge.y
            end,
            
            setPlanet = function (self, newPlanet)
                self.planet = newPlanet
                -- if ListIndex(self.planet.astroBodies, self) == -1 then
                --     table.insert(self.planet.astroBodies, self)
                -- end
                self.gravity = calculate.gravity(self.planet.mass, self.planet.radius)
            end,

            movePlayerHorizontally = function (self, dir)
                self.angle.velocity = calculate.lerp(self.angle.velocity, -self.angle.avgVelocity * dir / self.planet.radius, self.angle.acceleration)
            end,
            
            jumpUp = function (self)
                self.onTheGround = false
                self.jump.acceleration = self.jump.targetAcceleration
            end,

            draw = function (self)
                if not self.gettingDestroyed then
                    love.graphics.setColor(self.color.r, self.color.g, self.color.b)
                    love.graphics.circle('fill', self.x, self.y, self.radius)
                end

                self.explosionParticles:draw()
            end,

            update = function (self)
                if self.planet ~= nil then
                    self:move()
                    self:updateInput()
                end
                self:updateExplosionProcedures()
            end,
            
            destroy = function (self)
                self.gettingDestroyed = true
                self.radus = 1
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
                local planetDistance = calculate.distance(self.x, self.y, self.planet.x, self.planet.y) - (self.radius + self.planet.radius) + 1

                if love.keyboard.isDown('d') then
                    self:movePlayerHorizontally(1 / planetDistance)
                elseif love.keyboard.isDown('a') then
                    self:movePlayerHorizontally(-1 / planetDistance)
                else
                    self.angle.velocity = calculate.lerp(self.angle.velocity, 0, self.angle.acceleration / planetDistance)
                end

                if not self.onTheGround then
                    self.jump.acceleration = -self.gravity
                    if self.planetDisplacement <= 0 then
                        self.onTheGround = true
                        self.jump.acceleration = 0
                        self.jump.velocity = 0
                        self.planetDisplacement = 0
                    end
                end
                if love.keyboard.isDown('w') and self.onTheGround then
                    self:jumpUp()
                end
                
            end,
        }
        
        player:setPlanet(planet)

        return player
    end
}
