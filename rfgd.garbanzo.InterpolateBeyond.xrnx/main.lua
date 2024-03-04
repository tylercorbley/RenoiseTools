-- Placeholder for the dialog
local dialog = nil

-- Placeholder to expose the ViewBuilder outside the show_dialog() function
local vb = nil

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

local manifest = RenoiseScriptingTool()
local ok,err = manifest:load_from("manifest.xml")
local tool_name = manifest:property("Name").value
local tool_id = manifest:property("Id").value

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
    return nil  -- Pattern object not found
end

--finds pattern ID from sequence ID
function patternID_from_sequenceID(seqID)
    return findPatternIndex(pattern_from_sequence(seqID))
end

--   The total number of sequences in the song
function countSequences()
    local totalSequences = 0
    local sequenceIndex = 1
    
    -- Iterate over sequence indices until the end of the song
    while true do
        -- Get the sequence at the current index
        local sequence =  pattern_from_sequence(sequenceIndex)
        
        -- If the sequence is nil, we've reached the end of the song
        if not sequence then
            break
        end
        
        -- Increment the total number of sequences
        totalSequences = totalSequences + 1
        
        -- Move to the next sequence index
        sequenceIndex = sequenceIndex + 1
    end
    
    return totalSequences
end
-------------------UTILITY AND MATH--------------------------
--is line not empty checker function
  local function isLineEmpty(lineID, columnID, patTrack)
     local deviceString = patTrack:line(lineID).effect_columns[columnID].number_string
    -- Check if the line is not empty
        if deviceString ~= "00" then
          return false
        else
        return true
        end
    end
    
    --is sample command?
local function isSample(deviceString)
    local valuesToCheck = {"0A", "0U", "0D", "0G", "0V", "0I", "0O", "0T", "0C", "0S", "0B", "0E", "0N"}
    for _, value in ipairs(valuesToCheck) do
        if deviceString == value then
            return true
        end
    end
    return false  -- Return false only after checking all values
end

--interpolator lerp
local function interpolate(stepCounter, startValue, endValue, curStep)
        local interpolation =  (startValue) + ((curStep / stepCounter) * (endValue-startValue))
        if interpolation < 0 then
        interpolation = 0
        end
        return interpolation
end

--log interpolation
local function logarithmicInterpolation(currentStep, totalSteps, y0, y1)
    -- Calculate the interpolated value at the current step in log space
    if y0 == 0 then
    y0 = 0.1
    end
    if y1 == 0 then
    y1 = 0.1
    end
    -- Ensure y0 is smaller than y1
    if y0 > y1 then
        y0, y1 = y1, y0
         currentStep = totalSteps-currentStep
    end
    -- Calculate the interpolated value at the current step in log space
    local logInterpolatedValue = math.log(y0) * (1 - currentStep / totalSteps) + math.log(y1) * (currentStep / totalSteps)
    -- Exponentiate the result to obtain the final interpolated value
    local interpolatedValue = math.exp(logInterpolatedValue)
    if interpolatedValue > 255 then
    interpolatedValue = 255
    end
    return interpolatedValue
end
-----------Looking for patterns or lines or values--------------------
    --establish parameter value from device based on first value
local function parameterOldFunc(trackID,deviceString)
    local deviceID = 1
    local deviceStringSplit = 1
    local deviceParamID 
    local parameterOld =1
      if deviceString ~= "00" then
   deviceID = tonumber(string.sub(deviceString, 1, 1))+1 -- first part
   deviceStringSplit = deviceString:sub(2) -- second part
   if deviceStringSplit == "P" then --this stuff is for using the first track device with panning, width, and volume
   deviceParamID = renoise.song().tracks[trackID].prefx_panning
   elseif deviceStringSplit == "L" then
   deviceParamID = renoise.song().tracks[trackID].prefx_volume
   elseif deviceStringSplit == "W" then
   deviceParamID =  renoise.song().tracks[trackID].prefx_width
  else
   deviceParamID = renoise.song().tracks[trackID].devices[deviceID].parameters[tonumber(deviceStringSplit)]
   end
    parameterOld = math.floor((255 / (deviceParamID.value_max - deviceParamID.value_min)) * (deviceParamID.value - deviceParamID.value_min) + 0.5)     --gets the value of the parameter on the device currently
    return parameterOld
else
return nil
  end
end

--find previous point function
function findPreviousPoint(lineID, columnID, seqID, trackID, beginningOfProject, patternLengthPrev, patternLength, lineDown)
    while isLineEmpty(lineID, columnID, renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID)) do
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
function findNextModulationPoint(lineDown, columnID, seqNext, trackID,seqCount)
    local stepCounter = 0
    local endOfProject = false

    while isLineEmpty(lineDown, columnID, renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID)) do
        lineDown = lineDown + 1
        stepCounter = stepCounter + 1
        local patternLength = renoise.song().patterns[patternID_from_sequenceID(seqNext)].number_of_lines
--print(stepCounter, isLineEmpty(lineDown, columnID, renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID)),"lineDown"..lineDown,"seqNext"..seqNext)
        if lineDown == patternLength + 1 then
            seqNext = seqNext + 1
            lineDown = 1
        end

        if seqNext > seqCount then
            seqNext = seqNext - 1
            endOfProject = true
            print("End of project")
            stepCounter = stepCounter - 1
            break
        end
    end        
    -- Return the updated values
    return lineDown, seqNext, stepCounter, endOfProject
end

