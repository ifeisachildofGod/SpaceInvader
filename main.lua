require 'global'

math.randomseed(os.time())

local World = require 'world'
local modes = require 'modes'
local celestials = require 'collisionBodies.celestials'

local function Init()
    local worldCollisionBodies = {}
    local worldPlanets = {celestials.planet(love.graphics.getWidth() / 2, (love.graphics.getHeight() / 2) + 110, {r=100/255, g=120/255, b=21/255}, 100, worldCollisionBodies)}--, celestials.planet(820, 820, {r=0/255, g=255/255, b=201/255}, 40, collisionBodies, 0.5)}
    
    for _, planet in ipairs(worldPlanets) do
        table.insert(worldCollisionBodies, planet)
    end
    
    local world = World(worldPlanets, worldCollisionBodies, modes.player)
    
    return world
end

local world = Init()

DT = 0

function love.load()
    love.graphics.setFont(Fonts['p'])
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
        world = Init()
        STATESMACHINE:setState('normal')
    else
        world:update()
    end
end

function love.quit()
    logger:closeFile()
end
