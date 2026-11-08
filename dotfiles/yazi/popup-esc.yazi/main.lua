--- @sync entry

-- Popup only (Mod+e sets YAZI_POPUP): Esc still cancels first, and quits once nothing is left to cancel
local function entry()
	local tab = cx.active
	local busy = tab.finder
		or not tab.mode.is_normal
		or tab.current.files.filter
		or #tab.selected > 0
		or tab.current.cwd.spec.is_search
	ya.emit((busy or not os.getenv("YAZI_POPUP")) and "escape" or "quit", {})
end

return { entry = entry }
