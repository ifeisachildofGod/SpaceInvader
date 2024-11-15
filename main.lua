
math.randomseed(os.time())

local World = require 'world'
local world = World()

LOGGER = Logger()
DT = 0

function love.load()
    love.graphics.setFont(Fonts['p'])
    LOGGER:clearFile()
    LOGGER:log('[Running] Love "'..debug.getinfo(1).source..'"')
end

function love.draw()
    world:draw(love.timer.getDelta())
    if DEBUGGING then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(tostring(love.timer.getFPS()), love.graphics.getWidth() - 30, 10, love.graphics.getWidth(), 'left')
    end
end

function love.keypressed(key)
    world:keyPressed(key)
end

function love.mousepressed(_, _, mouseCode)
    world:mousePressed(mouseCode)
end

function love.update(dt)
    DT = dt
    if STATESMACHINE.restart then
        world = World()
        STATESMACHINE:setState('normal')
    else
        world:update()
    end
end

function love.quit()
    LOGGER:closeFile()
end
