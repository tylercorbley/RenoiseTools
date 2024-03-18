-- Reload the script whenever this file is saved.
-- Additionally, execute the attached function.
_AUTO_RELOAD_DEBUG = function()

end

-- Read from the manifest.xml file.
class "RenoiseScriptingTool" (renoise.Document.DocumentNode)
function RenoiseScriptingTool:__init()
    renoise.Document.DocumentNode.__init(self)
    self:add_property("Name", "Untitled Tool")
    self:add_property("Id", "Unknown Id")
end

--------------------------------------------------------------------------------
-----------seq to pattern--------------------
--get the pattern object based on the index inside the sequence instead of the index in the patterns list.
function pattern_from_sequence(index)
    local song = renoise.song()
    local seq = song.sequencer
    if index <= #seq.pattern_sequence then
        return song:pattern(seq.pattern_sequence[index])
    else
        return nil
    end
end

-- finds pattern index number from pattern objects
function findPatternIndex(patternObj)
    for index, pattern in ipairs(renoise.song().patterns) do
        if pattern == patternObj then
            return index
        end
    end
    return nil -- Pattern object not found
end

--finds pattern ID from sequence ID
function patternID_from_sequenceID(seqID)
    return findPatternIndex(pattern_from_sequence(seqID))
end

-------------------UTILITY--------------------------
--is line not empty checker function
local function isLineEmpty(lineID, columnID, patTrack, subColumnID)
    local deviceString
    if subColumnID == renoise.Song.SUB_COLUMN_VOLUME then
        deviceString = patTrack:line(lineID).note_columns[columnID].volume_string
        --print("volume"..deviceString)
    elseif subColumnID == renoise.Song.SUB_COLUMN_PANNING then
        deviceString = patTrack:line(lineID).note_columns[columnID].panning_string
        --print("panning"..deviceString)
    elseif subColumnID == renoise.Song.SUB_COLUMN_DELAY then
        deviceString = patTrack:line(lineID).note_columns[columnID].delay_string
        --print("delay"..deviceString)
    elseif subColumnID >= 6 then
        deviceString = patTrack:line(lineID).effect_columns[columnID].number_string
    end
    -- Check if the line is not empty
    if subColumnID > 6 then
        if deviceString == "00" then
            return true
        else
            return false
        end
    else
        if deviceString == ".." then
            return true
        else
            return false
        end
    end
end
--is sample command?
local function isSample(deviceString)
    local valuesToCheck = { "0A", "0U", "0D", "0G", "0V", "0I", "0O", "0T", "0C", "0S", "0B", "0E", "0N" }
    for _, value in ipairs(valuesToCheck) do
        if deviceString == value then
            return true
        end
    end
    return false -- Return false only after checking all values
end
--WAVE FUNCTIONS---------------------------------------------------------
-- math.max here returns the larger from the two numbers it receives.
-- this is to make sure f is always at least 1 without an "if" statement
local function saw(t, f)
    local tf = t * math.max(1, f)
    return tf - math.floor(tf)
end

local function sqr(t, f)
    return math.floor(saw(t, f) + 0.5)
end

local function sin(t, f)
    local tf = t * math.pi * 2 * (f + 0.5)
    return math.sin(tf - math.pi / 2) * 0.5 + 0.5
end

local function tri(t, f)
    local tf = t * (f + 0.5) * 2 + 1
    return math.abs((tf % 2) - 1.0)
end

function lerp(a, b, t)
    return a + t * (b - a)
end

local function lin(t, f)
    return t
end

local function logIn(t, f)
    if f < 2 then
        f = 2
    end
    if t == 0 then
        return 0
    else
        return f ^ (10 * t - 10)
    end
end

local function logOut(t, f)
    if f < 2 then
        f = 2
    end
    if t == 1 then
        return 1
    else
        return 1 - f ^ (-10 * t)
    end
end

function easeOutBounce(x, f)
    local n1 = 7.5625
    local d1 = 2.75

    if x < 1 / d1 then
        return n1 * x * x
    elseif x < 2 / d1 then
        x = x - 1.5 / d1
        return n1 * x * x + 0.75
    elseif x < 2.5 / d1 then
        x = x - 2.25 / d1
        return n1 * x * x + 0.9375
    else
        x = x - 2.625 / d1
        return n1 * x * x + 0.984375
    end
end

function easeInBounce(x, f)
    return 1 - easeOutBounce(1 - x)
end

