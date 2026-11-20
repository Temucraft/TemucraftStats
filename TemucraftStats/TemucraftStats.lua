-- Temucraft Stats
-- A panel next to the character frame that shows all your stats at once, for the 3.3.5 client.
-- Our own code, MIT licence.

local ADDON = "TemucraftStats"
local TITLE = "|cffffcc00Temucraft|r Stats"

local DEFAULTS = {
	show = true,          -- show the panel with the character frame
	hideDefault = false,  -- hide the default stat boxes and their dropdowns
	showRatings = true,   -- show the rating next to percent values
	scale = 1,
	collapsed = {},       -- [sectionKey] = true
}

local db
local S = {}             -- stat helpers, also used by the tests
TemucraftStats = S

local function CR(name, fallback) return _G[name] or fallback end
local CR_DEFENSE = function() return CR("CR_DEFENSE_SKILL", 2) end
local CR_IDS = {
	DODGE = 3, PARRY = 4, BLOCK = 5, HIT_MELEE = 6, HIT_RANGED = 7, HIT_SPELL = 8,
	CRIT_MELEE = 9, CRIT_RANGED = 10, CRIT_SPELL = 11, CRIT_TAKEN_MELEE = 15,
	CRIT_TAKEN_RANGED = 16, CRIT_TAKEN_SPELL = 17, HASTE_MELEE = 18, HASTE_RANGED = 19,
	HASTE_SPELL = 20, EXPERTISE = 24, ARMOR_PENETRATION = 25,
}
local function cr(key) return CR("CR_" .. key, CR_IDS[key]) end

local GREEN, RED, GREY, WHITE = "|cff20ff20", "|cffff2020", "|cff999999", "|cffffffff"
local SCHOOLS = { { 2, "Holy" }, { 3, "Fire" }, { 4, "Nature" }, { 5, "Frost" }, { 6, "Shadow" }, { 7, "Arcane" } }
local STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
local STAT_TIPS = {
	"Raises melee attack power and the amount a shield blocks.",
	"Raises critical strike chance, armor and dodge chance. Raises attack power for some classes.",
	"Raises health: 10 health for each point after the first 20.",
	"Raises mana (15 mana for each point after the first 20) and spell critical strike chance.",
	"Raises health and mana regeneration out of combat.",
}

local function P(x) return ("%.2f%%"):format(x or 0) end
local function Num(x) return tostring(math.floor((x or 0) + 0.5)) end

function S.Rating(key)
	local id = cr(key)
	return (GetCombatRating(id) or 0), (GetCombatRatingBonus(id) or 0)
end

-- percent text, with the rating in grey after it when the option is on
local function WithRating(text, rating)
	if db and db.showRatings and rating and rating > 0 then
		return text .. " " .. GREY .. "(" .. rating .. ")|r"
	end
	return text
end

local function BuffColor(text, pos, neg)
	if neg and neg < 0 then return RED .. text .. "|r" end
	if pos and pos > 0 then return GREEN .. text .. "|r" end
	return text
end

local function BuffLine(base, pos, neg)
	local s = "Base " .. Num(base)
	if pos and pos > 0 then s = s .. GREEN .. " +" .. Num(pos) .. "|r" end
	if neg and neg < 0 then s = s .. RED .. " " .. Num(neg) .. "|r" end
	return s
end

-- 3.3.5 does not have these two, newer clients do
local function HitMod() return (GetHitModifier and GetHitModifier()) or 0 end
local function SpellHitMod() return (GetSpellHitModifier and GetSpellHitModifier()) or 0 end

function S.ArmorReduction(armor, level)
	local l = level
	if l > 59 then l = l + 4.5 * (l - 59) end
	local t = 0.1 * armor / (8.5 * l + 40)
	t = t / (1 + t)
	return math.max(0, math.min(0.75, t)) * 100
end

function S.HasRanged()
	local speed = UnitRangedDamage("player")
	return speed and speed > 0
