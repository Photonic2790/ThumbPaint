-- ThumbPaint: By Photonic2790@github.com
--[[Description:
A cross-platform high level image editor in love2d
Designed for use on handheld consoles
May 19th, 2024
]]

--[[Controls:
Mouse, emulated with "L-stick", "L1" = mouse button 1 (Left click), "R1" = mouse button 2 (right click)
    -- usb mouse also works

            handheld  --  key/mouse
ANYTOOL     "start"   or  "RETURN"      - save as ".local/share/love/thumbpaint/test.png"
            "select"  or  "SPACE"       - change tool
            "L2"      or  "wheel down"  - (zoom out) 
            "R2"      or  "wheel up"    - (zoom in)
            "D-PAD"   or  "arrows"      - move canvas
            "R-Stick"                   - move canvas

0
PENCIL      "L1"      or  "Left-click"  - draw pixel
            "R1"      or  "Right-click" - color grab
            "X"       or  "X"           - erase pixel

1
MOVE        "L1"      or  "Left-click"  - hold to drag canvas

2
SELECT      "L1"      or  "Left-click"  - hold to set selection box
            "X"       or  "X"           - erase selection
            "B"       or  "B"           - clears selection

3
COLOR       "L1"      or  "Left-click"  - use on sliders r,g,b,a to set color
            "R1"      or  "Right-click" - color grab

]]

--[[
TODO

priority 1
flexable toolbar, new file(change canvas size), open file,

priority 2
save as, draw {lines, circles, rects, with and without fills}

priority 3
copy/paste(buffer should persist between files), move selection, undo
]]

local TITLE = "ThumbPaint"
local width, height = love.window.getMode()
love.window.setMode(width, height, {fullscreen=true, resizable=true, vsync=0, minwidth=320, minheight=240})
width, height = love.window.getMode()
-- width = 640 -- debugging on desktop, forcing window size here
-- height = 480
local WINDOWWIDTH  = width
local WINDOWHEIGHT = height
local BGCOLOR = { .2,  .2,  .2 }

--[[ todo: trim these rgb vars down ]]
-- rgb strings RRGGBB hex

-- r,g,b,a 0 to 1
local r = 0.01 
local g = 0.01 
local b = 0.01
local a = 1.00

-- red,green,blue,alpha 0 to 255 
local red   = 0
local green = 0
local blue  = 0
local alpha = 255

-- fixed canvas size, change it here
local cx = 16 -- canvas x size
local cy = 16 -- canvas y size

-- mouse
local zoom = 16 -- adjusted with mouse wheel
local mx = 0
local my = 0

-- starts centered 
local xoff = width/2-(cx*zoom)/2
local yoff = height/2-(cy*zoom)/2


-- press "space" or "back" or "SE" or "select" to change the current tool at the moment
local TOOL = 3 -- 0 = pencil, 1 = move, 2 = rectangle select, 3 = color picker 

-- these are used by the program
local lastx = 0
local lasty = 0
local LIFTED = 0 -- 0 = empty, 1 = canvas, 2 = selection
local SELECTED = { 0, 0, 0, 0 } -- x1, y1, x2, y2
local SELMODE = 0 -- a selection helper, 0 = empty 1 = between points, 2 = full 


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

	drawGrid(.5,.5,.5,1)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(canvas,xoff,yoff,0,zoom,zoom)
    drawGrid(.2,.2,.2,.3)

    checkTools()

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

function fetchPixel(x,y)
    love.graphics.setCanvas()    
    local imagedata = canvas:newImageData()
    local w = imagedata:getWidth()
    local h = imagedata:getHeight()
    if x < 0 or x > w or y < 0 or y > h then return end
    r, g, b, a = imagedata:getPixel(x,y)
    red = r * 255
    green = g * 255
    blue = b * 255
    alpha = a * 255
end

function erasePixel(x,y)
    love.graphics.setCanvas(canvas)
    love.graphics.setScissor(x,y,1,1)
    love.graphics.clear()
    love.graphics.setCanvas()
    love.graphics.setScissor()
end

