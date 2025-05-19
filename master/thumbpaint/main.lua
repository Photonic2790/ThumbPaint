-- ThumbPaint: By Photonic2790@github.com
--[[Description:
Day one of writing a cross-platform high level image editor in love2d
Designed for use on handheld consoles with MUOS
May 18th, 2024
]]

local TITLE = "ThumbPaint"
local width, height = love.window.getMode()
love.window.setMode(width, height, {fullscreen=true, resizable=true, vsync=0, minwidth=320, minheight=240})
width, height = love.window.getMode()
width = 640 -- debugging on desktop, forcing window size here
height = 480
local WINDOWWIDTH  = width
local WINDOWHEIGHT = height
local BGCOLOR = { .2,  .2,  .2 }

--[[ todo: trim these rgb vars down ]]
-- rgb strings RRGGBB hex
local redSTR = ""
local greenSTR = ""
local blueSTR = ""

-- r,g,b 0 to 1
local r = 0.01 
local g = 0.01 
local b = 0.01
local tempR = 0.01 
local tempG = 0.01 
local tempB = 0.01

-- red,green,blue 0 to 255 
local red   = 0
local green = 0
local blue  = 0
local tempRed   = 0
local tempGreen = 0
local tempBlue  = 0

-- fixed canvas size, change it here
local cx = 32 -- canvas x size
local cy = 48 -- canvas y size

-- mouse
local zoom = 8 -- adjusted with mouse wheel
local mx = 0
local my = 0
local mdelay = 0

-- starts centered 
local xoff = width/2-(cx*zoom)/2
local yoff = height/2-(cy*zoom)/2


-- one tool per execution until toolbar gets written, set the tool here
local TOOL = 3 -- 0 = pencil, 1 = move, 2 = rectangle select, 3 = color picker 

-- these are used by the program
local lastx = 0
local lasty = 0
local LIFTED = 0 -- 0 = empty, 1 = canvas, 2 = selection
local SELECTED = { 0, 0, 0, 0 } -- x1, y1, x2, y2
local SELMODE = 0 -- a selection helper, 0 = empty 1 = between points, 2 = full 

--[[
todo list, 
color - rgb sliders, plus color picker 

priority 1
flexable toolbar, new file(change canvas size), open file,

priority 2
save as, draw {lines, circles, rects, with and without fills}

priority 3
copy/paste(buffer should persist between files), move selection, undo
]]

function love.load()
    love.window.setTitle(TITLE)
    love.window.setMode(WINDOWWIDTH, WINDOWHEIGHT, {resizable=true, vsync=0, minwidth=320, minheight=240})
    canvas = love.graphics.newCanvas(cx, cy)
    cursor = love.graphics.newImage("gfx/cursor.png")
    love.mouse.setVisible(false)
    testPNG = love.graphics.newImage("test.png")

    dot = love.graphics.newImage("gfx/dot.png")
    line = love.graphics.newImage("gfx/line.png")

    love.graphics.setCanvas(canvas)
    love.graphics.draw(testPNG)
    love.graphics.setCanvas()
end

function love.draw()

    redSTR = string.format("%02x", red)
    greenSTR = string.format("%02x", green)
    blueSTR = string.format("%02x", blue)

	drawGrid(.5,.5,.5,1)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(canvas,xoff,yoff,0,zoom,zoom)
    drawGrid(.2,.2,.2,.3)

    mx, my = love.mouse.getPosition()
    mdelay = mdelay + 1


    if TOOL == 3 then -- colour picker
        drawColorSlider()
        if (mdelay >= 1 and love.mouse.isDown(1) or love.mouse.isDown(2) or love.mouse.isDown(3)) then
            if (mx < 516 and my < 29) then -- red slider
                mdelay = 0
                red = math.floor(mx/2)
                if red > 255 then red = 255 end
                r = red/255
            elseif (mx < 516 and my < 51) then -- green slider
                mdelay = 0
                green = math.floor(mx/2)
                if green > 255 then green = 255 end
                g = green/255
            elseif (mx < 516 and my < 73) then -- blue slider
                mdelay = 0
                blue = math.floor(mx/2)
                if blue > 255 then blue = 255 end
                b = blue/255
            end
        end
    end

    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(cursor, love.mouse.getX(), love.mouse.getY())

    -- MOVE
    if LIFTED == 1 then -- CANVAS
        xoff = love.mouse.getX() - lastx
        yoff = love.mouse.getY() - lasty
    end

    -- SELECT
    if SELMODE == 1 then
        love.graphics.setColor(1,1,1,1)
        love.graphics.rectangle("line",(SELECTED[0]*zoom)+xoff,(SELECTED[1]*zoom)+yoff,love.mouse.getX()-((SELECTED[0]*zoom)+xoff),love.mouse.getY()-((SELECTED[1]*zoom)+yoff))

    elseif SELMODE == 2 then
        love.graphics.setColor(1,1,1,1)
        love.graphics.rectangle("line",(SELECTED[0]*zoom)+xoff,(SELECTED[1]*zoom)+yoff,((SELECTED[2]*zoom)+xoff)-((SELECTED[0]*zoom)+xoff),((SELECTED[3]*zoom)+yoff)-((SELECTED[1]*zoom)+yoff))
    end

end


function drawGrid(r,g,b,a)
    love.graphics.setColor(r,g,b,a)
    for x = 0, cx*zoom, zoom do --vert
        love.graphics.line(xoff+x, yoff+0, xoff+x, yoff+cy*zoom)
    end
    for y = 0, cy*zoom, zoom do --horz
        love.graphics.line(xoff+0, yoff+y, xoff+cx*zoom, yoff+y)
    end
end

