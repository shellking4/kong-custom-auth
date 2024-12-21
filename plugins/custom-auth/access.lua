local _Access = { conf = {} }
local http = require "resty.http"
local pl_stringx = require "pl.stringx"
local cjson = require "cjson.safe"

function _Access.error_response(message, status)
    local response_body = {
        data = {},
        error = {
            code = tostring(status),
            message = message
        }
    }
    return kong.response.exit(status, response_body, {
        ["Content-Type"] = "application/json"
    })
end

function _Access.validate_token(token)
    local httpc = http:new()

    local res, err = httpc:request_uri(_Access.conf.validation_endpoint, {
        method = "POST",
        ssl_verify = _Access.conf.ssl_verify,
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = token
        }
    })

    if not res then
        kong.log.err("Failed to contact auth service: ", err)
        return { status = 0 }
    end

    -- Check if status is in the 2xx range (200-299)
    if res.status < 200 or res.status >= 300 then
        kong.log.warn("Auth service returned non-2xx status: ", res.status)
        return { status = res.status }
    end

    return { status = res.status, body = res.body }
end

function _Access.run(conf)
    _Access.conf = conf
    
    -- Get token from header or cookie using ngx.var
    local token = kong.request.get_header(_Access.conf.token_header) or
                 ngx.var["cookie_token"]

    if not token then
        return _Access.error_response("Unauthenticated", 401)
    end

    -- Get request path using Kong's API
    local request_path = kong.request.get_path_with_query()

    local res = _Access.validate_token(token)

    if not res then
        return _Access.error_response("Authentication server error", 500)
    end

    -- Accept any 2xx status code as success
    if res.status < 200 or res.status >= 300 then
        return _Access.error_response("Authentication server forbids access to the requested resource", 401)
    end

    -- Clear the token header using Kong's API
    kong.service.request.clear_header(_Access.conf.token_header)
end

return _Access