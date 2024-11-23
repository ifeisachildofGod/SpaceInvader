
function Clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function CalculateDistance(x1, y1, x2, y2)
    local dX = x2 - x1
    local dY = y2 - y1

    return math.sqrt(dX^2 + dY^2)
end

---@overload fun(x: number, y: number)
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number
function CalculateAngle(x1, y1, x2, y2)
    local dx, dy
    
    if x2 ~= nil and y2 ~= nil then
        dx = x2 - x1
        dy = y1 - y2
    else
        dx = x1
        dy = -y1
    end
    
    ---@diagnostic disable-next-line: deprecated
    return (math.deg(math.atan2(dy, dx)) - 90) % 360
end

---@param a1 number
---@param a2 number
---@return number
function CalculateAngleBetween(a1, a2)
    local diff = a2 - a1
    if diff > 180 then
        diff = diff - 360
    elseif diff < -180 then
        diff = diff + 360
    end

    return diff
end

function CalculateAngleLerp(from, to, by)
    return (from + CalculateAngleBetween(from, to) * by) % 360

end

function CalculateListIndex(list, value)
    for i, v in ipairs(list) do
        if value == v then
            return i
        end
    end
    return -1
end

-- Both arguements must have x, y and radius
---@param staticBody table
---@param satelliteBody table
---@return number
---@return number
function CalculateTwoBodyVector(staticBody, satelliteBody)
    local dx = staticBody.x - satelliteBody.x
    local dy = satelliteBody.y - staticBody.y
    local satelliteBodyMass = satelliteBody.mass or satelliteBody.radius
    local staticBodyMass = staticBody.mass or staticBody.radius

    local distanceBetween = math.sqrt(dx^2 + dy^2)
    local udx = dx / distanceBetween
    local udy = dy / distanceBetween

    ---@diagnostic disable-next-line: deprecated
    local theta = math.atan2(udy, udx)
    local force = GRAVITATIONAL_CONSTANT * satelliteBodyMass * staticBodyMass / distanceBetween^2

    local  Fx = force * math.cos(theta)
    local  Fy = -force * math.sin(theta)
    
    return Fx / satelliteBodyMass, Fy / satelliteBodyMass
end

---@param planetaryBody table Must have a radius property
---@return number
function CalculaterEscapeVelocity(planetaryBody)
    local g = (GRAVITATIONAL_CONSTANT * (planetaryBody.radius or planetaryBody.mass)) / planetaryBody.radius^2
    return math.sqrt(2 * g * planetaryBody.radius)
end

-- Both arguements must have x, y and radius
---@param staticBody table
---@param satelliteBody table
---@return number
---@return number
---@return number
---@return number
function CalculateTwoBodyThrust(staticBody, satelliteBody)
    local bodyFx, bodyFy =  CalculateTwoBodyVector(staticBody, satelliteBody)
    local myFx, myFy =  CalculateTwoBodyVector(satelliteBody, staticBody)
    
    staticBody.thrust.x = staticBody.thrust.x + myFx
    staticBody.thrust.y = staticBody.thrust.y + myFy

    staticBody.x = staticBody.x + staticBody.thrust.x * DT
    staticBody.y = staticBody.y + staticBody.thrust.y * DT
    
    satelliteBody.thrust.x = satelliteBody.thrust.x + bodyFx
    satelliteBody.thrust.y = satelliteBody.thrust.y + bodyFy

    return staticBody.thrust.x, staticBody.thrust.y, satelliteBody.thrust.x, satelliteBody.thrust.y
end

---@param min number
---@param max number
---@param accuracy number
---@return number
function CalculateInterpolation (min, max, accuracy)
   return min + (max - min) * accuracy
end


