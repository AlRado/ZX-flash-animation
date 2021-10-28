----------------------------------------------------------------------
--
-- ZX flash animation
-- The Aseprite tools to create and import/export ZX-Spectrum flash animation (no pixels, only attributes)
-- Screen size: 32x24
-- Border size: 4
-- Palette: ZX-Spectrum
-- Frames count: 2
-- Author: Al-Rado
-- 2021 A.D.
--
----------------------------------------------------------------------

local version = "0.5.3"

local border_size = 4
local screen_w = 32
local screen_h = 24
local flashDuration = 0.33
local alphaColor = 0
local defaultScreenColor = 5
local defaultBorderColor = 6
local dialogHeight = 285
local rotateForVertical = "90"
local currentFrame = 1

local function showStartDialog()
    -- start dialog
    local dlg = Dialog("Is the layout horizontal or vertical?")
    dlg:button{ id="horizontal", text="Horizontal" }
    dlg:button{ id="vertical", text="Vertical" }
    dlg:show{   wait=true,
                bounds=Rectangle(380, 220, 250, 40)}

    if dlg.data.vertical then
        screen_w = 24
        screen_h = 32
    end
end

local function activeFrameNumber()
    local f = app.activeFrame
    if f == nil then
      return 1
    else
      return f.frameNumber
    end
end

local function saveCurrentFrame()
    currentFrame = activeFrameNumber()
end

local function gotoCurrentFrame()
    if (currentFrame == 1) then
        app.command.GotoFirstFrame()
    else
        app.command.GotoLastFrame()
    end
end

local function clearScreenZone(frameNum, colorNum)
    app.useTool{
        tool="filled_rectangle",
        color=colorNum,
        points={ {border_size, border_size}, {screen_w + border_size - 1, screen_h + border_size - 1} },
        layer=app.activeLayer,
        frame=frameNum
    }
end

local function clearAll(frameNum, colorValue)
    app.useTool{
        tool="filled_rectangle",
        color=colorValue,
        points={ {0, 0}, {screen_w + border_size*2, screen_h + border_size*2}},
        frame=frameNum
    }
end

local function init()
    -- create sprite
    local spr = Sprite(screen_w + border_size*2, screen_h + border_size*2, ColorMode.INDEXED)
    app.command.BackgroundFromLayer()

    -- load ZX-Spectrum palette
    local palette = Palette{ fromResource="ZX Spectrum" }
    palette:setColor(0, Color{ r=0, g=0, b=0, a=255 })
    -- minor changes in black color with bright
    palette:setColor(8, Color{ r=0, g=0, b=5, a=255 })
    spr:setPalette(palette)

    app.bgColor = defaultScreenColor

    -- set frame duration
    app.activeFrame.duration = flashDuration
    -- add new frame and go to first frame
    app.command.NewFrame()
    app.activeFrame.duration = flashDuration
    app.command.GotoFirstFrame()

    -- setup screen layer
    clearScreenZone(1, defaultScreenColor)
    clearScreenZone(2, defaultScreenColor)
    app.activeLayer.name = "Screen"

    -- add and setup border layer
    app.command.NewLayer()
    app.activeLayer.name = "Border"
    clearAll(1, defaultBorderColor)
    clearAll(2, defaultBorderColor)
    clearScreenZone(1, alphaColor)
    clearScreenZone(2, alphaColor)
    -- lock border layer
    app.command.LayerLock()
    app.command.GotoPreviousLayer()

    -- zoom and scroll to center
    -- app.command.Zoom(800) --- <- not working
    for i = 1, 6 do
        app.command.Zoom()
    end
    app.command.ScrollCenter()

    -- Toolbar
    local dlg = Dialog("ZX flash animation v." .. version)
    dlg :separator{     text="Border" }
        :shades{        id="BorderColor",
                        label="Border colors:",
                        mode="pick",
                        colors={ 0, 1, 2, 3, 4, 5, 6, 7 },
                        onclick=function(ev) onChangeBorder(ev.color) end }

        :separator{     text="Bright" }
        :button{        text="Apply bright attr 1fr -> 2fr",
                        onclick=function() onApplyBrightToSecondFrame() end }

        :separator {    text="Convert BLACK in animation " }
        :button{        text="NO BRIGHT",
                        onclick=function() convertBlackInAnimation(false) end }
        :button{        text="BRIGHT",
                        onclick=function() convertBlackInAnimation(true) end }

        :separator{     text="Change bright attr in selection" }
        :check{         id="SetBrightCheck",
                        text="bright",
                        selected=true,
                        onclick=function()  end }
        :button{        text="Only BLACK",
                        onclick=function() onChangeBrightInSelection(dlg.data["SetBrightCheck"], true) end }
        :button{        text="All colors",
                        onclick=function() onChangeBrightInSelection(dlg.data["SetBrightCheck"], false) end }

        :separator {    text="Save x10 preview" }
        :button{        text="frames .png",
                        onclick=function() onSaveX10(false) end}

        :button{        text="anim .gif",
                        onclick=function() onSaveX10(true) end}

        :separator {    text="Export to .scr" }
        :button{        text="frame",
                        onclick=function() onExport(false) end}

        :button{        text="animation",
                        onclick=function() onExport(true) end}

        :separator {    text="Import from .scr" }

    if (screen_w == 24) then
        dlg:combobox{
                        id="rotate",
                        label="Rotation:",
                        -- TODO implement "0" and "180"
                        options={ "90", "270" },
                        onchange=function() onChangeRotate()  end }
        dialogHeight = dialogHeight + 24
    end

    dlg :button{        text="frame",
                        onclick=function() onImport(false) end}
    dlg :button{        text="animation",
                        onclick=function() onImport(true) end}

    dlg :show{          wait=false,
                        bounds=Rectangle(700, 200, 212, dialogHeight)}

