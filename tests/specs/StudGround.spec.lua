return function(t)
	-- Minimal fake Instances: StudGround only creates Folders and Parts.
	local created = {}
	local fakeInstance = {
		new = function(className)
			local attrs = {}
			local inst = {
				ClassName = className,
				SetAttribute = function(self, k, v)
					attrs[k] = v
				end,
				GetAttribute = function(self, k)
					return attrs[k]
				end,
			}
			table.insert(created, inst)
			return inst
		end,
	}
	-- Modules see the harness globals, so swap Instance there.
	local globals = getfenv(t.require)
	local oldInstance = globals.Instance
	globals.Instance = fakeInstance
	local StudGround = t.require(t.Server.Modules.Map.StudGround)

	local function build(zoneAt)
		table.clear(created)
		local folder = StudGround.Build({}, {
			Cell = 8,
			Radius = 100,
			Bottom = -14,
			SideColor = Color3.new(),
			Zones = {
				Grass = { Color = Color3.new(0, 1, 0), Top = 0 },
				Sand = { Color = Color3.new(1, 1, 0), Top = -1.5 },
			},
			ZoneAt = zoneAt,
		})
		local tops, area, cells = 0, 0, 0
		for _, inst in created do
			if inst.ClassName == "Part" and inst.Name ~= "Dirt" then
				tops += 1
				area += inst.Size.X * inst.Size.Z
				t.expect(inst.Position.Y + inst.Size.Y / 2).toBeCloseTo(if inst.Name == "Sand" then -1.5 else 0, 1e-6)
			end
		end
		for row = 0, 24 do
			for column = 0, 24 do
				if zoneAt(-100 + (column + 0.5) * 8, -100 + (row + 0.5) * 8) then
					cells += 1
				end
			end
		end
		return folder, tops, area, cells
	end

	t.test("stud ground covers every cell once and merges rows into long parts", function()
		local zoneAt = function(x, z)
			local r = math.sqrt(x * x + z * z)
			if r > 90 then
				return nil
			elseif r > 70 then
				return "Sand"
			end
			return "Grass"
		end
		local folder, tops, area, cells = build(zoneAt)
		t.expect(area).toBe(cells * 64)
		t.expect(tops < cells / 3).toBe(true) -- merged, not one part per cell
		t.expect(folder:GetAttribute("Parts") > 0).toBe(true)
	end)

	t.test("empty cells (water) leave gaps", function()
		local _, tops, area = build(function(x)
			return if math.abs(x) < 20 then nil else "Grass"
		end)
		t.expect(area).toBe(25 * 20 * 64) -- 5 of 25 columns are empty
		t.expect(tops).toBe(50) -- two runs per row
	end)

	globals.Instance = oldInstance
end