function thresholdRan()
    local poles = 0 -- Initialize poles outside of the functions
    local poleRandomPrev = 2
    local poleRandomNext = math.random()
    return function(t, polesPlus, startValue, endValue)
        if poles > .95 and t < .05 then
            poleRandomPrev = startValue / 255
            poleRandomNext = math.random()
            poles = polesPlus
        end
        if poleRandomPrev == 2 then
            poleRandomPrev = startValue / 255
            poles = poles + polesPlus
        end
        if t > poles then
            poleRandomPrev = poleRandomNext
            poleRandomNext = math.random()
            poles = poles + polesPlus
        end
        if poles == 1 then
            poleRandomNext = endValue / 255
        end
        return poleRandomPrev, poleRandomNext, poles
    end
end

--locked value
local poleRan = thresholdRan()

function GradientRan(t, f, startValue, endValue)
    local polesPlus = 1 / math.max(1, f + 1)
    local ran1, ran2, poles = poleRan(t, polesPlus, startValue, endValue)
    local tSub = (t - (poles - polesPlus)) / polesPlus
    print(startValue, endValue, "t", t, "poles", poles, "random prev", ran1, "random next", ran2, "tsub", tSub, "lerp",
        lerp(ran1, ran2, tSub))
    if f == 0 then
        return math.random()
    else
        if startValue < endValue then
            return lerp(ran1, ran2, tSub), true
        else
            return lerp(ran1, ran2, tSub), false
        end
    end
end

function interpolate_with(waveFun, startValue, endValue, curStep, stepCounter, numOsc)
    local t = curStep / (stepCounter + 1)
    local wavyTime, flip = waveFun(t, numOsc, startValue, endValue)
    if flip == nil then
        return lerp(startValue, endValue, wavyTime)
    elseif flip then
        return lerp(startValue, endValue, wavyTime)
    else
        return lerp(endValue, startValue, wavyTime)
    end
end

-----------Looking for patterns or lines or values--------------------
--establish parameter value from device based on first value
local function parameterOldFunc(trackID, deviceString)
    local deviceID = 1
    local deviceStringSplit = 1
    local deviceParamID
    local parameterOld = 1
    if deviceString ~= "00" and deviceString ~= ".." then
        deviceID = tonumber(string.sub(deviceString, 1, 1)) + 1 -- first part
        deviceStringSplit = deviceString:sub(2)                 -- second part
        if deviceStringSplit == "P" then                        --this stuff is for using the first track device with panning, width, and volume
            deviceParamID = renoise.song().tracks[trackID].prefx_panning
        elseif deviceStringSplit == "L" then
            deviceParamID = renoise.song().tracks[trackID].prefx_volume
        elseif deviceStringSplit == "W" then
            deviceParamID = renoise.song().tracks[trackID].prefx_width
        else
            deviceParamID = renoise.song().tracks[trackID].devices[deviceID].parameters[tonumber(deviceStringSplit)]
        end
        parameterOld = math.floor((255 / (deviceParamID.value_max - deviceParamID.value_min)) *
            (deviceParamID.value - deviceParamID.value_min) + 0.5) --gets the value of the parameter on the device currently
        return parameterOld
    else
        return nil
    end
end

function lineIDAdder(lineID, seqID, patternLength)
    local lineIDNext = lineID + 1
    local seqIDNext = seqID
    if lineIDNext > patternLength then
        seqIDNext = seqID + 1
        lineIDNext = 1
    end
    if seqID == 1 and lineID == 1 then
        lineIDNext = 1
    end
    return lineIDNext, seqIDNext
end

function isDeviceStringEqual(lineID, columnID, lineIDInit, seqID, trackID,seqIDInit)
    local deviceStringLineID = renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID).effect_columns[columnID].number_string
    local deviceStringLineIDInit = renoise.song().patterns[patternID_from_sequenceID(seqIDInit)]:track(trackID):line(lineIDInit).effect_columns[columnID].number_string
    print(lineID, seqID, lineIDInit,deviceStringLineID, deviceStringLineIDInit)
    if deviceStringLineID == deviceStringLineIDInit then
        return true
    else
        return false
    end
end

