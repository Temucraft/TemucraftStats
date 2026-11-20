-- Plain Lua 5.1 test for TemucraftStats with stubbed 3.3.5 stat functions.
local dir = arg[1]
local fails = 0
local function ok(cond, msg) if not cond then fails = fails + 1 print("FAIL " .. msg) else print("ok   " .. msg) end end

-- tiny frame stub: known methods do real work, everything else does nothing
local M = {}
local MT = { __index = function(t, k) return M[k] or function() end end }
local all = {}
local function New(otype, name, parent)
	local f = setmetatable({ otype = otype, scripts = {}, shown = true, parent = parent }, MT)
	if name then _G[name] = f end
	all[#all + 1] = f
	return f
end
function M:SetScript(k, fn) self.scripts[k] = fn end
function M:GetScript(k) return self.scripts[k] end
function M:HookScript(k, fn) local o = self.scripts[k] self.scripts[k] = function(...) if o then o(...) end fn(...) end end
function M:Show() local was = self.shown self.shown = true if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
function M:Hide() self.shown = false end
function M:IsShown() return self.shown end
function M:IsVisible() local f = self while f do if not rawget(f, "shown") then return false end f = rawget(f, "parent") end return true end
function M:SetText(t) self.text = t end
function M:GetText() return self.text end
function M:SetChecked(v) self.checked = v end
function M:GetChecked() return self.checked end
function M:SetHeight(h) self.h = h end
function M:SetScale(s) self.scale = s end
function M:SetValue(v) self.value = v end
function M:CreateFontString() return New("FontString", nil, self) end
function M:CreateTexture() return New("Texture", nil, self) end

function CreateFrame(t, name, parent, tmpl)
	local f = New(t, name, parent)
	if name and tmpl then for _, s in ipairs({ "Text", "Low", "High" }) do _G[name .. s] = New("FontString", nil, f) end end
	return f
end
UIParent = New("Frame", "UIParent")
CharacterFrame = New("Frame", "CharacterFrame", UIParent)
PaperDollFrame = New("Frame", "PaperDollFrame", CharacterFrame)
CharacterAttributesFrame = New("Frame", "CharacterAttributesFrame", PaperDollFrame)
GameTooltip = New("GameTooltip", "GameTooltip", UIParent)
local tipLines = {}
function GameTooltip:AddLine(t) tipLines[#tipLines + 1] = t end
function GameTooltip:SetOwner() tipLines = {} end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) end }
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function InterfaceOptions_AddCategory() end
function InterfaceOptionsFrame_OpenToCategory() end
MANA, ENERGY = "Mana", "Energy"

-- stat stubs: a level 80 character
local power = "MANA"
function UnitLevel() return 80 end
function UnitHealthMax() return 25000 end
function UnitPowerMax(_, t) if t == 0 then return power == "MANA" and 12000 or 0 end return power == "MANA" and 12000 or 100 end
function UnitPowerType() return power == "MANA" and 0 or 3, power end
local stats = { { 100, 150, 50, 0 }, { 80, 400, 320, 0 }, { 120, 1500, 1380, 0 }, { 60, 300, 260, -20 }, { 70, 200, 130, 0 } }
function UnitStat(_, i) return unpack(stats[i]) end
function UnitArmor() return 9000, 10000, 10000, 1000, 0 end
function UnitAttackPower() return 3000, 500, -100 end
function UnitRangedAttackPower() return 1000, 0, 0 end
function UnitDamage() return 800.4, 1200.2, 400.1, 600.9, 0, 0, 1 end
function UnitAttackSpeed() return 2.6, 1.8 end
local rangedSpeed = 0
function UnitRangedDamage() return rangedSpeed, 300, 400, 0, 0, 1 end
function GetCritChance() return 25.5 end
function GetRangedCritChance() return 10 end
local spellCrit = { [2] = 15, [3] = 14, [4] = 13.5, [5] = 14, [6] = 14, [7] = 14 }
function GetSpellCritChance(s) return spellCrit[s] end
local spellDmg = { [2] = 100, [3] = 900, [4] = 100, [5] = 800, [6] = 100, [7] = 100 }
function GetSpellBonusDamage(s) return spellDmg[s] end
function GetSpellBonusHealing() return 1100 end
local ratings = { [2] = 200, [3] = 40, [6] = 263, [8] = 100, [9] = 300, [15] = 400, [18] = 100, [24] = 64, [25] = 120 }
function GetCombatRating(id) return ratings[id] or 0 end
function GetCombatRatingBonus(id)
	local per = { [2] = 4.92, [6] = 32.79, [8] = 26.23, [9] = 45.91, [15] = 81.97, [18] = 32.79, [24] = 8.2, [3] = 45.25 }
	return per[id] and ratings[id] / per[id] or 0
