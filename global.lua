love = require 'love'
local ui = require 'ui'

DEBUGGING = true
WorldDirection = {x=0, y=0}

local stateMachineStates = {
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



function ListIndex(list, value)
    for i, v in ipairs(list) do
        if value == v then
            return i
        end
    end
    return -1
end

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
function LoggerFunc(loggerFilePath, scrollThresh)
    local loggerOutput = ui.text(0, 0, 'p', {1, 1, 1})
    local loggerPath = loggerFilePath or 'C:\\Users\\User\\Documents\\Code\\lua\\SpaceInvader\\debug\\logger'
    local scollThreshold = scrollThresh or 15

    local logger = {}

    logger = {
        text = '',
        sep = ' ',
        ending = '\n',
        loggingFile = io.open(loggerPath, "a"),
        loggerFilePath = loggerPath,

        log = function (...)
            if DEBUGGING then
                local args = {...}
                local printedText = ''
                
                for _, msg in pairs(args) do
                    printedText = printedText..tostring(msg)..((#args > 1) and logger.sep or '')
                end
                printedText = printedText..logger.ending
                
                if logger.loggingFile ~= nil then
                    logger.loggingFile:write(printedText)
                end
                
                local count = 0
                logger.text = logger.text..printedText
                for i = 1, #logger.text do
                    if string.sub(logger.text, i, i) == '\n' then
                        count = count + 1
                    end    
                end
                
                if count >= scollThreshold then
                    local firstNewlineIndex
                    for i = 1, #logger.text do
                        if string.sub(logger.text, i, i) == '\n' then
                            firstNewlineIndex = i + 1
                            break
                        end
                    end
                    -- local firstNewlineIndex = string.find(logger.text, '\n')
                    if firstNewlineIndex ~= nil then
                        logger.text = string.sub(logger.text, firstNewlineIndex)
                    end
                end

                loggerOutput:setText(logger.text)
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
        end
    }

    return logger
end

logger = LoggerFunc()

logger:setLogPath(logger.loggerFilePath)
logger:clearFile()

logger:log('[Running] Love "'..debug.getinfo(1).source..'"')

STATESMACHINE = StateMachine(stateMachineStates)