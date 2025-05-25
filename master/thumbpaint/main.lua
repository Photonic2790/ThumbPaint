-- ThumbPaint: By Photonic2790@github.com
--[[Description:
A cross-platform high level image editor in love2d
Designed for use on handheld consoles
May 25th, 2025
]]

--[[Controls:
Mouse, emulated with "L-stick", "R1" = mouse button 1 (Left click), "R2" = mouse button 2 (right click)
    -- usb mouse also works

            handheld  --  key/mouse
ANYTOOL     "start"   or  "RETURN"      - save as ".local/share/love/thumbpaint/temp.png"
            "select"  or  "SPACE"       - change tool
            "L1"      or  "wheel up"    - zoom in
            "L2"      or  "wheel down"  - zoom out 
            "L3"      or  "mid mouse"   - click to drag/drop canvas
            "D-PAD"   or  "arrows"      - move canvas (deprecated)
            "R-Stick"                   - move canvas (deprecated)

0
PENCIL      "R1"      or  "Left-click"  - draw pixel
            "R2"      or  "Right-click" - color grab
            "X"       or  "X"           - erase pixel

1
MOVE        "R1"      or  "Left-click"  - hold to drag canvas (to become a layer/selection type move)

2
SELECT      "R1"      or  "Left-click"  - hold to set selection box
            "X"       or  "X"           - erase selection
            "B"       or  "B"           - cancels selection

3
COLOR       "R1"      or  "Left-click"  - use on sliders r,g,b,a to set color
            "R2"      or  "Right-click" - color grab

]]

