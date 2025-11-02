local calculate = {}

calculate = {
    GRAVITATIONAL_CONSTANT = 67,

    clamp = function (x, min, max)
        return math.max(math.min(x, max), min)
    end,

    ---@overload fun(dx: number, dy: number): number
    ---@param x1 number
    ---@param y1 number
    ---@param x2 number
    ---@param y2 number
    ---@return number
    distance = function (x1, y1, x2, y2)
        local dX
        local dY
        if x1 ~= nil and x2 ~= nil then
            dX = x2 - x1
            dY = y2 - y1
        else
            dX = x1
            dY = y1
        end

        return math.sqrt(dX^2 + dY^2)
    end,

    ---@overload fun(dx: number, dy: number): number
    ---@param x1 number
    ---@param y1 number
    ---@param x2 number
    ---@param y2 number
    ---@return number
    angle = function (x1, y1, x2, y2)
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
    end,

    ---@param a1 number
    ---@param a2 number
    ---@return number
    angleBetween = function (a1, a2)
        local diff = a2 - a1
        if diff > 180 then
            diff = diff - 360
        elseif diff < -180 then
            diff = diff + 360
        end

        return diff
    end,
    
    ---@param x1 number
    ---@param y1 number
    ---@param x2 number
    ---@param y2 number
    ---@param pointX number
    ---@param pointY number
    ---@return number
    angleBetweenAPoint = function (x1, y1, x2, y2, pointX, pointY)
        local angle1 = calculate.angle(x1, y1, pointX, pointY)
        local angle2 = calculate.angle(x2, y2, pointX, pointY)
        
        return calculate.angleBetween(angle1, angle2) 
    end,

    angleLerp = function (from, to, by)
        return (from + calculate.angleBetween(from, to) * by) % 360
    end,
    
    lerp = function (from, to, by)
        return from + (to - from) * by
    end,
    
    lineIntersection = function (x, y, radius, lx1, ly1, lx2, ly2)
        x = x - radius
        y = y - radius
        
        radius = radius * 2

        local left = math.min(lx1, lx2)
        local top = math.min(ly1, ly2)
        local width = math.abs(lx2 - lx1)
        local height = math.abs(ly2 - ly1)
        
        local lXComparison = (left < x and x < left + width) or (left < x + radius and x + radius < left + width)
        local lYComparison = (top < y and y < top + height) or (top < y + radius and y + radius < top + height)
        
        local bodyXComparison = (x < left  and left < x + radius) or (x < left + width and left + width < x + radius)
        local bodyYComparison = (y < top and top < y + radius) or (y < top + height and top + height < y + radius)

        if (lXComparison or bodyXComparison) and (lYComparison or bodyYComparison) then
            return true
        end
        return false
    end,

    gravity = function (mass, radius)
        return calculate.GRAVITATIONAL_CONSTANT * mass / radius^2
    end,
    
    ---@overload fun(x: number, y: number)
    ---@overload fun(angle: number)
    ---@param x1 number
    ---@param y1 number
    ---@param x2 number
    ---@param y2 number
    ---@return number
    ---@return number
    direction = function (x1, y1, x2, y2)
        local angle

        if x2 then
            angle = calculate.angle(x2 - x1, y2 - y1)
        elseif y1 then
            angle = calculate.angle(x1, x2)
        else
            angle = x1
        end

        return math.cos(math.rad(angle + 90)), -math.sin(math.rad(angle + 90))
    end,

    -- Both arguements must have x, y and radius
    ---@param staticBody table
    ---@param satelliteBody table
    ---@return number
    ---@return number
    twoBodyVector = function (staticBody, satelliteBody)
        local dx = staticBody.x - satelliteBody.x
        local dy = satelliteBody.y - staticBody.y
        local satelliteBodyMass = satelliteBody.mass or satelliteBody.radius
        local staticBodyMass = staticBody.mass or staticBody.radius

        local distanceBetween = math.sqrt(dx^2 + dy^2)
        local udx = dx / distanceBetween
        local udy = dy / distanceBetween

        ---@diagnostic disable-next-line: deprecated
        local theta = math.atan2(udy, udx)
        local force = calculate.GRAVITATIONAL_CONSTANT * satelliteBodyMass * staticBodyMass / distanceBetween^2

        local  Fx = force * math.cos(theta)
        local  Fy = -force * math.sin(theta)
        
        return Fx / satelliteBodyMass, Fy / satelliteBodyMass
    end,

    -- Both arguements must have x, y and radius
    ---@param staticBody table
    ---@param satelliteBody table
    ---@return table
    ---@return table
    twoBodyThrust = function (staticBody, satelliteBody)
        local satelliteBodyFx, satelliteBodyFy =  calculate.twoBodyVector(staticBody, satelliteBody)
        
        satelliteBody.thrust.x = satelliteBody.thrust.x + satelliteBodyFx
        satelliteBody.thrust.y = satelliteBody.thrust.y + satelliteBodyFy

        local staticBodyFx, staticBodyFy =  calculate.twoBodyVector(satelliteBody, staticBody)
        
        staticBody.thrust.x = staticBody.thrust.x + staticBodyFx
        staticBody.thrust.y = staticBody.thrust.y + staticBodyFy

        -- staticBody.x = staticBody.x + staticBody.thrust.x * DT
        -- staticBody.y = staticBody.y + staticBody.thrust.y * DT

        return staticBody.thrust, satelliteBody.thrust
    end,

    ---@param min number
    ---@param max number
    ---@param accuracy number
    ---@return number
    interpolation = function (min, max, accuracy)
    return min + (max - min) * accuracy
    end

}

return calculate