function drawColorSlider()    
    x=0
    while x < 255 do -- the slider bars
        love.graphics.setColor(.7,.7,.7,1)
        love.graphics.draw(dot, x*2-2, 2)    -- white backdrop  
        love.graphics.draw(dot, x*2-2, 20)   -- white backdrop      
        love.graphics.draw(dot, x*2-2, 40)   -- white backdrop      
        love.graphics.draw(dot, x*2-2, 58)   -- white backdrop      
        love.graphics.setColor(x/255,0,0,1)
        love.graphics.draw(dot, x*2-4, 10)   -- red
        love.graphics.setColor(0,x/255,0,1)
        love.graphics.draw(dot, x*2-4, 30)   -- green
        love.graphics.setColor(0,0,x/255,1)
        love.graphics.draw(dot, x*2-4, 50)   -- blue
        x = x + 2
    end
    
    -- the slider line
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(line, red * 2,   10)
    love.graphics.draw(line, green * 2, 30)
    love.graphics.draw(line, blue * 2,  50)


    x=530
    love.graphics.setColor(r,0,0,1)
    love.graphics.draw(dot, x, 10)  
    love.graphics.setColor(0,g,0,1)
    love.graphics.draw(dot, x, 30)  
    love.graphics.setColor(0,0,b,1)
    love.graphics.draw(dot, x, 50)
        
    -- behind buffer color  
    y=10
    x=560
    z=-1
    while y < 52 do
        while x < 604 do
            love.graphics.setColor(.5+z*.4,.5+z*.4,.5+z*.4,1)
            love.graphics.draw(dot, x, y)
            x = x + 4
            z = z * -1
        end
        x = 560
        y = y + 4
    end

    love.graphics.setColor(r,g,b,1) 
    y=20
    x=570
    while y < 44 do
        while x < 594 do
            love.graphics.draw(dot, x, y)
            x = x + 4
        end
        x = 570
        y = y + 4
    end
    love.graphics.print("HEXCODE : "..redSTR..greenSTR..blueSTR, 540, 80)    
end

function love.keypressed(k)

    if k == "return" then
        love.graphics.setCanvas()    
        local imagedata = canvas:newImageData()
        imagedata:encode("png", "test.png")
    end

    if k == "space" then
        TOOL = TOOL + 1
        if TOOL > 3 then TOOL = 0 end
    end

    if TOOL == 0 then -- pencil
        if k == "a" then
            love.graphics.setColor(r,g,b,1)
            love.graphics.setCanvas(canvas)
            love.graphics.points((love.mouse.getX()-xoff)/zoom, (love.mouse.getY()-yoff)/zoom)
            love.graphics.setCanvas()
    
        elseif k == "b" then
            love.graphics.setCanvas(canvas)
            love.graphics.setScissor((love.mouse.getX()-xoff)/zoom, (love.mouse.getY()-yoff)/zoom,1,1)
            love.graphics.clear()
            love.graphics.setCanvas()
            love.graphics.setScissor()
    
        elseif k == "up" then
            yoff = yoff - 8
        elseif k == "down" then
            yoff = yoff + 8
        elseif k == "left" then
            xoff = xoff - 8
        elseif k == "right" then
            xoff = xoff + 8
        end

    elseif TOOL == 1 then -- move
        if k == "a" then
            if LIFTED == 0 then
                lastx = love.mouse.getX() - xoff
                lasty = love.mouse.getY() - yoff
                LIFTED = 1 -- CANVAS
            else
                LIFTED = 0 -- EMPTY, DOWN
                lastx = 0
                lasty = 0
            end
        end

    elseif TOOL == 2 then -- select
        if k == "escape" then
            SELMODE = 0
            SELECTED[0] = 0
            SELECTED[1] = 0
            SELECTED[2] = 0
            SELECTED[3] = 0
        end
        
        if SELMODE == 0 then
            if k == "a" then
                SELECTED[0] = (love.mouse.getX()-xoff)/zoom
                SELECTED[1] = (love.mouse.getY()-yoff)/zoom
                SELMODE = 1 -- onto next point
            end
        elseif SELMODE == 1 then
            if k == "a" then
                SELECTED[2] = (love.mouse.getX()-xoff)/zoom
                SELECTED[3] = (love.mouse.getY()-yoff)/zoom
                SELMODE = 2 -- selected rectangle full
            end
        elseif SELMODE == 2 then
            if k == "b" then -- erase
                love.graphics.setColor(0,0,0,0)
                love.graphics.setCanvas(canvas)
                if SELECTED[0] < SELECTED[2] then
                    if SELECTED[1] < SELECTED[3] then
                        love.graphics.setScissor(SELECTED[0], SELECTED[1],SELECTED[2]-SELECTED[0],SELECTED[3]-SELECTED[1])
                    else 
                        love.graphics.setScissor(SELECTED[0], SELECTED[3],SELECTED[2]-SELECTED[0],SELECTED[1]-SELECTED[3])
                    end
                else
                    if SELECTED[1] < SELECTED[3] then
                        love.graphics.setScissor(SELECTED[2], SELECTED[1],SELECTED[0]-SELECTED[2],SELECTED[3]-SELECTED[1])
                    else 
                        love.graphics.setScissor(SELECTED[2], SELECTED[3],SELECTED[0]-SELECTED[2],SELECTED[1]-SELECTED[3])
                    end
                end

                love.graphics.clear()
                love.graphics.setCanvas()
                love.graphics.setScissor()
                SELMODE = 0 -- empty
            end
        end
    end
end


function love.wheelmoved(x, y) 
    if y > 0 then
        zoom = zoom + 1
        if zoom > 256 then zoom = 256 end
    end
    if y < 0 then
        zoom = zoom - 1
        if zoom < .5 then zoom = .5 end
    end
end