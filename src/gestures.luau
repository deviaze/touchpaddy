--!strict

local task = require("@lune/task")

local Gestures = {}

local WindowManager = require("@classes/window_manager")
local Input = require("@classes/input_controller")

function Gestures.PointerScroll(delta: { x: number, y: number })
	local active_window_id: string? = WindowManager:GetActiveWindow()
	if active_window_id then
		local window_info = WindowManager:GetWindowInfo(active_window_id)
		if window_info and window_info.ClassName then
			local application_name: string = window_info.ClassName
			if application_name:match("firefox") or application_name:match("edge") or application_name:match("chrom") then
				if math.abs(delta.x) > math.abs(delta.y) then
					if delta.x < -6 then
						Input:SendKeys{"Alt", "Right"}
					elseif delta.x > 6 then
						Input:SendKeys{"Alt", "Left"}
					end
				end
			end
		end
	end
end

function Gestures.SwipeBegin(finger_count: number)
	
end

export type SwipeUpdateInfo = {
	FingerCount: number,
	SwipeDirection: "Up" | "Down" | "Left" | "Right",
	Delta: { x: number, y: number },
	Magnitude: number,
}

local last_window_snapped_time = 0

function Gestures.SwipeUpdate(update: SwipeUpdateInfo)
	if update.FingerCount == 3 then
		-- local window_id = WindowManager:GetActiveWindow()
		
		if update.Magnitude > 3 then
			if update.SwipeDirection == "Up" then
				WindowManager:ShowTaskView()
			elseif update.SwipeDirection == "Down" then
				if update.Magnitude > 13 then
					for window_id, _ in WindowManager.TrackedWindows do 
						task.spawn(function()
							WindowManager:MinimizeWindow(window_id)
						end)
					end
				else
					WindowManager:HideTaskView()
				end
			elseif update.SwipeDirection == "Left" then
				WindowManager:SwitchWindow("Left")
			elseif update.SwipeDirection == "Right" then
				WindowManager:SwitchWindow("Right")
			end
		end
	elseif update.FingerCount == 4 then
		if update.Magnitude > 3 then
			local window_id: string? = WindowManager:GetActiveWindow()
			if window_id and (os.clock() - last_window_snapped_time > 0.15) then
				if update.SwipeDirection == "Left" then
					WindowManager:SnapWindow(window_id, "Left")
				elseif update.SwipeDirection == "Right" then
					WindowManager:SnapWindow(window_id, "Right")
				elseif update.SwipeDirection == "Up" then
					WindowManager:MaximizeWindow(window_id)
				elseif update.SwipeDirection == "Down" then
					WindowManager:MinimizeWindow(window_id)
				end
				last_window_snapped_time = os.clock()
			end
		end
	end
end

function Gestures.SwipeEnd()
	
end

return Gestures