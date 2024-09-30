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
WindowManager:Listen()

local executors = require("@libraries/exec_async.luau")

-- local Windows = require("kwin_runner.luau")
local TICK_TIME = 0.1 -- how often gestures update 

type Delta = {
	x: number,
	y: number,
}

type Clocks = {
	GESTURE_SWIPE: {
		[string]: { -- key is number of fingers
			UpdateTime: number,
			CurrentDelta: Delta?,
			Ticks: number,
		},
	},
	POINTER_SCROLL_FINGER: {
		UpdateTime: number,
		Ticks: number,
	}?
}

local clocks: Clocks = {
	GESTURE_SWIPE = {},
	POINTER_SCROLL_FINGER = nil,
}

if environment.PlatformType.OS == "Linux" then
	task.spawn(function()
		while true do
			local lines = handle.stdout:read(100)
			if not lines then
				break
			end
			lines = lines:split("\n")
	
			local text = lines[1]:gsub("[%s]+", " "):gsub("event%d", "")
	
			for event in events do
				if not text:match(event) then
					continue
				end
	
				if event == "GESTURE_SWIPE_BEGIN" then
					local finger_count_string = text:match("(%d)$")
					if finger_count_string then
						clocks.GESTURE_SWIPE[finger_count_string] = {
							UpdateTime = os.clock(),
							Ticks = 0,
						}
						local finger_count = tonumber(finger_count_string)
						if finger_count and gestures.SwipeBegin then
							gestures.SwipeBegin(finger_count)
						end
					end
				elseif event == "GESTURE_SWIPE_UPDATE" then
					local t, finger_count_string, delta = text:match("GESTURE_SWIPE_UPDATE %+([%w%p]+)s (%d) ([%w%s%p]+) %(")
					if delta then
						delta = delta:gsub(" ", "")
						local delta_array = delta:split("/")
						local x = tonumber(delta_array[1])
						local y = tonumber(delta_array[2])
						local current_swipe_data = clocks.GESTURE_SWIPE[finger_count_string]
						if current_swipe_data and x and y then
							current_swipe_data.CurrentDelta = {
								x = x,
								y = y,
							}
							local now = os.clock()
	
							local is_first_tick = if (now - current_swipe_data.UpdateTime < 0.025) and current_swipe_data.Ticks == 0 then true else false
	
							if is_first_tick or (now - current_swipe_data.UpdateTime > TICK_TIME) then
								current_swipe_data.Ticks += 1
	
								local finger_count: number? = tonumber(finger_count_string)
								if gestures.SwipeUpdate and finger_count then
									local swipe_direction =
										if math.abs(x) > math.abs(y) then
											if x < 0 then "Left"
											else "Right"
										else
											if y < 0 then "Up"
											else "Down"
									
									local swipe_update_info: gestures.SwipeUpdateInfo = {
										FingerCount = finger_count,
										SwipeDirection = swipe_direction,
										Delta = delta,
										Magnitude = if swipe_direction == "Up" or swipe_direction == "Down" 
											then math.abs(y)
											else math.abs(x)
									}
									gestures.SwipeUpdate(swipe_update_info)
								end

								current_swipe_data.UpdateTime = now
							end
						end
					end
				elseif event == "GESTURE_SWIPE_END" then
					local finger_count_string = text:match("(%d)$")
					if finger_count_string then
						clocks.GESTURE_SWIPE[finger_count_string] = nil
						local finger_count: number? = tonumber(finger_count_string)
						if gestures.SwipeEnd and finger_count then
							gestures.SwipeEnd(finger_count)
						end
					end
				elseif event == "POINTER_SCROLL_FINGER" then
					local vert, horiz = text:match("vert ([%-%d%.]+)/[%-%d%.]+[%*]* horiz ([%-%d%.]+)/[%-%d%.]+[%*]*")
					local delta = {
						x = tonumber(horiz) :: number,
						y = tonumber(vert) :: number,
					}

					local now = os.clock()
					if not clocks.POINTER_SCROLL_FINGER then
						clocks.POINTER_SCROLL_FINGER = {
							UpdateTime = now,
							Ticks = 0,
						}
					end

					local pointer_clocks = clocks.POINTER_SCROLL_FINGER
					
					if now == pointer_clocks.UpdateTime or (now - pointer_clocks.UpdateTime) > TICK_TIME/2 then
						if gestures.PointerScroll then
							gestures.PointerScroll(delta)
						end
					end

					clocks.POINTER_SCROLL_FINGER.UpdateTime = now

				end
	
				break
			end
		end
	end)
end


return Touchpaddy