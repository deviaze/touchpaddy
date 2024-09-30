--!nonstrict

local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local task = require("@lune/task")

local environment = require("@workspace/environment.luau")
local gestures = require("@src/gestures")

local events = {
    GESTURE_HOLD_BEGIN = true,
    GESTURE_HOLD_END = true,
    GESTURE_SWIPE_BEGIN = true,
    GESTURE_SWIPE_END = true,
    GESTURE_SWIPE_UPDATE = true,
    KEYBOARD_KEY = true,
    POINTER_BUTTON = true,
    POINTER_MOTION = true,
    POINTER_SCROLL_FINGER = true,
}

local Touchpaddy = {}

local handle = process.create(`libinput debug-events`, nil, { shell = true })

local WindowManager = require("@classes/window_manager.luau")

local executors = require("@libraries/exec_async.luau")

local Windows = require("kwin_runner.luau")
local TICK_TIME = 0.1 -- seconds u need to hold down a gesture for it to trigger action

type Delta = {
    x: number,
    y: number,
}

type Clocks = {
    GESTURE_SWIPE: {
        [number]: { -- key is number of fingers
            UpdateTime: number,
            CurrentDelta: Delta?,
            Ticks: number,
        },
    },
}

local clocks: Clocks = {
    GESTURE_SWIPE = {}
}

task.spawn(function()
    while true do
        local lines = handle.stdout:read(100)
        if not lines then break end
        lines = lines:split("\n")

        local text = lines[1]
            :gsub("[%s]+", " ")
            :gsub("event%d", "")

        for event in events do
            if not text:match(event) then continue end

            if event == "GESTURE_SWIPE_BEGIN" then
                local number_fingers = text:match("(%d)$")
                if number_fingers then
                    clocks.GESTURE_SWIPE[number_fingers] = {
                        UpdateTime = os.clock(),
                        Ticks = 0,
                    }
                end
            elseif event == "GESTURE_SWIPE_UPDATE" then
                local t, number_fingers, delta = text:match("GESTURE_SWIPE_UPDATE %+([%w%p]+)s (%d) ([%w%s%p]+) %(")
                if delta then
                    delta = delta:gsub(" ", "")
                    local delta_array = delta:split("/")
                    local x = tonumber(delta_array[1])
                    local y = tonumber(delta_array[2])
                    local current_swipe_data = clocks.GESTURE_SWIPE[number_fingers]
                    if current_swipe_data and x and y then
                        current_swipe_data.CurrentDelta = {
                            x = x,
                            y = y,
                        }
                        local now = os.clock()

                        local is_first_tick = if (now - current_swipe_data.UpdateTime < 0.025) and current_swipe_data.Ticks == 0 then true else false

                        local absolute_delta = math.max(math.abs(x), math.abs(y))

                        if is_first_tick or (now - current_swipe_data.UpdateTime > TICK_TIME) then
                            current_swipe_data.Ticks += 1
                            if number_fingers == "3" then
                                local id: string
                                if math.abs(x) > math.abs(y) and absolute_delta > 2 then
                                    if math.abs(x) > 4 then
                                        if #Windows.LastActiveWindows > 1 then
                                            local index = math.max(1, #Windows.LastActiveWindows - current_swipe_data.Ticks) -- make sure we don't get an outofbounds on the left
                                            id = Windows.LastActiveWindows[#Windows.LastActiveWindows - index]
                                            if not Windows:ActivateWindow(id) then
                                                Windows:ActivateWindow(id)
                                            end
                                        end
                                    end
                                else
                                    if y >= 10 then -- down at least ten
                                        for window_id in Windows.CurrentWindows do
                                            Windows:MinimizeWindow(window_id)
                                        end
                                    elseif y <= -10 then -- up 10
                                        Windows:ActivateWindow(Windows.LastActiveWindows[1])
                                    end
                                end
                            elseif number_fingers == "4" then
                                if Windows.ActiveWindowId ~= "" then
                                    if absolute_delta < 10 then
                                        Windows:MoveWindow(Windows.ActiveWindowId, {
                                            x = x * 12,
                                            y = y * 12,
                                        })
                                    else
                                        if math.abs(x) > math.abs(y) then
                                            Windows:SnapWindow(Windows.ActiveWindowId, if x > 0 then "Right" else "Left")
                                        else
                                            if y < -10 then
                                                Windows:MaximizeWindow(Windows.ActiveWindowId)
                                            elseif y > 10 then
                                                Windows:MinimizeWindow(Windows.ActiveWindowId)
                                            end
                                        end
                                        clocks.GESTURE_SWIPE[number_fingers] = nil
                                    end
                                end
                                -- if math.abs(x) > math.abs(y) then
                                    
                                -- end
                            end

                            current_swipe_data.UpdateTime = now
                        end
                    end
                end
                -- print(`time: {t}, fingers: {number_fingers}, delta: {delta}`)
            elseif event == "GESTURE_SWIPE_END" then
                local number_fingers = text:match("(%d)$")
                if number_fingers then
                    clocks.GESTURE_SWIPE[number_fingers] = nil
                end
            end

            break
        end
    end
end)

return Touchpaddy

-- task.delay(2, function()
--     handle:kill()
--     process.exit()
-- end)