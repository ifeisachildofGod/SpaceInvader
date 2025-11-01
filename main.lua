require 'global'

math.randomseed(os.time())

local World = require 'world'

local world = World()

DT = 0

local miniMapWidth = 200
local calculate = require 'calculate'
local miniMap = love.graphics.newCanvas(miniMapWidth, miniMapWidth * SCREEN_HEIGHT / SCREEN_WIDTH)

local screenScalingX = miniMap:getWidth() / SCREEN_WIDTH
local screenScalingY = miniMap:getHeight() / SCREEN_HEIGHT

local screenScalingOffset = 0.15

love.window.setMode(SCREEN_WIDTH, SCREEN_HEIGHT)
love.window.setTitle('Space Explorer')

function love.load()
    love.graphics.setFont(Fonts['p'])
end

local angle = 0

function love.draw()
    love.graphics.setCanvas(miniMap)
    love.graphics.clear()
    love.graphics.push()
    love.graphics.scale(screenScalingX * screenScalingOffset, screenScalingY * screenScalingOffset)
    local translatedX, translatedY = -SCREEN_WIDTH * (screenScalingOffset - 1) / (2 * screenScalingOffset), -SCREEN_HEIGHT * (screenScalingOffset - 1) / (2 * screenScalingOffset)
    love.graphics.translate(translatedX, translatedY)
    world:draw()
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', -translatedX, -translatedY, SCREEN_WIDTH / screenScalingOffset, SCREEN_HEIGHT / screenScalingOffset)
    
    love.graphics.pop()

    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1)
    
    local targetAngle = 0

    if world.player.modes.character then
        local player = world.player.character.player

        targetAngle = calculate.angle(player.planet.x, player.planet.y, player.x, player.y)
        angle = calculate.angleLerp(angle, targetAngle, 0.08)
        love.graphics.translate(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2)
        love.graphics.rotate(math.rad(angle))
        love.graphics.translate(-SCREEN_WIDTH / 2, -SCREEN_HEIGHT / 2)
    else
        angle = calculate.angleLerp(angle, 0, 0.08)
        love.graphics.translate(SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2)
        love.graphics.rotate(math.rad(angle))
        love.graphics.translate(-SCREEN_WIDTH / 2, -SCREEN_HEIGHT / 2)
    end
    world:draw()
    
    if world.player.modes.character then
        local player = world.player.character.player

        -- love.graphics.translate(math.cos(math.rad(angle)) * player.planet.radius, -math.sin(math.rad(angle)) * player.planet.radius)
        love.graphics.rotate(math.rad(-angle))
    end

    love.graphics.rectangle('line', 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('fill', 0, 0, miniMap:getWidth(), miniMap:getHeight())
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(miniMap, 0, 0)
    
    if DEBUGGING then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(tostring(love.timer.getFPS()), SCREEN_WIDTH - 30, 10, SCREEN_WIDTH, 'left')
    end
    
    logger.write()
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
