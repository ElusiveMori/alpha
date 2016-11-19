local class = Class("debug_info")

if (SERVER) then
	function class:constructor()
		self.should_transmit = CreateConVar("alpha_memreport", "0", bit.bor(FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE))

		util.AddNetworkString("debug_info_memreport")

		self:hook_add("Think", self.on_think)
	end

	function class:destructor()
		self:hook_remove("Think")
	end

	function class:on_think()
		if (self.should_transmit:GetBool()) then
			for k, v in pairs(player.GetAll()) do
				if (v:GetInfo("alpha_debug") == "1") then
					net.Start("debug_info_memreport")
						net.WriteDouble(collectgarbage("count"))
						net.WriteDouble(CurTime())
					net.Send(v)
				end
			end
		end
	end
end

if (CLIENT) then
	function class:constructor()
		self.frames = {}
		self.reports = {}
		self.sample_duration = 1
		self.memory_sv = -1
		self.memory_cl = -1
		self.last_report = 0
		self.overlay_enable = CreateClientConVar("alpha_debug", "0", true, true)

		net.Receive("debug_info_memreport", function()
			local footprint = net.ReadDouble()
			local timestamp = net.ReadDouble()

			self.last_report = SysTime()

			table.insert(self.reports, {footprint, timestamp})
		end)

		self:hook_add("Think", self.on_think)
		self:hook_add("HUDPaint", self.on_paint)
	end

	function class:destructor()
		self:hook_remove("Think")
		self:hook_remove("HUDPaint")
	end

	function class:on_think()
		if (!self.overlay_enable:GetBool()) then
			return
		end

		self.memory_cl = collectgarbage("count")

		table.insert(self.frames, SysTime())

		if (SysTime() - self.last_report > 4) then
			self.memory_sv = -1
		else
			while (self.reports[1] != nil && CurTime() > self.reports[1][2]) do
				self.memory_sv = self.reports[1][1]

				table.remove(self.reports, 1)
			end
		end

		while (self.frames[1] + self.sample_duration < SysTime()) do
			table.remove(self.frames, 1)
		end
	end

	local font = "DebugFixedSmall"

	function class:on_paint()
		if (!self.overlay_enable:GetBool()) then
			return
		end

		draw.SimpleTextOutlined("fps: " .. Format("%3i", math.floor(#self.frames / self.sample_duration)),
                        font,
                        ScrW() - 16, 16,
                        Color(30, 255, 30),
                        TEXT_ALIGN_RIGHT,
                        TEXT_ALIGN_BOTTOM,
                        1, Color(0, 0, 0))

		local kbytes = self.memory_cl % 1024
		local mbytes = self.memory_cl / 1024

		draw.SimpleTextOutlined("client mem: " .. Format("%03iMB %04iKB", mbytes, kbytes),
		                        font,
		                        ScrW() - 16, 32,
		                        Color(240, 227, 116),
		                        TEXT_ALIGN_RIGHT,
		                        TEXT_ALIGN_BOTTOM,
		                        1, Color(0, 0, 0))

		if (self.memory_sv > 0) then
			kbytes = self.memory_sv % 1024
			mbytes = self.memory_sv / 1024

			draw.SimpleTextOutlined("server mem: " .. Format("%03iMB %04iKB", mbytes, kbytes),
	                        font,
	                        ScrW() - 16, 48,
	                        Color(167, 186, 241),
	                        TEXT_ALIGN_RIGHT,
	                        TEXT_ALIGN_BOTTOM,
	                        1, Color(0, 0, 0))
		else
			draw.SimpleTextOutlined("server mem: UNAVAILABLE",
	                        font,
	                        ScrW() - 16, 48,
	                        Color(167, 186, 241),
	                        TEXT_ALIGN_RIGHT,
	                        TEXT_ALIGN_BOTTOM,
	                        1, Color(0, 0, 0))
		end

		local hours = math.floor(CurTime()/60/60)
		local minutes = math.floor((CurTime() % (60*60))/60)
		local seconds = math.floor((CurTime() % 60))
		local milliseconds = math.floor((CurTime()%1) * 1000)

		draw.SimpleTextOutlined("curtime: " .. Format("%02i:%02i:%02i.%03i", hours, minutes, seconds, milliseconds),
                        font,
                        ScrW() - 16, 64,
                        Color(219, 143, 179),
                        TEXT_ALIGN_RIGHT,
                        TEXT_ALIGN_BOTTOM,
                        1, Color(0, 0, 0))
	end

end