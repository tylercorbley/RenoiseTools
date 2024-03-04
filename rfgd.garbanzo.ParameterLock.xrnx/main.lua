--[[============================================================================
main.lua
============================================================================]]--

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
-- Main functions
--------------------------------------------------------------------------------
--is line not empty checker function
  local function isLineEmpty(lineID, columnID, patTrack)
    --local patTrack = renoise.song().selected_pattern_track
     local deviceString = patTrack:line(lineID).effect_columns[columnID].number_string
    -- Check if the line is not empty
        if deviceString ~= "00" then
          return false
        else
        return true
        end
    end

    --establish parameter value from device based on first value
local function parameterOldFunc(trackID,deviceString)
    local deviceID = 1
    local deviceStringSplit = 1
    local deviceParamID 
    local parameterOld =1
    print(deviceString)
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

local function isSample(deviceString)
    local valuesToCheck = {"0A", "0U", "0D", "0G", "0V", "0I", "0O", "0T", "0C", "0S", "0B", "0E", "0N"}
    for _, value in ipairs(valuesToCheck) do
        if deviceString == value then
            return true
        end
    end
    return false  -- Return false only after checking all values
end


--to next line OR editStep length
local function ParameterLockShort()
    print("____SHORT___")
    local trackID = renoise.song().selected_track_index
    local patternID = renoise.song().selected_pattern_index
    local patTrack = renoise.song().patterns[patternID]:track(trackID)
    local parameterID = renoise.song().selected_automation_parameter
    local columnID = renoise.song().selected_effect_column_index
    local lineID = renoise.song().selected_line_index
      if columnID ~= 0 then 
    local lineID = renoise.song().selected_line_index
    local editStep = renoise.song().transport.edit_step
    if editStep == 0 then
    editStep = 1
    end
    local lineDown = lineID + editStep
    local lineUp = lineID - 1
    local deviceString = patTrack:line(lineID).effect_columns[columnID].number_string
        local isSample = isSample(deviceString)
        if isSample == false then
    local parameterOld = parameterOldFunc(trackID,deviceString)
    local track = renoise.song().selected_track
    local effect = patTrack:line(lineDown).effect_columns[columnID]
    local pattern = renoise.song().selected_pattern
    local patternLength = pattern.number_of_lines
    local parameter = renoise.song().selected_parameter 

    if parameterOld ~= nil then
    --up
    if lineUp >= 1 then
        if isLineEmpty(lineUp, columnID, patTrack) then
            patTrack:line(lineUp).effect_columns[columnID].amount_value = parameterOld
            patTrack:line(lineUp).effect_columns[columnID].number_string = deviceString
        end
    else
        if patternID - 1 ~= 0 then
            local patTrack3 = renoise.song().patterns[patternID - 1]:track(trackID)
            if isLineEmpty(patternLength, columnID, patTrack3) then
                patTrack3:line(renoise.song().patterns[patternID-1].number_of_lines).effect_columns[columnID].amount_value = parameterOld
                patTrack3:line(renoise.song().patterns[patternID-1].number_of_lines).effect_columns[columnID].number_string = deviceString
            end
        end
    end

    --down
    local editStep2 = editStep - (patternLength - lineID)
    if lineDown <= patternLength then
        if isLineEmpty(lineDown, columnID, patTrack) then
            patTrack:line(lineDown).effect_columns[columnID].amount_value = parameterOld
            patTrack:line(lineDown).effect_columns[columnID].number_string = deviceString
        end
    else
        local patTrack2 = renoise.song().patterns[patternID + 1]:track(trackID)
        if isLineEmpty(lineDown, columnID, patTrack2) then
            patTrack2:line(editStep2).effect_columns[columnID].amount_value = parameterOld
            patTrack2:line(editStep2).effect_columns[columnID].number_string = deviceString
        end
    end
end
end
end
end


 --To next Note Step    
local function ParameterLockLong()
    print("___LONG___")
     local trackID = renoise.song().selected_track_index
     local patternID = renoise.song().selected_pattern_index
     local patTrack = renoise.song().patterns[patternID]:track(trackID)
     local parameterID = renoise.song().selected_automation_parameter
     local columnID = renoise.song().selected_effect_column_index
           if columnID ~= 0 then
     local lineID = renoise.song().selected_line_index
     local lineUp = lineID - 1
    local lineDown = lineID + 1
     local deviceString = patTrack:line(lineID).effect_columns[columnID].number_string
             local isSample = isSample(deviceString)
        if isSample == false then
    local parameterOld = parameterOldFunc(trackID,deviceString)
  local lineUp = lineID - 1
  local track = renoise.song().selected_track
  local pattern = renoise.song().selected_pattern
  local effect = patTrack:line(lineDown).effect_columns[columnID]
  local patternLength = pattern.number_of_lines
  local parameter = renoise.song().selected_parameter 
  

if parameterOld ~= nil then
    if lineUp >= 1 then
        if isLineEmpty(lineUp, columnID, patTrack) then
            patTrack:line(lineUp).effect_columns[columnID].amount_value = parameterOld
            patTrack:line(lineUp).effect_columns[columnID].number_string = deviceString
        end
        else 
         if patternID - 1 ~= 0 then
            local patTrack3 = renoise.song().patterns[patternID - 1]:track(trackID)
             if isLineEmpty(patternLength, columnID, patTrack3) then
            patTrack3:line(renoise.song().patterns[patternID-1].number_of_lines).effect_columns[columnID].amount_value = parameterOld
            patTrack3:line(renoise.song().patterns[patternID-1].number_of_lines).effect_columns[columnID].number_string = deviceString
        end
        end
    end

    while (renoise.song().patterns[patternID].tracks[trackID].lines[lineDown].note_columns[1].note_value == 121) and lineDown <= patternLength-1 do
        lineDown = lineDown + 1
    end

    if lineDown <= patternLength then
      if lineDown == patternLength then
        if isLineEmpty(lineDown, columnID, patTrack) then
        local patTrack3 = renoise.song().patterns[patternID + 1]:track(trackID)
            patTrack3:line(1).effect_columns[columnID].amount_value = parameterOld
            patTrack3:line(1).effect_columns[columnID].number_string = deviceString
        end
      else
        if isLineEmpty(lineDown, columnID, patTrack) then
            patTrack:line(lineDown).effect_columns[columnID].amount_value = parameterOld
            patTrack:line(lineDown).effect_columns[columnID].number_string = deviceString
        end
        end
    end
end
end
end
end
--------------------------------------------------------------------------------
-- Menu entries
--------------------------------------------------------------------------------
renoise.tool():add_menu_entry {
  name = "Pattern Editor:Parameter Lock:Short",
  invoke = ParameterLockShort
}
renoise.tool():add_menu_entry {
  name = "Pattern Editor:Parameter Lock:Long",
  invoke = ParameterLockLong
}

--------------------------------------------------------------------------------
-- Key Binding
--------------------------------------------------------------------------------


renoise.tool():add_keybinding {
  name = "Global:Tools:" .. tool_name.."Short",
  invoke = ParameterLockShort
}

renoise.tool():add_keybinding {
  name = "Global:Tools:" .. tool_name.."Long",
  invoke = ParameterLockLong
}

