require 'global'

math.randomseed(os.time())

local World = require 'world'

local world = World()

DT = 0

local screenWidth = 800
local screenHeight = 600

local miniMapWidth = 200

local miniMap = love.graphics.newCanvas(miniMapWidth, miniMapWidth * screenHeight / screenWidth)

local screenScalingX = miniMap:getWidth() / screenWidth
local screenScalingY = miniMap:getHeight() / screenHeight

local screenScalingOffset = 0.2

love.window.setMode(screenWidth, screenHeight)
love.window.setTitle('Space Explorer')

function love.load()
    love.graphics.setFont(Fonts['p'])
end


function love.draw()
    -- love.graphics.setCanvas(miniMap)
    -- love.graphics.clear()
    -- love.graphics.push()
    -- love.graphics.scale(screenScalingX * screenScalingOffset, screenScalingY * screenScalingOffset)
    -- local translatedX, translatedY = -love.graphics.getWidth() * (screenScalingOffset - 1) / (2 * screenScalingOffset), -love.graphics.getHeight() * (screenScalingOffset - 1) / (2 * screenScalingOffset)
    -- love.graphics.translate(translatedX, translatedY)
    -- world:draw()
    -- love.graphics.setLineWidth(2)
    -- love.graphics.rectangle('line', -translatedX, -translatedY, love.graphics.getWidth() / screenScalingOffset, love.graphics.getHeight() / screenScalingOffset)
    
    -- love.graphics.pop()

    -- love.graphics.setCanvas()
    world:draw()
    -- love.graphics.setColor(0, 0, 0)
    -- love.graphics.rectangle('fill', 0, 0, miniMap:getWidth(), miniMap:getHeight())
    -- love.graphics.setColor(1, 1, 1)
    -- love.graphics.draw(miniMap, 0, 0)

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
    logger:closeFile()
end