--[[
TODO - draw toolbar tool buttons :) 32x32

MENUBAR - mouse operated, simple top down File Edit Image Settings...
Consider multifile editing and layers, now, early in dev
Text input, for drawing and file system

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
--      Dec R     G     B     A    Hex R, G, B, A
-- RGBA = { 0.01, 0.01, 0.01, 1.00,    0, 0, 0, 255 }
-- r,g,b,a 0 to 1
local r = 0.00 
local g = 0.00 
local b = 0.00
local a = 1.00

-- red,green,blue,alpha 0 to 255 
local red   = 0
local green = 0
local blue  = 0
local alpha = 255

-- canvas size determined by input file at the moment
local cx = 0 -- canvas x size
local cy = 0 -- canvas y size

-- mouse
local zoom = 1 -- adjusted with mouse wheel
local mx = 0
local my = 0

-- starts centered 
local xoff = (width-(cx*zoom))/2
local yoff = (height-(cy*zoom))/2
local bufferxoff = xoff
local bufferyoff = yoff

-- press "space" or "back" or "SE" or "select" to change the current tool at the moment
local TOOL = 3 -- 0 = pencil, 1 = move, 2 = rectangle select, 3 = color picker 

-- these are used by the program
local flag = { 0, 0, 0, 0, 0 } -- todo remove some vars, use this array neatly
local lastx = 0
local lasty = 0
local GRID = true
local LIFTED = 0 -- 0 = empty, 1 = canvas, 2 = selection
local SELECTED = { 0, 0, 0, 0 } -- x1, y1, x2, y2
local SELMODE = 0 -- a selection helper, 0 = empty 1 = between points, 2 = full
local utf8 = require("utf8")
local INTEXT = ""


function love.load()
    love.window.setTitle(TITLE)
    love.window.setMode(WINDOWWIDTH, WINDOWHEIGHT, {resizable=true, vsync=0, minwidth=320, minheight=240})
    love.graphics.setDefaultFilter("nearest", "nearest")
    font = love.graphics.newFont(14)
    love.graphics.setBackgroundColor(BGCOLOR)
    cursor = love.graphics.newImage("gfx/cursor.png")
    love.mouse.setVisible(false)

    loadImageFile("default.png")
    buffer = love.graphics.newCanvas(1024, 1024)

end

function loadImageFile(fileName) -- File

    imageFile = love.graphics.newImage(fileName)
    -- dynamically change canvas at image load
    local w = imageFile:getWidth()
    local h = imageFile:getHeight()
    cx = w
    cy = h

    canvas = love.graphics.newCanvas(cx, cy)
    love.graphics.setCanvas(canvas)
    love.graphics.draw(imageFile)
    love.graphics.setCanvas()

    xoff = (width-(cx*zoom))/2
    yoff = (height-(cy*zoom))/2

end

function love.draw()

    if GRID then
	   drawGrid(.5,.5,.5,1) -- under canvas
    end

    drawCanvas(xoff,yoff,canvas)
    if SELMODE > 2 then
        drawCanvas(bufferxoff,bufferyoff,buffer)
    end

    if GRID then
        drawGrid(.2,.2,.2,.3) -- over canvas
    end

    checkTools(385) -- gets inputs and pointer data

    applyTools() -- draws active tooling 
    
    drawToolBarH(15,385) -- x buffer on both sides, y top + 80 to bottom
    
    drawCursor()

    if FILEMODE == 1 then
        love.graphics.print("Open File: 'Start' + 'D-pad Down' for handheld text input mode, then 'Select' + 'A'to load file.", 20, 420)
        love.graphics.print(INTEXT, 20, 440)
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

function checkTools(y)

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
        if love.mouse.isDown(1) then
            if my < y - 80 then return end
            if (mx < 516 and my < y - 60) then -- red slider
                red = math.floor(mx/2)
                if red > 255 then red = 255 end
                r = red/255
            elseif (mx < 516 and my < y - 40) then -- green slider
                green = math.floor(mx/2)
                if green > 255 then green = 255 end
                g = green/255
            elseif (mx < 516 and my < y - 20) then -- blue slider
                blue = math.floor(mx/2)
                if blue > 255 then blue = 255 end
                b = blue/255
            elseif (mx < 516 and my < y) then -- alpha slider
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

function applyTools()

    mx, my = love.mouse.getPosition()

    -- MOVE
    if SELMODE == 3 and LIFTED == 1 then -- buffer
        bufferxoff = mx - lastx
        bufferyoff = my - lasty
    elseif LIFTED == 1 then -- CANVAS
        xoff = mx - lastx
        yoff = my - lasty
    end

    -- SELECT
    if SELMODE == 1 then
        love.graphics.setColor(1,1,1,1)
        love.graphics.rectangle("line",(SELECTED[0]*zoom)+xoff,(SELECTED[1]*zoom)+yoff,mx-((SELECTED[0]*zoom)+xoff),my-((SELECTED[1]*zoom)+yoff))

    elseif SELMODE == 2 then
        love.graphics.setColor(1,1,1,1)
        love.graphics.rectangle("line",(SELECTED[0]*zoom)+xoff,(SELECTED[1]*zoom)+yoff,((SELECTED[2]*zoom)+xoff)-((SELECTED[0]*zoom)+xoff),((SELECTED[3]*zoom)+yoff)-((SELECTED[1]*zoom)+yoff))
    end
end

function drawGrid(Gr,Gg,Gb,Ga)
    love.graphics.setColor(Gr,Gg,Gb,Ga)
    for x = 0, cx*zoom, zoom do --vert
        love.graphics.line(xoff+x, yoff+0, xoff+x, yoff+cy*zoom)
    end
    for y = 0, cy*zoom, zoom do --horz
        love.graphics.line(xoff+0, yoff+y, xoff+cx*zoom, yoff+y)
    end
end

function drawCanvas(x,y,c)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(c,x,y,0,zoom,zoom)
end

function drawCursor()
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(cursor, love.mouse.getX(), love.mouse.getY())
end

function drawToolBarH(x,y)
    love.graphics.setColor(.5,.5,.5,1) 
    love.graphics.rectangle("fill", x, y, width - x * 2, 80)
    drawCurrentColor(width-x-76,y+4)
    if TOOL == 3 then -- colour picker
        drawColorSlider(y-80)
    end
end

function drawCurrentColor(x,y) -- x,y = top left 32px radius, 72px sq background

    local m = 1
    for i = 0, 8 do 
        for j = 0, 8 do 
            love.graphics.setColor(.5+m*.4,.5+m*.4,.5+m*.4,1) 
            love.graphics.rectangle("fill",x+j*8,y+i*8,8,8)
            m = m * -1
        end
    end

    love.graphics.setColor(r,g,b,a) 
    love.graphics.circle("fill",x+36, y+36, 32)
end

function drawColorSlider(y)    
    love.graphics.setColor(.7,.7,.7,1)
    love.graphics.rectangle("fill", 0, y, 550,80)    -- white backdrop
    x=0
    while x < 255 do -- the slider bars
        love.graphics.setColor(x/255,0,0,1)
        love.graphics.circle("fill", x*2, y+10, 7, 3) -- red
        love.graphics.setColor(0,x/255,0,1)
        love.graphics.circle("fill", x*2, y+30, 7, 3) -- green
        love.graphics.setColor(0,0,x/255,1)
        love.graphics.circle("fill", x*2, y+50, 7, 3)  -- blue
        love.graphics.setColor(0,0,0,x/255)
        love.graphics.circle("fill", x*2, y+70, 7, 3)  -- alpha
        x = x + 2
    end
    
    -- the slider line
    love.graphics.setColor(1,1,1,1)
    love.graphics.circle("fill", red * 2,   y+10, 5, 4)
    love.graphics.circle("fill", green * 2, y+30, 5, 4)
    love.graphics.circle("fill", blue * 2,  y+50, 5, 4)
    love.graphics.circle("fill", alpha * 2, y+70, 5, 4)


    x=520
    love.graphics.setColor(r,0,0,1)
    love.graphics.circle("fill", x, y+10, 8)
    love.graphics.circle("fill", x+20, y+10, 8)
    love.graphics.rectangle("fill", x, y+2, 20, 16)
    love.graphics.setColor(0,g,0,1)
    love.graphics.circle("fill", x, y+30, 8)  
    love.graphics.circle("fill", x+20, y+30, 8)
    love.graphics.rectangle("fill", x, y+22, 20, 16)
    love.graphics.setColor(0,0,b,1)
    love.graphics.circle("fill", x, y+50, 8)
    love.graphics.circle("fill", x+20, y+50, 8)
    love.graphics.rectangle("fill", x, y+42, 20, 16)
    love.graphics.setColor(1,1,1,a)
    love.graphics.circle("fill", x, y+70, 8)
    love.graphics.circle("fill", x+20, y+70, 8)
    love.graphics.rectangle("fill", x, y+62, 20, 16)

    x=516
    love.graphics.setColor(1,1,1,1) 
    love.graphics.print("R:"..string.format("%02X", red),   x, y+3)
    love.graphics.print("G:"..string.format("%02X", green), x, y+23)
    love.graphics.print("B:"..string.format("%02X", blue),  x, y+43)
    love.graphics.setColor(0,0,0,1) 
    love.graphics.print("A:"..string.format("%02X", alpha), x, y+63)
        
end

function setSelction()
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
end

function love.textinput(t)
    INTEXT = INTEXT .. t
end

function love.keypressed(k)

    mx, my = love.mouse.getPosition()

    if k == "backspace" then
        if INTEXT then
            local textoffset = utf8.offset(INTEXT, -1)
            if textoffset then
                INTEXT = string.sub(INTEXT, 1, textoffset - 1)
            end
        end
    end

    if k == "lctrl" then
        loadImageFile("temp.png")
        -- todo: test gptokey text input to load a file
            -- otherwise use a dedicated input folder and show a list.. for ipairs...
            -- a simple folder icon on the toolbar will do, until a top menubar shows up 
    end

    if k == "tab" then
        INTEXT = ""
        FILEMODE = 1
    end

    if FILEMODE == 1 and k == "return" then
        loadImageFile(INTEXT)
        FILEMODE = 0
    elseif k == "return" then
        love.graphics.setCanvas()    
        local imagedata = canvas:newImageData()
        imagedata:encode("png", "temp.png")
    end

    if k == "lshift" then -- move canvas anytime (shift)
        xoff = mx - cx * zoom / 2
        yoff = my - cy * zoom / 2
        if SELMODE == 3 then
            bufferxoff = mx
            bufferyoff = my
            lastx = mx
            lasty = my
        end
    end

    if k == "rctrl" then
        if GRID then
            GRID = false
        else
            GRID = true
        end
    end

    if k == "pageup" then
        zoom = zoom + .25
        if zoom > 100 then zoom = 100 end
    end
    if k == "pagedown" then
        zoom = zoom - .25
        if zoom < .5 then zoom = .5 end
    end

    if k == "space" then
        TOOL = TOOL + 1
        if TOOL > 3 then TOOL = 0 end
        -- SELMODE = 0 -- todo, keeping selection active. properly deal with consequences
    end

    if SELMODE > 0 and k == "backspace" then -- B to clear user variables
        SELMODE = 0
        SELECTED[0] = 0
        SELECTED[1] = 0
        SELECTED[2] = 0
        SELECTED[3] = 0
        love.graphics.setCanvas(buffer)
        love.graphics.clear()
        love.graphics.setCanvas()
        LIFTED = 0
        FILEMODE = 0
        INTEXT = ""
    end

    if TOOL == 0 then -- pencil
    
        if k == "delete" then
            erasePixel((mx-xoff)/zoom,(my-yoff)/zoom)
    
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
        
        if SELMODE == 2 then
            if k == "delete" then -- cut
                love.graphics.setCanvas(buffer)
                love.graphics.clear()
                setSelction()
                love.graphics.draw(canvas)
                love.graphics.setCanvas(canvas)
                love.graphics.clear()
                love.graphics.setCanvas()
                love.graphics.setScissor()
                bufferxoff = xoff
                bufferyoff = yoff
                lastx = mx - xoff
                lasty = my - yoff
                SELMODE = 3
                LIFTED = 1   
            elseif k == "rshift" then -- copy
                love.graphics.setCanvas(buffer)
                love.graphics.clear()
                setSelction()
                love.graphics.draw(canvas)
                love.graphics.setCanvas()
                love.graphics.setScissor()
                bufferxoff = xoff
                bufferyoff = yoff
                lastx = mx - xoff
                lasty = my - yoff
                SELMODE = 3
                LIFTED = 1   
            end
        elseif SELMODE == 3 then -- paste
            if k == "insert" then
                love.graphics.setCanvas(canvas)
                love.graphics.draw(buffer, (bufferxoff-xoff)/zoom, (bufferyoff-yoff)/zoom)
                love.graphics.setCanvas()
            end
        end
    end
end

function love.mousepressed(x, y, button, it, p) -- look for isDown() also throughout checkTools()
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
    elseif button == 3 then -- move canvas anytime (middle mouse button)
        xoff = x - cx * zoom / 2
        yoff = y - cy * zoom / 2
        if SELMODE == 3 then
            bufferxoff = x
            bufferyoff = y
            lastx = x
            lasty = y
        end
    end
end

function love.mousereleased(x, y, button, it, p) 
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
        zoom = zoom + .25
        if zoom > 100 then zoom = 100 end
    end
    if y < 0 then
        zoom = zoom - .25
        if zoom < .25 then zoom = .25 end
    end
end