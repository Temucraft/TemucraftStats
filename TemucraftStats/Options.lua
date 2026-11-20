-- Options panel for Temucraft Stats (Interface > AddOns).

local panel

function TemucraftStats_CreateOptions()
	if panel then return end
	local S = TemucraftStats
	local db = S.GetDB()
	panel = CreateFrame("Frame", "TemucraftStatsOptions", UIParent)
	panel.name = "Temucraft Stats"

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Temucraft Stats")
	local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	sub:SetText("All your stats in one panel next to the character window. /tstats")

	local checks = {}
	local function Check(name, label, y, key, apply)
		local cb = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
		cb:SetPoint("TOPLEFT", 16, y)
		_G[name .. "Text"]:SetText(label)
		cb:SetScript("OnClick", function(self)
			db[key] = self:GetChecked() and true or false
			apply()
		end)
		cb.key = key
		checks[#checks + 1] = cb
	end
	Check("TStatsOptShow", "Show the stats panel with the character window", -60, "show", S.ApplyShown)
	Check("TStatsOptDefault", "Hide the default stat boxes and their dropdowns", -86, "hideDefault", S.ApplyHideDefault)
	Check("TStatsOptRatings", "Show the rating next to percent values", -112, "showRatings", S.MarkDirty)

	local slider = CreateFrame("Slider", "TStatsOptScale", panel, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", 24, -160)
	slider:SetWidth(200)
	slider:SetMinMaxValues(0.6, 1.5)
	slider:SetValueStep(0.05)
	_G["TStatsOptScaleLow"]:SetText("0.6")
	_G["TStatsOptScaleHigh"]:SetText("1.5")
	slider:SetScript("OnValueChanged", function(self, value)
		value = tonumber(value) or db.scale
		value = math.floor(value * 20 + 0.5) / 20
		_G["TStatsOptScaleText"]:SetText(("Scale: %.2f"):format(value))
		if not self.refreshing then
			db.scale = value
			S.ApplyShown()
		end
	end)

	local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", 16, -200)
	help:SetWidth(560)
	help:SetJustifyH("LEFT")
	help:SetText("Click a section title in the panel to fold it. Hover a value to see what it means. "
		.. "/tstats print writes every value to the chat.")

	panel:SetScript("OnShow", function()
		db = S.GetDB()
		for _, cb in ipairs(checks) do cb:SetChecked(db[cb.key]) end
		slider.refreshing = true
		slider:SetValue(db.scale or 1)
		_G["TStatsOptScaleText"]:SetText(("Scale: %.2f"):format(db.scale or 1))
		slider.refreshing = false
	end)
	InterfaceOptions_AddCategory(panel)
end

function TemucraftStats_OpenOptions()
	if not panel then TemucraftStats_CreateOptions() end
	InterfaceOptionsFrame_OpenToCategory(panel)
	InterfaceOptionsFrame_OpenToCategory(panel)
end
