#LIBRARY context_init
#DEPEND object

function context_init:initialize()
	self:hook_add("PostObjectInitialize", self.setup)
end

function context_init:setup()
	log:info("setting up game context...")
	alpha.context = C.game_context:create()
	log:info("game context set up.")
end

function context_init:shutdown()
	log:info("tearing down game context...")
	alpha.context:delete()
	alpha.context = nil
	log:info("game context torn down.")
end