end
function GetExpertise() return 18, 18 end
function GetExpertisePercent() return 4.5, 4.5 end
function GetArmorPenetration() return 8.6 end
function GetDodgeChance() return 12.34 end
function GetParryChance() return 10.1 end
function GetBlockChance() return 5 end
function GetShieldBlock() return 30 end
function UnitDefense() return 400, 40 end
function GetManaRegen() return 50, 20 end
function GetPowerRegen() return 10, 12 end
function UnitAffectingCombat() return false end
function GetSpellPenetration() return 35 end
local items = { [1] = { 200, "INVTYPE_HEAD" }, [16] = { 232, "INVTYPE_2HWEAPON" }, [18] = { 200, "INVTYPE_RANGED" } }
function GetInventoryItemLink(_, slot) return items[slot] and ("item:" .. slot) end
function GetItemInfo(link) local s = tonumber(link:match("%d+")) return "x", link, 4, items[s][1], 80, "", "", 1, items[s][2] end
-- no GetHitModifier / GetSpellHitModifier, like the 3.3.5 client

dofile(dir .. "/TemucraftStats.lua")
dofile(dir .. "/Options.lua")
local function Fire(e, ...) for _, f in ipairs(all) do if f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end end end
TemucraftStatsDB = { showRatings = false }
Fire("ADDON_LOADED", "TemucraftStats")
Fire("PLAYER_LOGIN")
local S = TemucraftStats
local db = S.GetDB()
ok(db.show == true and db.showRatings == false and type(db.collapsed) == "table", "saved variables merged")

local function Values()
	local v = {}
	for _, r in ipairs(S.Collect()) do v[r.section .. ":" .. r.label] = r end
	return v