end

function onChangeRotate()
    rotateForVertical = dlg.data.rotate
end

function onChangeBorder(color)
    -- delete selection
    app.activeSprite.selection:deselect()
    app.command.GotoNextLayer()
    app.command.LayerLock(false)

    -- zero is the alpha channel
    if (color.index == 0.0) then
        color.index = 8.0
    end
    clearAll(1, color)
    clearAll(2, color)
    clearScreenZone(1, alphaColor)
    clearScreenZone(2, alphaColor)
    app.command.LayerLock(true)
    app.command.GotoPreviousLayer()
end

local function isBrightError()
    saveCurrentFrame()
    app.command.GotoFirstFrame()
    local img1 = app.activeCel.image:clone()
    app.command.GotoLastFrame()
    local img2 = app.activeCel.image:clone()
    local isBrightError = false

    for y = border_size, getMaxY() do
        for x = border_size, getMaxX() do
            local a = img1:getPixel(x, y)
            local b = img2:getPixel(x, y)
            if ((a >= 8 and b < 8) or (a < 8 and b >= 8)) then
                isBrightError = true
            end
        end
    end

    gotoCurrentFrame()

    return isBrightError
end

function getMaxX()
    return border_size+screen_w-1
end

function getMaxY()
    return border_size+screen_h-1
end

function onApplyBrightToSecondFrame()
    saveCurrentFrame()
    app.command.GotoFirstFrame()
    local img1 = app.activeCel.image:clone()
    app.command.GotoLastFrame()
    local img2 = app.activeCel.image:clone()

    for y = border_size, getMaxY() do
        for x = border_size, getMaxX() do
            local a = img1:getPixel(x, y)
            local b = img2:getPixel(x, y)
            if (b >= 8) then
                b = b - 8
                img2:drawPixel(x, y, b)
            end
            if (a >= 8) then
                b = b + 8
                img2:drawPixel(x, y, b)
            end
        end
    end
    app.activeCel.image = img2
    app.refresh()
    gotoCurrentFrame()

    app.alert("The BRIGHT attributes from the first into the second frame successfully applied!")
end

function convertBlackInAnimation(convertToBrightBlack)
    saveCurrentFrame()
    app.command.GotoFirstFrame()
    local img1 = app.activeCel.image:clone()
    doReplaceBlack(img1, convertToBrightBlack)
    app.activeCel.image = img1
    app.refresh()

    app.command.GotoLastFrame()
    local img2 = app.activeCel.image:clone()
    doReplaceBlack(img2, convertToBrightBlack)
    app.activeCel.image = img2
    gotoCurrentFrame()
    app.refresh()
