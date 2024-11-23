
love = require 'love'
require 'calculate'

DEBUGGING = true

local Text = require 'ui'.text
-- local StatesMachine = require 'statesMachine'

WorldDirection = {x=0, y=0}

GRAVITATIONAL_CONSTANT = 67


local function StateMachine(statesTbl)
    local self = {
        setState = function (self, state)
            self.state = state
            for _, s in ipairs(statesTbl) do
                self[s] = self.state == s
            end
        
        end
    }
    
    self.state = nil

    for _, state in ipairs(statesTbl) do
        self[state] = self.state == state
    end

    return self
end


---@param loggerFilePath? string
---@param scrollThresh? integer
---@return table
function Logger(loggerFilePath, scrollThresh)
    local loggerOutput = Text(0, 0, 'p', {1, 1, 1})
    local loggerPath = loggerFilePath or 'C:\\Users\\User\\Documents\\Code\\lua\\SpaceInvader\\debug\\logger'
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
                end
                
                if count >= scollThreshold then
                    local firstNewlineIndex
                    for i = 1, #self.text do
                        if string.sub(self.text, i, i) == '\n' then
                            firstNewlineIndex = i + 1
                            break
                        end
                    end
                    -- local firstNewlineIndex = string.find(self.text, '\n')
                    if firstNewlineIndex ~= nil then
                        self.text = string.sub(self.text, firstNewlineIndex)
                    end
                end

                loggerOutput:setText(self.text)
                if count >= scollThreshold then
                    -- loggerOutput:scroll(0, -1)
                end 
            end
        end,
        
        write = function ()
            loggerOutput:write()
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
        end,

        DEBUG = function (self)
            -- self.text = string.sub(self.text, 2)
            -- self:log(#self.text)
            -- self:log(string.find(self.text, '\n'))
            -- local count = 0
            -- for i = 1, #self.text do
            --     if string.sub(self.text, i, i) == '\n' then
            --         count = count + 1
            --     end
            -- end
            -- if count >= 15 then
            --     self:log('string.sub(self.text, 1, 1)')
            --     return
            -- end
            -- self:log(1)
        end
    }
end

PLAYER_DOCKING_DISTANCE = 100

ASTROID_MIN_ALLOWED = 1
ASTROID_MIN_RAD = 10
ASTROID_MAX_RAD = 90
ASTROID_MIN_SIDES = 5
ASTROID_MAX_SIDES = 10
ASTROID_MAX_VEL = 100
ASTROID_DEFAULT_AMT = 3

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

STATESMACHINE = StateMachine(STATES)