--find previous point function
function findPreviousPoint(lineID, columnID, seqID, trackID, beginningOfProject, patternLengthPrev, patternLength,
                           lineDown, subColumnID)
    local lineIDInit = lineID
    local seqIDInit = seqID
    --if line is empty --	find next and previous point, interpolate between
    if isLineEmpty(lineID, columnID, renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID), subColumnID) then
        while isLineEmpty(lineID, columnID, renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID), subColumnID) do
            lineID = lineID - 1
            if lineID == 0 then
                seqID = seqID - 1
                if seqID == 0 then
                    print("Beginning of song")
                    seqID = 1
                    beginningOfProject = true
                    lineID = 1
                    break
                end
                patternLengthPrev = renoise.song().patterns[patternID_from_sequenceID(seqID)].number_of_lines
                lineID = patternLengthPrev
            end
        end
        --if line is not empty
    else
        --if next line is not empty		find next and previous point where deviceString differs OR empty, stop at last full point(go back/forward one), interpolate between
        local lineIDNext, seqIDNext = lineIDAdder(lineID, seqID, patternLength)
        if not isLineEmpty(lineIDNext, columnID, renoise.song().patterns[patternID_from_sequenceID(seqIDNext)]:track(trackID), subColumnID) then
            while not isLineEmpty(lineID, columnID, renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID), subColumnID) and isDeviceStringEqual(lineID, columnID, lineIDInit, seqID, trackID, seqIDInit) do
                lineID = lineID - 1
                if lineID == 0 then
                    seqID = seqID - 1
                    print(seqID)
                    if seqID == 0 then
                        seqID = 1
                        beginningOfProject = false
                        lineID = 1
                        break
                    end
                    patternLengthPrev = renoise.song().patterns[patternID_from_sequenceID(seqID)].number_of_lines
                    lineID = patternLengthPrev
                    print("prior point seqID",lineID, seqID)
                end
            end
            print(isLineEmpty(lineID, columnID, renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID), subColumnID),lineID, seqID, isDeviceStringEqual(lineID, columnID, lineIDInit, seqID, trackID, seqIDInit))
            lineID = lineIDAdder(lineID, seqID, patternLength)
        end
    end

    -- Check if the point is the last line of the pattern
    lineDown = lineID + 1
    local seqNext = seqID -- patternID == start point pattern
    if patternLengthPrev == nil then
        patternLengthPrev = patternLength
    end
    if lineDown > patternLengthPrev then
        lineDown = 1
        seqNext = seqID + 1
    end

    -- Return the updated values
    return lineID, seqID, beginningOfProject, patternLengthPrev, patternLength, lineDown, seqNext
end

--find next point function
function findNextModulationPoint(lineDown, columnID, seqNext, trackID, seqCount, subColumnID)
    local stepCounter = 0
    local endOfProject = false
    local lineIDInit = lineDown
    local seqIDInit = seqNext
    local patternLength = renoise.song().patterns[patternID_from_sequenceID(seqNext)].number_of_lines

    if isLineEmpty(lineDown, columnID, renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID), subColumnID) then
        while isLineEmpty(lineDown, columnID, renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID), subColumnID) do
            lineDown = lineDown + 1
            stepCounter = stepCounter + 1

            if lineDown == patternLength + 1 then
                seqNext = seqNext + 1
                lineDown = 1
            end

            if seqNext > seqCount then
                seqNext = seqNext - 1
                endOfProject = true
                print("End of project")
                lineDown = patternLength
                --stepCounter = stepCounter-1
                break
            end
        end
    else
        local lineIDNext, seqIDNext = lineIDAdder(lineDown, seqNext, patternLength)
        if isLineEmpty(lineIDNext, columnID, renoise.song().patterns[patternID_from_sequenceID(seqIDNext)]:track(trackID), subColumnID) then
            while isLineEmpty(lineDown, columnID, renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID), subColumnID) do
                lineDown = lineDown + 1
                stepCounter = stepCounter + 1

                if lineDown == patternLength + 1 then
                    seqNext = seqNext + 1
                    lineDown = 1
                end

                if seqNext > seqCount then
                    seqNext = seqNext - 1
                    endOfProject = true
                    print("End of project")
                    lineDown = patternLength
                    --stepCounter = stepCounter-1
                    break
                end
            end
        else
            while not isLineEmpty(lineDown, columnID, renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID), subColumnID) and isDeviceStringEqual(lineIDNext, columnID, lineIDInit, seqIDNext, trackID, seqIDInit) do
                lineDown = lineDown + 1
                stepCounter = stepCounter + 1
                local patternLength = renoise.song().patterns[patternID_from_sequenceID(seqNext)].number_of_lines

                if lineDown == patternLength + 1 then
                    seqNext = seqNext + 1
                    lineDown = 1
                end

                if seqNext > seqCount then
                    seqNext = seqNext - 1
                    endOfProject = false
                    lineDown = patternLength
                    --stepCounter = stepCounter-1
                    break
                end
            end
            stepCounter = stepCounter - 1
            if lineDown - 1 == 0 then
                lineDown = patternLength
                seqNext = seqNext - 1
            else
                lineDown = lineDown - 1
            end
        end
    end

    -- Return the updated values
    return lineDown, seqNext, stepCounter, endOfProject
end

