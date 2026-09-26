local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 5000000 -> "5M"
function Format.Number(n: number): string
	n = n or 0
	if n < 1000 then
		return tostring(math.floor(n))
	end
	local i = 1
	-- 999.5 so that values which round up (999999 -> "1000K") use the next suffix
	while n >= 999.5 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local s
	if n >= 100 then
		s = string.format("%.0f", n)
	elseif n >= 10 then
		s = string.format("%.1f", n)
	else
		s = string.format("%.2f", n)
	end
	if string.find(s, "%.") then
		s = (string.gsub(s, "0+$", ""))
		s = (string.gsub(s, "%.$", ""))
	end
	return s .. SUFFIXES[i]
end

function Format.Money(n: number): string
	return "$" .. Format.Number(n)
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local m = seconds // 60
	local s = seconds % 60
	if m > 0 then
		return string.format("%d:%02d", m, s)
	end
	return s .. "s"
end

function Format.Percent(p: number): string
	if p >= 0.1 then
		return string.format("%.0f%%", p * 100)
	end
	return string.format("%.2f%%", p * 100)
end

return Format