end
local function strip(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local v = Values()
local function eq(key, want)
	local got = v[key] and strip(v[key].value)
	ok(got == want, key .. " = " .. tostring(got) .. (got == want and "" or " (want " .. want .. ")"))
end
eq("General:Health", "25000")
eq("General:Mana", "12000")
eq("General:Strength", "150")
eq("General:Intellect", "300")
ok(v["General:Intellect"].value:find("|cffff2020"), "debuffed stat shown red")
ok(v["General:Agility"].value:find("|cff20ff20"), "buffed stat shown green")
eq("General:Item level", ("%.1f"):format((200 + 232 + 232 + 200) / 17))
eq("Melee:Damage", "800 - 1201")
eq("Melee:Speed", "2.60 / 1.80")
eq("Melee:Attack power", "3400")
eq("Melee:Hit", "+8.02%")
eq("Melee:Crit", "25.50%")
eq("Melee:Expertise", "18")
eq("Melee:Armor pen.", "8.60%")
eq("Melee:Haste", "3.05%")
eq("Ranged:Damage", "-")
eq("Ranged:Speed", "-")
eq("Spell:Damage", "900")
eq("Spell:Healing", "1100")
eq("Spell:Hit", "+3.81%")
eq("Spell:Crit", "13.50%")
eq("Spell:Penetration", "35")
eq("Defense:Armor", "10000")
eq("Defense:Defense", "440")
eq("Defense:Dodge", "12.34%")
eq("Defense:Block value", "30")
eq("Defense:Resilience", "400")
eq("Regen:Mana (not casting)", "250")
eq("Regen:Mana (casting)", "100")
ok(v["Regen:Energy regen"] == nil, "no energy row for a mana user")

-- tooltips
local armorTip = table.concat(v["Defense:Armor"].tip, "\n")
local expected = 0.1 * 10000 / (8.5 * (80 + 4.5 * 21) + 40)
expected = expected / (1 + expected) * 100
ok(armorTip:find(("%.1f%%"):format(expected), 1, true), "armor tooltip has the damage reduction " .. ("%.1f"):format(expected))
ok(table.concat(v["Spell:Damage"].tip, "\n"):find("Fire: |cffffffff900"), "spell damage tooltip lists schools")
ok(table.concat(v["Defense:Defense"].tip, "\n"):find("Defense rating 200 %(%+40 defense%)"), "defense tooltip has the rating")
ok(table.concat(v["Defense:Resilience"].tip, "\n"):find("4.88%%"), "resilience tooltip has crit reduction")
ok(table.concat(v["Melee:Attack power"].tip, "\n"):find("242.9 damage per second"), "AP tooltip has DPS bonus")

-- ratings option
db.showRatings = true
v = Values()
eq("Melee:Hit", "+8.02% (263)")
eq("Melee:Expertise", "18 (64)")

-- ranged weapon and energy user
rangedSpeed = 2.8
power = "ENERGY"
v = Values()
eq("Ranged:Damage", "300 - 400")
eq("Ranged:Speed", "2.80")
eq("General:Energy", "100")
eq("Regen:Energy regen", "10.0/s")
ok(v["Regen:Mana (casting)"] == nil, "no mana rows without mana")

-- panel
TemucraftStatsFrame.scripts.OnShow(TemucraftStatsFrame)
local shownRows = 0
for _, sec in ipairs(S.SECTIONS) do for _, r in ipairs(sec.rows) do if r.frame.shown and r.frame.value.text then shownRows = shownRows + 1 end end end
ok(shownRows >= 35, "panel filled (" .. shownRows .. " rows)")
local hdr = S.SECTIONS[2].header
hdr.scripts.OnClick(hdr)
ok(db.collapsed.melee == true and not S.SECTIONS[2].rows[1].frame.shown, "clicking a header folds the section")
ok(hdr.text.text == "+ Melee", "folded header shows +")
hdr.scripts.OnClick(hdr)
ok(db.collapsed.melee == nil and S.SECTIONS[2].rows[1].frame.shown, "clicking again unfolds it")
local row = S.SECTIONS[1].rows[3].frame
row.scripts.OnEnter(row)
ok(tipLines[1] and tipLines[1]:find("Strength"), "row tooltip shown")

-- throttled update on events
local before = S.SECTIONS[1].rows[1].frame.value.text
UnitHealthMax = function() return 30000 end
Fire("UNIT_STATS", "target")
TemucraftStatsFrame.scripts.OnUpdate(TemucraftStatsFrame, 1)
ok(S.SECTIONS[1].rows[1].frame.value.text == before, "events for other units ignored")
Fire("UNIT_MAXHEALTH", "player")
TemucraftStatsFrame.scripts.OnUpdate(TemucraftStatsFrame, 1)
ok(S.SECTIONS[1].rows[1].frame.value.text == "30000", "player event updates the panel")
Fire("PLAYER_EQUIPMENT_CHANGED", 1, true)
TemucraftStatsFrame.scripts.OnUpdate(TemucraftStatsFrame, 1)

-- hide default stats option and slash
SlashCmdList.TEMUCRAFTSTATS("default")
ok(db.hideDefault and not CharacterAttributesFrame.shown, "/tstats default hides the default stat boxes")
CharacterAttributesFrame.shown = false
CharacterAttributesFrame:Show()
ok(not CharacterAttributesFrame.shown, "default stat boxes stay hidden when shown again")
SlashCmdList.TEMUCRAFTSTATS("default")
ok(not db.hideDefault and CharacterAttributesFrame.shown, "/tstats default shows them again")
SlashCmdList.TEMUCRAFTSTATS("")
ok(not db.show and not TemucraftStatsFrame.shown, "/tstats hides the panel")
SlashCmdList.TEMUCRAFTSTATS("toggle")
ok(db.show and TemucraftStatsFrame.shown, "/tstats toggle shows it")
SlashCmdList.TEMUCRAFTSTATS("print")
SlashCmdList.TEMUCRAFTSTATS("reset")
ok(db.showRatings == true and db.hideDefault == false, "/tstats reset")

-- options panel
TemucraftStatsOptions.scripts.OnShow(TemucraftStatsOptions)
ok(TStatsOptShow.checked == true, "options checkbox reflects settings")
TStatsOptDefault.checked = true
TStatsOptDefault.scripts.OnClick(TStatsOptDefault)
ok(db.hideDefault and not CharacterAttributesFrame.shown, "options checkbox hides default stats")
TStatsOptScale.scripts.OnValueChanged(TStatsOptScale, 1.23)
ok(db.scale == 1.25 and TemucraftStatsFrame.scale == 1.25, "scale slider")

print(fails == 0 and "ALL PASSED" or (fails .. " FAILED"))
os.exit(fails == 0 and 0 or 1)