--prints to renoise
function processModulationPoints(lineDown, columnID, seqNext, trackID, parameterStart, parameterEnd, stepCounter, curStep,
                                 deviceString, seqCount, beginningOfProject, patternLength, lineID, seqID,
                                 deviceStringEnd, waveFun, subColumnID, numOsc, endOfProject)
    --if check point is last line of pattern, this keeps it from failing
    lineDown = lineID + 1
    seqNext = seqID --patternID == start point pattern
    patternLength = renoise.song().patterns[patternID_from_sequenceID(seqID)].number_of_lines
    if lineDown > patternLength then
        lineDown = 1
        seqNext = seqID + 1
    end
    if beginningOfProject then
        lineDown = 1
        curStep = 0
        deviceString = deviceStringEnd
    end
    print("stepcounter",stepCounter, "lineid", lineID)
    while curStep <= stepCounter do --isLineEmpty(lineDown, columnID, renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID), subColumnID) do
        local stepValue = 0
        if endOfProject then
            stepValue = interpolate_with(waveFun, parameterStart, parameterEnd, curStep+1, stepCounter, numOsc)
        else
            stepValue = interpolate_with(waveFun, parameterStart, parameterEnd, curStep, stepCounter, numOsc)
        end
        --print("process curstep and stepcounter",curStep, stepCounter)
        local patternLength = renoise.song().patterns[patternID_from_sequenceID(seqNext)].number_of_lines
        local line = renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID):line(lineDown)
        if subColumnID == renoise.Song.SUB_COLUMN_VOLUME then
            if parameterStart <= 128 and parameterEnd <= 128 then
                line.note_columns[columnID].volume_value = stepValue
            end
        elseif subColumnID == renoise.Song.SUB_COLUMN_PANNING then
            if parameterStart <= 128 and parameterEnd <= 128 then
                line.note_columns[columnID].panning_value = stepValue
            end
        elseif subColumnID == renoise.Song.SUB_COLUMN_DELAY then
            line.note_columns[columnID].delay_value = stepValue
        else
            line.effect_columns[columnID].amount_value = stepValue
            line.effect_columns[columnID].number_string = deviceString
        end
        lineDown = lineDown + 1
        curStep = curStep + 1

        if lineDown == patternLength + 1 then
            seqNext = seqNext + 1
            lineDown = 1
        end
        if seqNext > seqCount then
            break
        end
    end

    -- Return the updated values
    return lineDown, seqNext, curStep
end

--get end and start parameters
function getParameterValues(seqID, seqNext, lineID, lineDown, trackID, columnID, beginningOfProject, endOfProject,
                            deviceString, deviceStringEnd, subColumnID)
    local parameterStart
    local parameterEnd
    --print("getvalues line id, seqid, and down, seqNext",lineID,seqID,lineDown, seqNext)
    local line = renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID)
    -- Get parameter start value based on conditions
    if not beginningOfProject then
        if subColumnID == renoise.Song.SUB_COLUMN_VOLUME then
            parameterStart = line.note_columns[columnID].volume_value
        elseif subColumnID == renoise.Song.SUB_COLUMN_PANNING then
            parameterStart = line.note_columns[columnID].panning_value
        elseif subColumnID == renoise.Song.SUB_COLUMN_DELAY then
            parameterStart = line.note_columns[columnID].delay_value
        else
            parameterStart = line.effect_columns[columnID].amount_value
        end
        line = renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID):line(lineDown)
    elseif beginningOfProject and isSample(deviceStringEnd) then
        parameterStart = 255 - line.effect_columns[columnID].amount_value
    elseif beginningOfProject and subColumnID == renoise.Song.SUB_COLUMN_VOLUME then
        parameterStart = 128 - line.note_columns[columnID].volume_value
    elseif beginningOfProject and subColumnID == renoise.Song.SUB_COLUMN_PANNING then
        parameterStart = 128 - line.note_columns[columnID].panning_value
    elseif beginningOfProject and subColumnID == renoise.Song.SUB_COLUMN_DELAY then
        parameterStart = 255 - line.note_columns[columnID].delay_value
    else
        parameterStart = parameterOldFunc(trackID, deviceStringEnd)
    end

    -- Get parameter end value based on conditions
    line = renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID):line(lineDown)
    if not endOfProject then
        if subColumnID == renoise.Song.SUB_COLUMN_VOLUME then
            parameterEnd = line.note_columns[columnID].volume_value
        elseif subColumnID == renoise.Song.SUB_COLUMN_PANNING then
            parameterEnd = line.note_columns[columnID].panning_value
        elseif subColumnID == renoise.Song.SUB_COLUMN_DELAY then
            parameterEnd = line.note_columns[columnID].delay_value
        else
            parameterEnd = line.effect_columns[columnID].amount_value
        end
        line = renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID)
    elseif endOfProject and isSample(deviceString) then
        parameterEnd = 255 - line.effect_columns[columnID].amount_value
    elseif endOfProject and subColumnID == renoise.Song.SUB_COLUMN_VOLUME then
        parameterEnd = 128 - line.note_columns[columnID].volume_value
    elseif endOfProject and subColumnID == renoise.Song.SUB_COLUMN_PANNING then
        parameterEnd = 128 - line.note_columns[columnID].panning_value
    elseif endOfProject and subColumnID == renoise.Song.SUB_COLUMN_DELAY then
        parameterEnd = 255 - line.note_columns[columnID].delay_value
    else
        parameterEnd = parameterOldFunc(trackID, deviceString)
    end
    -- Return the parameter values
    --print("parameter start and end", parameterStart, parameterEnd)
    return parameterStart, parameterEnd
