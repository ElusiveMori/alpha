do return end

local t1_a = {}
local t1_b = {1, 2, 3, 4, 5}

local t2_a = {1, 2, 3}
local t2_b = {2, 2, 2, 2}

local t3_a = {1, 2, 3, 4}
local t3_b = {1, 2, 3}

local t4_a = {
	{1, 2, 3},
	2,
	3,
	4,
}

local t4_b = {
	{1, 2, 3},
	2,
	3,
	4,
}

local t5_a = {
	{1, 2, 3},
	2,
	3,
	4,
}

local t5_b = {
	{1, 2, 3, 4},
	2,
	3,
	4,
	5,
}

local t6_a = {
	{1, 2, 3},
	2,
	3,
	4,
}

local t6_b = {
	{1, 2},
	2,
}

local function delta_test(str, t1, t2)
	print("start of test case " .. tostring(str))
	print("in:")
	dprint(t1)
	dprint(t2)
	print("delta:")
	local delta = alpha.util.get_delta(t1, t2)
	dprint(delta)
	print("merge:")
	alpha.util.merge_delta(t1, delta)
	dprint(t1)
	print("end of test case " .. tostring(str))
end

delta_test(1, t1_a, t1_b)
delta_test(2, t2_a, t2_b)
delta_test(3, t3_a, t3_b)
delta_test(4, t4_a, t4_b)
delta_test(5, t5_a, t5_b)
delta_test(6, t6_a, t6_b)