end

function S.AverageItemLevel()
	local total, count = 0, 0
	local mainIs2H = false
	for slot = 1, 18 do
		if slot ~= 4 then -- shirt
			local link = GetInventoryItemLink("player", slot)
			if link then
				local _, _, _, ilvl, _, _, _, _, equipLoc = GetItemInfo(link)
				if ilvl then
					total = total + ilvl
					if slot == 16 and equipLoc == "INVTYPE_2HWEAPON" then mainIs2H = ilvl end
				end
			end
		end
	end
	-- a two-hand weapon with nothing in the off hand counts for both hands
	if mainIs2H and not GetInventoryItemLink("player", 17) then total = total + mainIs2H end
	count = 17
	return total / count
end

------------------------------------------------------------------------
-- Row definitions. Each get() returns the value text and the tooltip lines (first line is the title).
------------------------------------------------------------------------
local function StatRow(i)
	return {
		label = STAT_NAMES[i],
		get = function()
			local base, stat, pos, neg = UnitStat("player", i)
			return BuffColor(Num(stat), pos, neg), { STAT_NAMES[i] .. " " .. Num(stat), BuffLine(base, pos, neg), STAT_TIPS[i] }
		end,
	}
end

local function PowerToken()
	local _, token = UnitPowerType("player")
	return token or "MANA"
end