--prints to renoise
function processModulationPoints(lineDown, columnID, seqNext, trackID, parameterStart, parameterEnd, stepCounter, curStep, deviceString, seqCount,beginningOfProject,patternLength,lineID,seqID,deviceStringEnd,other)
                     --if check point is last line of pattern, this keeps it from failing
            lineDown = lineID+1
            seqNext = seqID --patternID == start point pattern
            patternLength = renoise.song().patterns[patternID_from_sequenceID(seqID)].number_of_lines
      if lineDown > patternLength then
      lineDown = 1
      seqNext = seqID+1
      end
          if beginningOfProject then
      lineDown = 1
      curStep = 0
     -- stepCounter = stepCounter-1
      deviceString =deviceStringEnd
      end
    while isLineEmpty(lineDown, columnID, renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID)) do

        local stepValue
        if other == "log" then
        stepValue = logarithmicInterpolation(curStep, stepCounter,parameterStart, parameterEnd)
        else
        stepValue = interpolate(stepCounter, parameterStart, parameterEnd, curStep)
        end
        local patternLength = renoise.song().patterns[patternID_from_sequenceID(seqNext)].number_of_lines
        renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID):line(lineDown).effect_columns[columnID].amount_value = stepValue
        renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID):line(lineDown).effect_columns[columnID].number_string = deviceString

        lineDown = lineDown + 1
        curStep = curStep + 1

        if lineDown == patternLength + 1 then
            seqNext = seqNext + 1
            lineDown = 1
        end
--               print(isLineEmpty(lineDown, columnID, renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID)),"lineDown"..lineDown,"seqNext"..seqNext,patternID_from_sequenceID(seqNext))

        if seqNext > seqCount then
            break
        end
    end

    -- Return the updated values
    return lineDown, seqNext, curStep
end

--get end and start parameters
function getParameterValues(seqID, seqNext, lineID, lineDown, trackID, columnID, beginningOfProject, endOfProject, deviceString, deviceStringEnd)
    local parameterStart
    local parameterEnd
    -- Get parameter start value based on conditions
    if not beginningOfProject then
        parameterStart = renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID).effect_columns[columnID].amount_value
    elseif beginningOfProject and isSample(deviceString) then
        parameterStart = 255-renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID).effect_columns[columnID].amount_value
    else
        parameterStart = parameterOldFunc(trackID, deviceStringEnd)
    end

    -- Get parameter end value based on conditions
    if not endOfProject then
        parameterEnd = renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID):line(lineDown).effect_columns[columnID].amount_value
    elseif endOfProject and isSample(deviceString) then
        parameterEnd = 255-renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID):line(lineID).effect_columns[columnID].amount_value
    else
        parameterEnd = parameterOldFunc(trackID, deviceString)
    end
    -- Return the parameter values
    return parameterStart, parameterEnd
end

--main function
local function InterpolateBeyond(other)
    print("____INTERPOLATE___")
    local track = renoise.song().selected_track
    local lineID = renoise.song().selected_line_index--variable for the first line
    local trackID = renoise.song().selected_track_index
    local patternID = renoise.song().selected_pattern_index
    local seqID = renoise.song().selected_sequence_index
    local patternObjFromSeq = pattern_from_sequence(seqID)
    local columnID = renoise.song().selected_effect_column_index
    if columnID == 0 then --only runs if run on an effect column
    columnID = columnID+1
    end
    local patternLength = renoise.song().patterns[patternID].number_of_lines
    local patternLengthPrev
    local seqCount= countSequences()
    local stepCounter = 0
    local curStep = 1
    local endOfProject = false
    local beginningOfProject = false
    local lineDown = lineID+1
    local patternNext = patternID --patternID == start point pattern
    local seqNext = seqID
    --find next and previous points
lineID, seqID, beginningOfProject, patternLengthPrev, patternLength, lineDown, seqNext = findPreviousPoint(lineID, columnID, seqID, trackID, beginningOfProject, patternLengthPrev, patternLength, lineDown)
lineDown, seqNext, stepCounter, endOfProject = findNextModulationPoint(lineDown, columnID, seqNext, trackID, seqCount)

    local patTrack = renoise.song().patterns[patternID_from_sequenceID(seqID)]:track(trackID)
    local deviceString = patTrack:line(lineID).effect_columns[columnID].number_string
    local patTrackNext =renoise.song().patterns[patternID_from_sequenceID(seqNext)]:track(trackID)
    local deviceStringEnd = patTrackNext:line(lineDown).effect_columns[columnID].number_string
    local parameterStart 
    local parameterEnd
    
        --get beginning and end values
parameterStart, parameterEnd = getParameterValues(seqID, seqNext, lineID, lineDown, trackID, columnID, beginningOfProject, endOfProject, deviceString, deviceStringEnd)

     if beginningOfProject and endOfProject then
  else
    --interpolate value at each point
  lineDown,seqNext, curStep = processModulationPoints(lineDown, columnID, seqNext, trackID, parameterStart, parameterEnd, stepCounter, curStep, deviceString, seqCount,beginningOfProject,patternLength,lineID,seqID,deviceStringEnd,other)
  end
end

local function InterpolateBeyondLog()
    print("____INTERPOLATE LOG___")
    InterpolateBeyond("log")
end
--------------------------------------------------------------------------------
-- Menu entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry {
  name = "Pattern Editor:Interpolate Beyond:Linear",
  invoke = InterpolateBeyond
}
renoise.tool():add_menu_entry {
  name = "Pattern Editor:Interpolate Beyond:Logarithmic",
  invoke = InterpolateBeyondLog
}


--------------------------------------------------------------------------------
-- Key Binding
--------------------------------------------------------------------------------


renoise.tool():add_keybinding {
  name = "Global:Tools:Interpolate Beyond Linear",
  invoke = InterpolateBeyond
}

renoise.tool():add_keybinding {
  name = "Global:Tools:Interpolate Beyond Logarithmic",
  invoke = InterpolateBeyondLog
}
