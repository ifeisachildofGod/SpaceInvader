
love = require 'love'

DEBUGGING = true

local Text = require 'text'
local StatesMachine = require 'statesMachine'

worldDirection = {x=0, y=0}

LoggerOutput = Text(0, 0, 'p', {1, 1, 1})
local GRAVITATIONAL_CONSTANT = 6

function WrapAroundScreen(x, y, width, height)
    local pos = {
        x = x,
        y = y
    }

    if pos.x + width < 0 then
        pos.x = love.graphics.getWidth() + width
    elseif pos.x - width > love.graphics.getWidth() then
        pos.x = -width
    end

    if pos.y + height < 0 then
        pos.y = love.graphics.getHeight() + height
    elseif pos.y - height > love.graphics.getHeight() then
        pos.y = -height
    end

    return pos
end

function Sign(x)
    if x == 0 then
        return 0
    end
    return x / math.abs(x)
end

function Clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function CalculateDistance(x1, y1, x2, y2)
    local dX = x2 - x1
    local dY = y2 - y1

    return math.sqrt(dX^2 + dY^2)
end

function CalculateAngle(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y1 - y2
    
    ---@diagnostic disable-next-line: deprecated
    return math.deg(math.atan2(dy, dx)) - 90
end

function CalculateAngleLerp(from, to, by)
    local diff = to - from
    if diff > 180 then
        diff = diff - 360
    elseif diff < -180 then
        diff = diff + 360
    end
    local result = from + diff * by

    return result % 360

end

-- Both arguements must have x, y and radius
---@param staticBody table
---@param satelliteBody table
---@return number
---@return number
CalculateTwoBodyVextor = function (staticBody, satelliteBody)
    local dx = staticBody.x - satelliteBody.x
    local dy = satelliteBody.y - staticBody.y
    
    local distanceBetween = math.sqrt(dx^2 + dy^2)
    local udx = dx / distanceBetween
    local udy = dy / distanceBetween

    ---@diagnostic disable-next-line: deprecated
    local theta = math.atan2(udy, udx)
    local force = GRAVITATIONAL_CONSTANT * satelliteBody.radius * staticBody.radius / distanceBetween^2

    local  Fx = force * math.cos(theta)
    local  Fy = -force * math.sin(theta)
    
    return Fx / satelliteBody.radius, Fy / satelliteBody.radius
end


---@param loggerFilePath? string
---@param scrollThresh? integer
---@return table
function Logger(loggerFilePath, scrollThresh)
    local loggerPath = loggerFilePath or 'logger.log'
    local scollThreshold = scrollThresh or 15

    return {
        text = '',
        sep = ' ',
        ending = '\n',
        loggingFile = io.open(loggerPath, "a"),
        loggerFilePath = loggerPath,

        log = function (self, ...)
            if DEBUGGING then
                local args = {...}
                local printedText = ''
                
                for _, msg in pairs(args) do
                    printedText = printedText..tostring(msg)..((#args > 1) and self.sep or '')
                end
                printedText = printedText..self.ending
                
                if self.loggingFile ~= nil then
                    self.loggingFile:write(printedText)
                end
                
                local count = 0
                self.text = self.text..printedText
                for i = 1, #self.text do
                    if string.sub(self.text, i, i) == '\n' then
                        count = count + 1
                    end

                    if count >= scollThreshold then
                        local firstNewlineIndex = string.find(self.text, '\n')
                        if firstNewlineIndex ~= nil then
                            self.text = string.sub(self.text, firstNewlineIndex)
                        end
                        
                        break
                    end
                end
                
                LoggerOutput:setText(self.text)
                if count >= scollThreshold then
                    LoggerOutput:scroll(0, -1)
                end 
            end
        end,

        setSeperator = function (self, sep)
            self.sep = sep
        end,

        setEnd = function (self, ending)
            self.ending = ending
        end,
        
        setLogPath = function (self, path)
            if DEBUGGING then 
                self:closeFile()
                self.loggerFilePath = path
                self.loggingFile = io.open(self.loggerFilePath, "a") 
            end
        end,

        closeFile = function (self)
            if DEBUGGING then 
                self.loggingFile:close()
            end
        end,

        clearFile = function (self)
            if DEBUGGING then 
                self:closeFile()
                self.loggingFile = io.open(self.loggerFilePath, "w")
                self.loggingFile:write('')
                self:closeFile()
                self.loggingFile = io.open(self.loggerFilePath, "a")
            end
        end
    }
end

PLAYER_DOCKING_DISTANCE = 100

ASTROID_MIN_ALLOWED = 1
ASTROID_MIN_RAD = 50
ASTROID_MAX_RAD = 100
ASTROID_MIN_SIDES = 6
ASTROID_MAX_SIDES = 10
ASTROID_MAX_VEL = 5
ASTROID_DEFAULT_AMT = 4

STATES = {
    'pause',
    'normal',
    'restart'
}

local baseFontSize = 60

Fonts = {
    h1 = love.graphics.newFont(baseFontSize),
    h2 = love.graphics.newFont(baseFontSize - 10),
    h3 = love.graphics.newFont(baseFontSize - 20),
    h4 = love.graphics.newFont(baseFontSize - 30),
    h5 = love.graphics.newFont(baseFontSize - 40),
    h6 = love.graphics.newFont(baseFontSize - 50),
    p = love.graphics.newFont(baseFontSize - 44),
}

STATESMACHINE = StatesMachine(STATES)