local SECTIONS = {
	{ key = "general", title = "General", rows = {
		{ label = "Health", get = function()
			local v = UnitHealthMax("player") or 0
			return Num(v), { "Health " .. Num(v), "Your most health." }
		end },
		{ label = "Power", labelFn = function()
			local t = PowerToken()
			local name = _G[t] or t
			return name:sub(1, 1):upper() .. name:sub(2):lower()
		end, get = function()
			local v = UnitPowerMax("player") or 0
			return Num(v), { "Most " .. ((_G[PowerToken()] or PowerToken()):lower()) .. " " .. Num(v) }
		end },
		StatRow(1), StatRow(2), StatRow(3), StatRow(4), StatRow(5),
		{ label = "Item level", get = function()
			local v = S.AverageItemLevel()
			return ("%.1f"):format(v), { "Average item level " .. ("%.1f"):format(v),
				"Average of your equipped items over 17 slots (shirt and tabard not counted). A two-hand weapon counts for both hands." }
		end },
	} },
	{ key = "melee", title = "Melee", rows = {
		{ label = "Damage", get = function()
			local lo, hi, olo, ohi = UnitDamage("player")
			local ms, ospeed = UnitAttackSpeed("player")
			lo, hi = math.max(math.floor(lo or 0), 1), math.max(math.ceil(hi or 0), 1)
			local tip = { "Main hand damage " .. lo .. " - " .. hi }
			if ms and ms > 0 then tip[#tip + 1] = ("Speed %.2f, %.1f damage per second"):format(ms, (lo + hi) / 2 / ms) end
			if ospeed and ospeed > 0 and ohi and ohi > 0 then
				local a, b = math.max(math.floor(olo or 0), 1), math.max(math.ceil(ohi), 1)
				tip[#tip + 1] = ("Off hand %d - %d, speed %.2f, %.1f damage per second"):format(a, b, ospeed, (a + b) / 2 / ospeed)
			end
			return lo .. " - " .. hi, tip
		end },
		{ label = "Speed", get = function()
			local ms, ospeed = UnitAttackSpeed("player")
			local r, b = S.Rating("HASTE_MELEE")
			local text = ("%.2f"):format(ms or 0)
			if ospeed and ospeed > 0 then text = text .. " / " .. ("%.2f"):format(ospeed) end
			return text, { "Attack speed " .. text, "Seconds between swings (main hand / off hand).",
				("Haste rating %d (%s faster)"):format(r, P(b)) }
		end },
		{ label = "Attack power", get = function()
			local base, pos, neg = UnitAttackPower("player")
			local ap = (base or 0) + (pos or 0) + (neg or 0)
			return BuffColor(Num(ap), pos, neg), { "Melee attack power " .. Num(ap), BuffLine(base, pos, neg),
				("Adds %.1f damage per second to melee attacks."):format(math.max(ap, 0) / 14) }
		end },
		{ label = "Hit", get = function()
			local r, b = S.Rating("HIT_MELEE")
			local total = b + HitMod()
			return WithRating("+" .. P(total), r), { "Melee hit +" .. P(total),
				("Hit rating %d gives +%s chance to hit."):format(r, P(b)),
				"About 8% is needed to never miss a boss with one weapon. Dual wield misses much more often." }
		end },
		{ label = "Crit", get = function()
			local c = GetCritChance() or 0
			local r, b = S.Rating("CRIT_MELEE")
			return WithRating(P(c), r), { "Melee critical strike " .. P(c), ("Crit rating %d gives +%s."):format(r, P(b)) }
		end },
		{ label = "Expertise", get = function()
			local e, oe = GetExpertise()
			local pe
			if GetExpertisePercent then pe = GetExpertisePercent() end
			local r, b = S.Rating("EXPERTISE")
			local text = Num(e)
			if oe and oe > 0 and oe ~= e then text = text .. " / " .. Num(oe) end
			return WithRating(text, r), { "Expertise " .. text,
				("Your attacks are dodged and parried %s less often."):format(P(pe or (e or 0) * 0.25)),
				("Expertise rating %d (+%d expertise)"):format(r, math.floor(b)) }
		end },
		{ label = "Armor pen.", get = function()
			local r = S.Rating("ARMOR_PENETRATION")
			local p = (GetArmorPenetration and GetArmorPenetration()) or 0
			return WithRating(P(p), r), { "Armor penetration " .. P(p),
				("Armor penetration rating %d. Your attacks ignore this much of the target's armor."):format(r) }
		end },
		{ label = "Haste", get = function()
			local r, b = S.Rating("HASTE_MELEE")
			return WithRating(P(b), r), { "Melee haste " .. P(b), ("Haste rating %d. Buffs and talents are not in this number, they show in Speed."):format(r) }
		end },
	} },
	{ key = "ranged", title = "Ranged", rows = {
		{ label = "Damage", get = function()
			if not S.HasRanged() then return "-", { "Ranged damage", "No ranged weapon." } end
			local speed, lo, hi = UnitRangedDamage("player")
			lo, hi = math.max(math.floor(lo or 0), 1), math.max(math.ceil(hi or 0), 1)
			return lo .. " - " .. hi, { "Ranged damage " .. lo .. " - " .. hi,
				("Speed %.2f, %.1f damage per second"):format(speed, (lo + hi) / 2 / speed) }
		end },
		{ label = "Speed", get = function()
			if not S.HasRanged() then return "-", { "Ranged speed", "No ranged weapon." } end
			local speed = UnitRangedDamage("player")
			return ("%.2f"):format(speed), { ("Ranged speed %.2f"):format(speed), "Seconds between shots." }
		end },
		{ label = "Attack power", get = function()
			local base, pos, neg = UnitRangedAttackPower("player")
			local ap = (base or 0) + (pos or 0) + (neg or 0)
			return BuffColor(Num(ap), pos, neg), { "Ranged attack power " .. Num(ap), BuffLine(base, pos, neg),
				("Adds %.1f damage per second to ranged attacks (not wands)."):format(math.max(ap, 0) / 14) }
		end },
		{ label = "Hit", get = function()
			local r, b = S.Rating("HIT_RANGED")
			local total = b + HitMod()
			return WithRating("+" .. P(total), r), { "Ranged hit +" .. P(total), ("Hit rating %d gives +%s chance to hit."):format(r, P(b)) }
		end },
		{ label = "Crit", get = function()
			local c = GetRangedCritChance() or 0
			local r, b = S.Rating("CRIT_RANGED")
			return WithRating(P(c), r), { "Ranged critical strike " .. P(c), ("Crit rating %d gives +%s."):format(r, P(b)) }
		end },
		{ label = "Haste", get = function()
			local r, b = S.Rating("HASTE_RANGED")
			return WithRating(P(b), r), { "Ranged haste " .. P(b), ("Haste rating %d"):format(r) }
		end },
	} },
	{ key = "spell", title = "Spell", rows = {
		{ label = "Damage", get = function()
			local best, tip = 0, { "Bonus spell damage" }
			for _, s in ipairs(SCHOOLS) do
				local v = GetSpellBonusDamage(s[1]) or 0
				best = math.max(best, v)
				tip[#tip + 1] = s[2] .. ": " .. WHITE .. Num(v) .. "|r"
			end
			tip[1] = tip[1] .. " " .. Num(best)
			return Num(best), tip
		end },
		{ label = "Healing", get = function()
			local v = GetSpellBonusHealing() or 0
			return Num(v), { "Bonus healing " .. Num(v), "Added to your healing spells." }
		end },
		{ label = "Hit", get = function()
			local r, b = S.Rating("HIT_SPELL")
			local total = b + SpellHitMod()
			return WithRating("+" .. P(total), r), { "Spell hit +" .. P(total),
				("Hit rating %d gives +%s. Talents are not in this number."):format(r, P(b)),
				"About 17% is needed to never miss a boss." }
		end },
		{ label = "Crit", get = function()
			local low, tip = nil, { "Spell critical strike" }
			for _, s in ipairs(SCHOOLS) do
				local v = GetSpellCritChance(s[1]) or 0
				low = low and math.min(low, v) or v
				tip[#tip + 1] = s[2] .. ": " .. WHITE .. P(v) .. "|r"
			end
			local r, b = S.Rating("CRIT_SPELL")
			tip[1] = tip[1] .. " " .. P(low)
			tip[#tip + 1] = ("Crit rating %d gives +%s."):format(r, P(b))
			return WithRating(P(low), r), tip
		end },
		{ label = "Haste", get = function()
			local r, b = S.Rating("HASTE_SPELL")
			return WithRating(P(b), r), { "Spell haste " .. P(b), ("Haste rating %d. Faster casts and a shorter global cooldown."):format(r) }
		end },
		{ label = "Penetration", get = function()
			local v = GetSpellPenetration() or 0
			return Num(v), { "Spell penetration " .. Num(v), "Lowers the target's resistance to your spells by this much." }
		end },
	} },
	{ key = "defense", title = "Defense", rows = {
		{ label = "Armor", get = function()
			local base, eff, _, pos, neg = UnitArmor("player")
			local level = UnitLevel("player") or 1
			return BuffColor(Num(eff), pos, neg), { "Armor " .. Num(eff), BuffLine(base, pos, neg),
				("Lowers physical damage from a level %d attacker by %.1f%%."):format(level, S.ArmorReduction(eff or 0, level)),
				("From a level %d attacker (boss): %.1f%%."):format(level + 3, S.ArmorReduction(eff or 0, level + 3)) }
		end },
		{ label = "Defense", get = function()
			local base, mod = UnitDefense("player")
			local def = (base or 0) + (mod or 0)
			local r, b = GetCombatRating(CR_DEFENSE()) or 0, GetCombatRatingBonus(CR_DEFENSE()) or 0
			local level = UnitLevel("player") or 1
			local over = (def - level * 5) * 0.04
			return BuffColor(Num(def), mod, mod), { "Defense " .. Num(def),
				("Defense rating %d (+%d defense)"):format(r, math.floor(b)),
				("Chance to be hit and critically hit %s %s; dodge, parry and block %s %s."):format(
					over >= 0 and "lowered by" or "raised by", P(math.abs(over)), over >= 0 and "raised by" or "lowered by", P(math.abs(over))),
				("A tank needs %d defense to never be critically hit by a boss (with no resilience)."):format(level * 5 + 140) }
		end },
		{ label = "Dodge", get = function()
			local v = GetDodgeChance() or 0
			local r, b = S.Rating("DODGE")
			return WithRating(P(v), r), { "Dodge " .. P(v), ("Dodge rating %d gives +%s."):format(r, P(b)) }
		end },
		{ label = "Parry", get = function()
			local v = GetParryChance() or 0
			local r, b = S.Rating("PARRY")
			return WithRating(P(v), r), { "Parry " .. P(v), ("Parry rating %d gives +%s."):format(r, P(b)) }
		end },
		{ label = "Block", get = function()
			local v = GetBlockChance() or 0
			local r, b = S.Rating("BLOCK")
			return WithRating(P(v), r), { "Block " .. P(v), ("Block rating %d gives +%s. Needs a shield."):format(r, P(b)) }
		end },
		{ label = "Block value", get = function()
			local v = GetShieldBlock() or 0
			return Num(v), { "Block value " .. Num(v), "Damage stopped by a block. Strength raises it." }
		end },
		{ label = "Resilience", get = function()
			local r, b = S.Rating("CRIT_TAKEN_MELEE")
			local m1 = _G.RESILIENCE_CRIT_CHANCE_TO_DAMAGE_REDUCTION_MULTIPLIER or 2.2
			local m2 = _G.RESILIENCE_CRIT_CHANCE_TO_CONSTANT_DAMAGE_REDUCTION_MULTIPLIER or 2.0
			return Num(r), { "Resilience " .. Num(r),
				("Chance to be critically hit lowered by %s."):format(P(b)),
				("Damage from critical strikes and mana drains lowered by %s."):format(P(b * m1)),
				("Damage from players and their pets lowered by %s."):format(P(b * m2)) }
		end },
	} },
	{ key = "regen", title = "Regen", rows = {
		{ label = "Mana (not casting)", show = function() return (UnitPowerMax("player", 0) or 0) > 0 end, get = function()
			local base = GetManaRegen()
			return Num((base or 0) * 5), { "Mana every 5 seconds: " .. Num((base or 0) * 5),
				"While you have not cast a spell for 5 seconds. Spirit and Intellect raise it." }
		end },
		{ label = "Mana (casting)", show = function() return (UnitPowerMax("player", 0) or 0) > 0 end, get = function()
			local _, casting = GetManaRegen()
			return Num((casting or 0) * 5), { "Mana every 5 seconds: " .. Num((casting or 0) * 5),
				"While casting and in the 5 seconds after a cast. Mp5 gear and some talents raise it." }
		end },
		{ labelFn = function()
			local t = PowerToken()
			local name = _G[t] or t
			return name:sub(1, 1):upper() .. name:sub(2):lower() .. " regen"
		end, show = function() return PowerToken() ~= "MANA" end, get = function()
			local inactive, active = GetPowerRegen()
			local v = (UnitAffectingCombat and UnitAffectingCombat("player")) and active or inactive
			return ("%.1f/s"):format(v or 0), { ("Per second: %.1f out of combat, %.1f in combat"):format(inactive or 0, active or 0) }
		end },
	} },
}
S.SECTIONS = SECTIONS

-- Every value as plain text, for the tests and for /tstats print
function S.Collect()
	local out = {}
	for _, sec in ipairs(SECTIONS) do
		for _, row in ipairs(sec.rows) do
			if not row.show or row.show() then
				local label = row.labelFn and row.labelFn() or row.label
				local value, tip = row.get()
				out[#out + 1] = { section = sec.title, label = label, value = value, tip = tip }
			end
		end
	end
	return out
end

------------------------------------------------------------------------
-- Panel
------------------------------------------------------------------------
local panel, content
local ROW_H, HEAD_H, WIDTH = 13, 18, 220
local dirty, throttle = true, 0

local function ShowTip(self)
	if not self.tip then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	for i, line in ipairs(self.tip) do
		if i == 1 then GameTooltip:AddLine(line, 1, 0.82, 0) else GameTooltip:AddLine(line, 1, 1, 1, true) end
	end
	GameTooltip:Show()
end
local function HideTip() GameTooltip:Hide() end

local function Update()
	if not panel or not panel:IsVisible() then dirty = true return end
	dirty = false
	local y = 0
	for _, sec in ipairs(SECTIONS) do
		local h = sec.header
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
		h.text:SetText((db.collapsed[sec.key] and "+ " or "- ") .. sec.title)
		y = y + HEAD_H
		for _, row in ipairs(sec.rows) do
			local f = row.frame
			if not db.collapsed[sec.key] and (not row.show or row.show()) then
				local value, tip = row.get()
				f.label:SetText(row.labelFn and row.labelFn() or row.label)
				f.value:SetText(value)
				f.tip = tip
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
				f:Show()
				y = y + ROW_H
			else
				f:Hide()
			end
		end
		y = y + 3
	end
	content:SetHeight(math.max(y, 1))
end
S.Update = Update

local function ApplyHideDefault()
	local f = CharacterAttributesFrame
	if not f then return end
	if db.hideDefault then f:Hide() else f:Show() end
end
S.ApplyHideDefault = ApplyHideDefault

local function ApplyShown()
	if not panel then return end
	if db.show then panel:Show() else panel:Hide() end
	panel:SetScale(db.scale or 1)
end
S.ApplyShown = ApplyShown

local function CreatePanel()
	panel = CreateFrame("Frame", "TemucraftStatsFrame", PaperDollFrame)
	panel:SetWidth(WIDTH)
	panel:SetHeight(424)
	panel:SetPoint("TOPLEFT", PaperDollFrame, "TOPRIGHT", -34, -14)
	panel:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 24,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})
	panel:EnableMouse(true)
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -12)
	title:SetText("Stats")

	local scroll = CreateFrame("ScrollFrame", "TemucraftStatsScroll", panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -30)
	scroll:SetPoint("BOTTOMRIGHT", -32, 12)
	content = CreateFrame("Frame", "TemucraftStatsContent", scroll)
	content:SetWidth(WIDTH - 44)
	content:SetHeight(1)
	scroll:SetScrollChild(content)

	for _, sec in ipairs(SECTIONS) do
		local h = CreateFrame("Button", nil, content)
		h:SetWidth(WIDTH - 44)
		h:SetHeight(HEAD_H)
		h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		h.text:SetPoint("LEFT", 0, 0)
		local line = h:CreateTexture(nil, "ARTWORK")
		line:SetTexture(1, 0.82, 0, 0.25)
		line:SetHeight(1)
		line:SetPoint("BOTTOMLEFT", 0, 2)
		line:SetPoint("BOTTOMRIGHT", 0, 2)
		h:SetScript("OnClick", function()
			db.collapsed[sec.key] = not db.collapsed[sec.key] or nil
			Update()
		end)
		h.tip = { sec.title, "Click to fold or unfold this section." }
		h:SetScript("OnEnter", ShowTip)
		h:SetScript("OnLeave", HideTip)
		sec.header = h
		for _, row in ipairs(sec.rows) do
			local f = CreateFrame("Button", nil, content)
			f:SetWidth(WIDTH - 44)
			f:SetHeight(ROW_H)
			f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			f.label:SetPoint("LEFT", 4, 0)
			f.value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			f.value:SetPoint("RIGHT", 0, 0)
			f.value:SetJustifyH("RIGHT")
			f:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
			f:SetScript("OnEnter", ShowTip)
			f:SetScript("OnLeave", HideTip)
			row.frame = f
		end
	end

	panel:SetScript("OnShow", function() Update() end)
	panel:SetScript("OnUpdate", function(self, elapsed)
		throttle = throttle + elapsed
		if dirty and throttle > 0.1 then
			throttle = 0
			Update()
		end
	end)
	ApplyShown()
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local UNIT_EVENTS = {
	"UNIT_STATS", "UNIT_AURA", "UNIT_RESISTANCES", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER",
	"UNIT_DAMAGE", "UNIT_RANGEDDAMAGE", "UNIT_ATTACK_SPEED", "UNIT_ATTACK", "UNIT_DEFENSE",
	"UNIT_MAXHEALTH", "UNIT_MAXMANA", "UNIT_MAXRAGE", "UNIT_MAXENERGY", "UNIT_MAXRUNIC_POWER",
	"UNIT_DISPLAYPOWER", "UNIT_LEVEL", "UNIT_INVENTORY_CHANGED",
}
local OTHER_EVENTS = {
	"PLAYER_EQUIPMENT_CHANGED", "COMBAT_RATING_UPDATE", "PLAYER_DAMAGE_DONE_MODS", "SKILL_LINES_CHANGED",
	"PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
	"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UPDATE_SHAPESHIFT_FORM",
}

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
local function CopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end
S.DEFAULTS = DEFAULTS

driver:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON then
			TemucraftStatsDB = CopyDefaults(DEFAULTS, TemucraftStatsDB or {})
			db = TemucraftStatsDB
		end
		return
	end
	if event == "PLAYER_LOGIN" then
		db = db or CopyDefaults(DEFAULTS, TemucraftStatsDB or {})
		CreatePanel()
		ApplyHideDefault()
		if CharacterAttributesFrame then
			CharacterAttributesFrame:HookScript("OnShow", function(f) if db.hideDefault then f:Hide() end end)
		end
		if TemucraftStats_CreateOptions then TemucraftStats_CreateOptions() end
		for _, e in ipairs(UNIT_EVENTS) do self:RegisterEvent(e) end
		for _, e in ipairs(OTHER_EVENTS) do self:RegisterEvent(e) end
		return
	end
	if event:find("^UNIT_") and arg1 ~= "player" then return end
	dirty = true
end)

function S.GetDB() return db end
function S.MarkDirty() dirty = true end

------------------------------------------------------------------------
-- Slash command
------------------------------------------------------------------------
local function Print(msg) DEFAULT_CHAT_FRAME:AddMessage(TITLE .. ": " .. msg) end
SLASH_TEMUCRAFTSTATS1 = "/tstats"
SlashCmdList.TEMUCRAFTSTATS = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "" or msg == "toggle" then
		db.show = not db.show
		ApplyShown()
		Print("panel " .. (db.show and "shown" or "hidden") .. " (it shows with the character window).")
	elseif msg == "options" or msg == "config" then
		TemucraftStats_OpenOptions()
	elseif msg == "default" then
		db.hideDefault = not db.hideDefault
		ApplyHideDefault()
		Print("default stat boxes " .. (db.hideDefault and "hidden" or "shown") .. ".")
	elseif msg == "ratings" then
		db.showRatings = not db.showRatings
		dirty = true
		Print("ratings next to percents " .. (db.showRatings and "on" or "off") .. ".")
	elseif msg == "print" then
		local last
		for _, r in ipairs(S.Collect()) do
			if r.section ~= last then Print("|cffffd100" .. r.section .. "|r") last = r.section end
			Print("  " .. r.label .. ": " .. r.value)
		end
	elseif msg == "reset" then
		wipe(db)
		CopyDefaults(DEFAULTS, db)
		ApplyShown()
		ApplyHideDefault()
		dirty = true
		Print("settings reset.")
	else
		Print("/tstats: show or hide the panel")
		Print("/tstats options | default (hide or show the default stat boxes) | ratings | print | reset")
	end
end
