
local Player = require 'player'

---comment
---@param x number
---@param y number
---@param radius number
---@param player table
---@param accuracy? number Value between 0 and 1 that determines how accurate the rammer will be
---@return table
local function Rammer(x, y, radius, player, accuracy)
    accuracy = accuracy or 0.5

    local enemy = Player(x, y, radius)

    enemy.player = player
    enemy.speed = 0

    enemy.inacurateAngleChangeVel = 0.001

    enemy.ACCEL_SPEED = 0.0009

    enemy.update = function (self)
        self:updatePlayerWordlProxy()

        if not self.player.exploding and not self.exploding then
            local dx = self.player.x - self.x
            local dy = self.y - self.player.y
            
            ---@diagnostic disable-next-line: deprecated
            local angle = math.deg(math.atan2(dy, dx)) - 90
            
            local rad = self.radius * (2 + (1 - 2) * accuracy)
            local newDY = dy - (math.sin(math.rad(angle + 90)) * rad)
            local newDX = dx + (math.cos(math.rad(angle + 90)) * rad)
            
            ---@diagnostic disable-next-line: deprecated
            angle = math.deg(math.atan2(newDY, newDX)) - 90
            
            self.angle = self.angle + (angle - self.angle) * (self.inacurateAngleChangeVel + (1 - self.inacurateAngleChangeVel) * accuracy)
            self.angle = self.angle % 360

            self.speed = math.min(self.speed + self.ACCEL_SPEED, self.MAX_SPEED)
            
            self.thrust.x = self.speed * math.cos(math.rad(self.angle + 90)) / DT
            self.thrust.y = -self.speed * math.sin(math.rad(self.angle + 90)) / DT
            
            self:movePlayer()
            if CalculateDistance(self.x, self.y, self.player.x, self.player.y) < self.player.radius then
                self:explode()
                self.player:explode()
            end

            for index, bullet in ipairs(self.player.bullets) do
                if CalculateDistance(bullet.x, bullet.y, self.x, self.y) < self.radius then
                    self:explode()
                    table.remove(self.player.bullets, index)
                end
            end
            
        end
    end

    return enemy

end

local function Turett(x, y, radius, player)
    local enemy = Player(x, y, radius, true)
    
    enemy.player = player
    enemy.TURN_SPEED = 0.01
    enemy.MAX_BULLETS_AMT = tonumber(enemy.MAX_BULLETS_AMT / 3)
    enemy.ACCEL_SPEED = enemy.ACCEL_SPEED / 4
    enemy.MAX_SPEED = (enemy.MAX_SPEED / 4) - 5
    enemy.SHOT_RANGE_ANGLE = 45

    enemy.update = function (self)
        self:updatePlayerWordlProxy()
        if not self.player.exploding and not self.exploding then
            self:movePlayer(worldDirection)
            local dx = self.player.x - self.x
            local dy = self.y - self.player.y

            ---@diagnostic disable-next-line: deprecated
            local angle = (math.deg(math.atan2(dy,dx)) - 90) % 360
            self.angle = self.angle + ((angle - self.angle) * self.TURN_SPEED)
            if angle - self.SHOT_RANGE_ANGLE < self.angle and self.angle < angle + self.SHOT_RANGE_ANGLE then
                self:addBullet()
            end
            
        end

        self:updateBullets()

        for index, bullet in ipairs(self.bullets) do
            if CalculateDistance(bullet.x, bullet.y, self.player.x, self.player.y) < self.player.radius then
                self.player:explode()
                table.remove(self.bullets, index)
            end
        end

        for index, bullet in ipairs(self.player.bullets) do
            if CalculateDistance(bullet.x, bullet.y, self.x, self.y) < self.radius then
                self:explode()
                table.remove(self.player.bullets, index)
            end
        end
    end

    return enemy

end


return {Rammer, Turett}
