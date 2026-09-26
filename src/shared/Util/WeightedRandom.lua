local WeightedRandom = {}

-- Picks one entry from a list. getWeight(entry) returns that entry's weight.
function WeightedRandom.Pick<T>(entries: { T }, getWeight: (T) -> number): T?
	local total = 0
	for _, entry in entries do
		total += getWeight(entry)
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	for _, entry in entries do
		roll -= getWeight(entry)
		if roll <= 0 then
			return entry
		end
	end
	return entries[#entries]
end

return WeightedRandom