function checkTools()

    mx, my = love.mouse.getPosition()

    if TOOL == 0 then-- pencil
        if love.mouse.isDown(1) then
            love.graphics.setColor(r,g,b,a)
            love.graphics.setCanvas(canvas)
            love.graphics.points((mx-xoff)/zoom, (my-yoff)/zoom)
            love.graphics.setCanvas()
        end
        if love.mouse.isDown(2) then
            fetchPixel((mx-xoff)/zoom, (my-yoff)/zoom)
        end
    elseif TOOL == 3 then -- colour picker
        drawColorSlider()
        if love.mouse.isDown(1) then
            if (mx < 516 and my < 29) then -- red slider
                red = math.floor(mx/2)
                if red > 255 then red = 255 end
                r = red/255
            elseif (mx < 516 and my < 51) then -- green slider
                green = math.floor(mx/2)
                if green > 255 then green = 255 end
                g = green/255
            elseif (mx < 516 and my < 73) then -- blue slider
                blue = math.floor(mx/2)
                if blue > 255 then blue = 255 end
                b = blue/255
            elseif (mx < 516 and my < 95) then -- alpha slider
                alpha = math.floor(mx/2)
                if alpha > 255 then alpha = 255 end
                a = alpha/255
            end
        end
        if love.mouse.isDown(2) then
            fetchPixel((mx-xoff)/zoom, (my-yoff)/zoom)
        end
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
        love.graphics.draw(dot, x*2-2, 60)   -- white backdrop
        love.graphics.draw(dot, x*2-2, 70)   -- behind alpha
        love.graphics.setColor(x/255,0,0,1)
        love.graphics.draw(dot, x*2-4, 10)   -- red
        love.graphics.setColor(0,x/255,0,1)
        love.graphics.draw(dot, x*2-4, 30)   -- green
        love.graphics.setColor(0,0,x/255,1)
        love.graphics.draw(dot, x*2-4, 50)   -- blue
        love.graphics.setColor(0,0,0,x/255)
        love.graphics.draw(dot, x*2-4, 70)   -- alpha
        x = x + 2
    end
    
    -- the slider line
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(line, red * 2,   10)
    love.graphics.draw(line, green * 2, 30)
    love.graphics.draw(line, blue * 2,  50)
    love.graphics.draw(line, alpha * 2,  70)


    x=530
    love.graphics.setColor(r,0,0,1)
    love.graphics.draw(dot, x, 10)  
    love.graphics.setColor(0,g,0,1)
    love.graphics.draw(dot, x, 30)  
    love.graphics.setColor(0,0,b,1)
    love.graphics.draw(dot, x, 50)
    love.graphics.setColor(1,1,1,a)
    love.graphics.draw(dot, x, 70)
        
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

    love.graphics.setColor(r,g,b,a) 
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

    love.graphics.setColor(1,1,1,1) 
    love.graphics.print("R:"..string.format("%02X", red).." G:"..string.format("%02X", green).." B:"..string.format("%02X", blue).." A:"..string.format("%02X", alpha), 530, 80)    
end

function love.keypressed(k)

    if k == "r" then
        zoom = zoom + 1
        if zoom > 256 then zoom = 256 end
    end
    if k == "l" then
        zoom = zoom - 1
        if zoom < .5 then zoom = .5 end
    end

    if k == "return" then
        love.graphics.setCanvas()    
        local imagedata = canvas:newImageData()
        imagedata:encode("png", "test.png")
    end

    if k == "space" then
        TOOL = TOOL + 1
        if TOOL > 3 then TOOL = 0 end
        SELMODE = 0 -- ghosting rectangle selection box fix
    end

    if TOOL == 0 then -- pencil
    
        if k == "x" then
            erasePixel((love.mouse.getX()-xoff)/zoom,(love.mouse.getY()-yoff)/zoom)
    
        elseif k == "up" then
            yoff = yoff - 8
        elseif k == "down" then
            yoff = yoff + 8
        elseif k == "left" then
            xoff = xoff - 8
        elseif k == "right" then
            xoff = xoff + 8
        end

    elseif TOOL == 2 then -- select
        if k == "b" then
            SELMODE = 0
            SELECTED[0] = 0
            SELECTED[1] = 0
            SELECTED[2] = 0
            SELECTED[3] = 0
        end
        
        if SELMODE == 2 then
            if k == "x" then -- erase
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


function love.mousepressed(x, y, button, it) -- look for isDown() also throughout checkTools()
    if button == 1 then
        if TOOL == 1 then -- move
            if LIFTED == 0 then
                lastx = x - xoff
                lasty = y - yoff
                LIFTED = 1 -- CANVAS
            else
                LIFTED = 0 -- EMPTY, DOWN
                lastx = 0
                lasty = 0
            end
        elseif TOOL == 2 then -- select
            SELECTED[0] = (x-xoff)/zoom
            SELECTED[1] = (y-yoff)/zoom
            SELMODE = 1 -- onto next point
        end
    end
end

function love.mousereleased(x, y, button, it) 
    if button == 1 then
        if TOOL == 1 then -- move
            LIFTED = 0 -- EMPTY, DOWN
            lastx = 0
            lasty = 0
        elseif TOOL == 2 then -- select
            SELECTED[2] = (x-xoff)/zoom
            SELECTED[3] = (y-yoff)/zoom
            SELMODE = 2 -- selected rectangle full
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