end

--main function
local function InterpolateBeyond(waveFun)
    print("__interpolate__")
    local numOsc = renoise.song().transport.edit_step
    local track = renoise.song().selected_track
    local lineID = renoise.song().selected_line_index --variable for the first line
    local trackID = renoise.song().selected_track_index
    local patternID = renoise.song().selected_pattern_index
    local seqID = renoise.song().selected_sequence_index
    local columnID = renoise.song().selected_effect_column_index -- the effect column ID
    local subColumnID = renoise.song().selected_sub_column_type
    local noteColumnID = renoise.song().selected_note_column_index
    -- print("columnID_"..columnID, "subColumnID_"..subColumnID, "noteColumnID_"..noteColumnID)
    if columnID == 0 then --if the effect column isn't selected, columnID is now equal to the note column ID
        columnID = renoise.song().selected_note_column_index
    end
    local patternLength = renoise.song().patterns[patternID].number_of_lines
    local patternLengthPrev
    local seqCount = #renoise.song().sequencer.pattern_sequence
    local stepCounter = 0
    local curStep = 1
    local endOfProject = false
    local beginningOfProject = false
    local lineDown = lineID + 1
    local patternNext = patternID --patternID == start point pattern
    local seqNext = seqID
    --find next and previous points
    lineID, seqID, beginningOfProject, patternLengthPrev, patternLength, lineDown, seqNext = findPreviousPoint(lineID,
        columnID, seqID, trackID, beginningOfProject, patternLengthPrev, patternLength, lineDown, subColumnID)
    lineDown, seqNext, stepCounter, endOfProject = findNextModulationPoint(lineDown, columnID, seqNext, trackID, seqCount,
        subColumnID)

    local patTrack = renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID)
    local deviceString = patTrack:line(lineID).effect_columns[columnID].number_string
    local patTrackNext = renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID)
    local deviceStringEnd = patTrackNext:line(lineDown).effect_columns[columnID].number_string
    if subColumnID < 6 then
        deviceStringEnd = "00"
        deviceString = "00"
    end
    local parameterStart
    local parameterEnd

    --get beginning and end values
    parameterStart, parameterEnd = getParameterValues(seqID, seqNext, lineID, lineDown, trackID, columnID,
        beginningOfProject, endOfProject, deviceString, deviceStringEnd, subColumnID)

    if beginningOfProject and endOfProject then
    else
        --interpolate value at each point
        lineDown, seqNext, curStep = processModulationPoints(lineDown, columnID, seqNext, trackID, parameterStart,
            parameterEnd, stepCounter, curStep, deviceString, seqCount, beginningOfProject, patternLength, lineID, seqID,
            deviceStringEnd, waveFun, subColumnID, numOsc,endOfProject)
    end
end
-- call functions------------------ Menu entries and key bindings
local function addInteractions(name, waveFun)
    local fun = function()
        InterpolateBeyond(waveFun)
    end
    renoise.tool():add_menu_entry {
        name = "Pattern Editor:Interpolate Beyond:" .. name,
        invoke = fun
    }
    renoise.tool():add_keybinding {
        name = "Global:Tools:Interpolate Beyond " .. name,
        invoke = fun
    }
end

addInteractions("Linear", lin)
addInteractions("Logarithmic In", logIn)
addInteractions("Logarithmic Out", logOut)
addInteractions("Sin", sin)
addInteractions("Square", sqr)
addInteractions("Saw", saw)
addInteractions("Tri", tri)
addInteractions("Bounce Out", easeOutBounce)
addInteractions("Bounce In", easeInBounce)
addInteractions("Gradient Noise", GradientRan)
