-- ThunbPaint: By Photonic2790@github.com
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

-- fixed canvas size, change it here
local cx = 16 -- canvas x size
local cy = 16 -- canvas y size

local zoom = 16 -- adjusted with mouse wheel

-- starts centered 
local xoff = width/2-(cx*zoom)/2
local yoff = height/2-(cy*zoom)/2


-- one tool per execution until toolbar gets written, set the tool here
local TOOL = 2 -- 0 = pencil, 1 = move, 2 = rectangle select

-- these are used by the program
local lastx = 0
local lasty = 0
local LIFTED = 0 -- 0 = empty, 1 = canvas, 2 = selection
local SELECTED = { 0, 0, 0, 0 } -- x1, y1, x2, y2
local SELMODE = 0 -- a selection helper, 0 = empty 1 = between points, 2 = full 

--[[
todo list, 
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

    love.graphics.setCanvas(canvas)
    love.graphics.draw(testPNG)
    love.graphics.setCanvas()
end

function love.draw()
	drawGrid(.5,.5,.5,1)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(canvas,xoff,yoff,0,zoom,zoom)
    drawGrid(.2,.2,.2,.3)

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

function love.keypressed(k)

    if k == "return" then
        love.graphics.setCanvas()    
        local imagedata = canvas:newImageData()
        imagedata:encode("png", "test.png")
    end

    if TOOL == 0 then -- pencil
        if k == "a" then
            love.graphics.setColor(1,1,1,1)
            love.graphics.setCanvas(canvas)
            love.graphics.points((love.mouse.getX()-xoff)/zoom, (love.mouse.getY()-yoff)/zoom)
            love.graphics.setCanvas()
    
        elseif k == "b" then
            love.graphics.setColor(0,0,0,0)
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