end

function doReplaceBlack(img, convertToBrightBlack)
    local sourceColor = 0
    local targetColor = 8
    if convertToBrightBlack == false then
        sourceColor = 8
        targetColor = 0
    end

    for y = border_size, getMaxY() do
        for x = border_size, getMaxX() do
            if img:getPixel(x, y) == sourceColor then
                img:drawPixel(x, y, targetColor)
            end
        end
    end
end

function onChangeBrightInSelection(brightValue, onlyBlack)
    local image = app.activeCel.image:clone()

    for y = border_size, getMaxY() do
        for x = border_size, getMaxX() do
            if (app.activeSprite.selection:contains(x, y)) then
                local a = image:getPixel(x, y)
                if (onlyBlack == false or (onlyBlack == true and (a == 0 or a == 8))) then
                    if (brightValue == true and a < 8) then
                        a = a + 8
                    end
                    if (brightValue == false and a >= 8) then
                        a = a - 8
                    end
                    image:drawPixel(x, y, a)
                end
            end
        end
    end
    app.activeCel.image = image
    app.refresh()
end

function onExport(isTwoFrames)
    if (isTwoFrames and isBrightError()) then
        app.alert("The brightness attributes in the frames are different!")
        return
    end

    local targetName = "frame"
    if (isTwoFrames) then
        targetName = "animation"
        saveCurrentFrame()
        -- get image from the active frame of the active sprite
        app.command.GotoFirstFrame()
    end
    local img1 = app.activeCel.image:clone()
    local img2 = nil

    if (isTwoFrames) then
        -- create second frame
        app.command.GotoLastFrame()
        img2 = app.activeCel.image:clone()
        app.command.GotoFirstFrame()
        gotoCurrentFrame()
    end

    -- fill the empty pixels data
    local bitmap = {}
    for i = 0, 6143 do
        table.insert(bitmap, 0)
    end

    -- fill the attributes
    if (screen_w == 32) then
        -- horizontal view
        for y = border_size, getMaxY() do
            for x = border_size, getMaxX() do
                dataToTable(img1, img2, x, y, bitmap, isTwoFrames)
            end
        end
    else 
        -- vertical view
        for x = getMaxX(), border_size, -1 do
            for y = border_size, getMaxY() do
                dataToTable(img1, img2, x, y, bitmap, isTwoFrames)
            end
        end
    end

    -- save file
    local dlg = Dialog()
    dlg:file{   id="export_file",
                label="Export " .. targetName .. " to:",
                title="Export " .. targetName .. " to .scr file",
                open=false,
                save=true,
                filetypes={"scr"},
                filename=""}
        :button{id="save", text="Save" }
        :show{  wait=true,
                bounds=Rectangle(380, 220, 250, 60)}

    if (dlg.data.save) then
        local export_file = dlg.data.export_file
        if (export_file ~= "") then
            local file = io.open(export_file,'wb')
            file:write(string.char(table.unpack(bitmap)))
            file:close()
            app.alert("The " .. targetName .. " was saved to: " .. export_file)
        else
            app.alert("Please select a file name")
            onExport(isTwoFrames)
        end
    end
end

function dataToTable(img1, img2, x, y, bitmap, isTwoFrames)
    local a = img1:getPixel(x, y)
    local b = 0
    local bright = 0
    local flash = 128

    if (a >= 8) then
        a = a - 8
        -- get the BRIGHT attribute from the first frame only
        bright = 64
    end

    if (isTwoFrames) then
        b = img2:getPixel(x, y)
        if (b >= 8) then
            b = b - 8
        end
    end

    if (isTwoFrames == true) then
        -- write INK + PAPER + BRIGHT + FLASH
        table.insert(bitmap, a + (b * 8) + bright + flash)
    else
        -- write PAPER + BRIGHT
        table.insert(bitmap, a * 8 + bright)
    end
end

