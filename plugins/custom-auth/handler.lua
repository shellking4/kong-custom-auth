local access = require "kong.plugins.custom-auth.access"

local CustomAuth = {
    PRIORITY = 1000,
    VERSION = "1.0.0",
}

function CustomAuth:init_worker()
    kong.log.debug("Initializing custom-auth plugin")
    kong.log("Custom-auth plugin initialization completed successfully")
    kong.log.notice("Custom-auth plugin is ready to process requests")
end

function CustomAuth:access(conf)
    access.run(conf)
end

return CustomAuth