local function loadBinary(filename)
    local inp = assert(io.open(filename, "rb"))
    local str = assert(inp:read("*all"))
    local table = {}
    for i = 1, #str do
        table[i] = string.byte(str:sub(i, i))
    end
    assert(inp:close())

    return table
end

function onImport(isTwoFrames)
    local targetName = "frame"
    if (isTwoFrames == true) then
        targetName = "animation"
    end

    -- load file
    local dlg = Dialog()
    dlg:file{   id="import_file",
                label="Import " .. targetName .. " from:",
                title="Import " .. targetName .. " from .scr file",
                open=true,
                save=false,
                filetypes={"scr"},
                filename="" }
        :button{id="import", text="Import" }
        :show{  wait=true,
                bounds=Rectangle(380, 220, 250, 60)}

    if (dlg.data.import) then
        local import_file = dlg.data.import_file
        if (import_file ~= "") then
            local data = loadBinary(import_file)
            drawData(data, isTwoFrames)
        else
            app.alert("Please select file")
            onImport(isTwoFrames)
        end
    end
end

function drawData(data, isTwoFrames)
    if (isTwoFrames == true) then
        saveCurrentFrame()
        app.command.GotoFirstFrame()
    end

    -- get the image from the active frame of the active sprite
    local frame1 = app.activeCel.image:clone()
    local frame2 = nil

    -- create second frame
    if (isTwoFrames == true) then
        app.command.GotoLastFrame()
        frame2 = app.activeCel.image:clone()
    end

    -- fill the attributes
    local i = 6145
    if (screen_w == 32) then
        -- horizontal view
        for y = border_size, getMaxY() do
            for x = border_size, getMaxX() do
                doDraw(data[i], x, y, frame1, frame2)
                i = i + 1
            end
        end
    else
        -- vertical view
        if (rotateForVertical == "90") then
            for x = getMaxX(), border_size, -1 do
                for y = border_size, getMaxY() do
                    doDraw(data[i], x, y, frame1, frame2)
                    i = i + 1
                end
            end
        elseif (rotateForVertical == "270") then
            for x = border_size, getMaxX() do
                for y = getMaxY(), border_size, -1 do
                    doDraw(data[i], x, y, frame1, frame2)
                    i = i + 1
                end
            end
        end
    end

    if (isTwoFrames == true) then
        app.command.GotoFirstFrame()
    end

    app.activeCel.image = frame1

    if (isTwoFrames == true) then
        app.command.GotoLastFrame()
        app.activeCel.image = frame2
        gotoCurrentFrame()
    end
    app.refresh()
end

function doDraw(attr, x, y, frame1, frame2)
    if (attr ~= nil) then
        local inkMask = 7
        local paperMask = 56
        local brightMask = 64
        local flashMask = 128

        local ink = attr & inkMask
        local paper = (attr & paperMask) >> 3
        local bright = (attr & brightMask) >> 6
        local flash = (attr & flashMask) >> 7
        -- if the FLASH disabled then ink = paper (color in the frame2 = color in the frame1)
        if (flash == 0) then
            ink = paper
        end
        if (bright == 1) then
            ink = ink + 8
            paper = paper + 8
        end

        frame1:drawPixel(x, y, paper)
        if (frame2 ~= nil) then
            frame1:drawPixel(x, y, ink)
            frame2:drawPixel(x, y, paper)
        end
    end
end

function onSaveX10(isTwoFrames)
    local targetName = "png"
    if (isTwoFrames == true) then
        targetName = "gif"
    end

    -- save file
    local dlg = Dialog()
    dlg:file{   id="save_file",
                label="Save x10 frames ." .. targetName .. " to:",
                title="Save x10 frames ." .. targetName .. " file",
                open=false,
                save=true,
                filetypes={targetName},
                filename=""}
        :button{id="save", text="Save" }
        :show{  wait=true,
                bounds=Rectangle(380, 220, 200, 100)}

    if (dlg.data.save) then
        app.command.SpriteSize{ ui = false, scale = 10, method="nearest" }
        local save_file = dlg.data.save_file
        app.activeSprite:saveCopyAs(save_file)
        app.command.Undo()
        app.alert("The x10 frames ." .. targetName .. " was saved to file: " .. save_file)
    end
end

showStartDialog()
init()
