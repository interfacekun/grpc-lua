--- Service.
-- Wraps service implementation module.
-- @classmod grpc_lua.server.Service

local Service = {}

local pb = require("luapbintf")
local Replier = require("grpc_lua.server.Replier")
local Reader = require("grpc_lua.server.Reader")
local Writer = require("grpc_lua.server.Writer")

--- Get service method info map.
-- @string svc_full_name like "helloworld.Greeter"
-- @tab svc_desc service descriptor message table
-- @treturn table map from method name to method info
local function get_method_info_map(svc_full_name, svc_desc)
    assert("table" == type(svc_desc))
    -- See: service_descriptor_example.txt
    local methods = svc_desc.methods
    assert("table" == type(methods))
    local result = {}
    for i = 1, #methods do
        local mthd = methods[i]
        assert("table" == type(mthd))
        local mthd_name = mthd.name
        result[mthd_name] = {  -- method info table
            request_type = pb.get_rpc_input_name(svc_full_name, mthd_name),
            response_type = pb.get_rpc_output_name(svc_full_name, mthd_name),
        }
    end  -- for
    return result
end  -- get_method_info_map()

-------------------------------------------------------------------------------
--- Public functions.
-- @section public

--- Service constructor.
-- Used by `Server`. Do not call it directly.
-- @string svc_full_name like "helloworld.Greeter"
-- @tab svc_desc service descriptor message table
-- @tab svc_impl service implementation
-- @treturn Service
function Service:new(svc_full_name, svc_desc, svc_impl)
    assert("string" == type(svc_full_name))
    assert("table" == type(svc_desc))
    assert("table" == type(svc_impl))
    local svc = {
        -- private:
        _full_name = svc_full_name,
        _descriptor = svc_desc,
        _impl = svc_impl,

        -- map method name to method info
        _method_info_map = get_method_info_map(svc_full_name, svc_desc),
    }
    setmetatable(svc, self)
    self.__index = self
    return svc
end  -- new()

-- Get service full name, like "helloworld.Greeter".
-- @treturn string
function Service:get_full_name()
    return self._full_name
end  -- get_full_name()

-- Get service descriptor table.
-- @treturn table
function Service:get_descriptor()
    return self._descriptor
end  -- get_descriptor()

--- Call simple rpc service method.
-- @string method_name method name, like: "SayHello"
-- @string request_type request type, like: "helloworld.HelloRequest"
-- @string request_str request message string
-- @tparam userdata c_replier C replier object
-- @string response_type response type, like: "helloworld.HelloResponse"
function Service:call_simple_method(method_name, request_type, request_str,
                                    c_replier, response_type)
    assert("string" == type(method_name))
    assert("string" == type(request_type))
    assert("string" == type(request_str))
    assert("userdata" == type(c_replier))
    assert("string" == type(response_type))

    local method, info = self._get_method(method_name)

    local info = assert(self._method_info_map[method_name], "No such method info: "..method_name)
    local method = assert(self._impl[method_name], "No such method impl: "..method_name)
    local request = assert(pb.decode(request_type, request_str))  -- XXX check result
    local replier = Replier:new(c_replier, response_type)
    method(request, replier)
end

--- Call server-to-client streaming rpc method.
-- @string method_name method name, like: "ListFeatures"
-- @string request_type request type, like: "routeguide.Rectangle"
-- @string request_str request message string
-- @tparam userdata c_writer C `ServerWriter` object
-- @string response_type response type, like: "routeguide.Feature"
function Service:call_s2c_streaming_method(method_name,
        request_type, request_str, c_writer, response_type)
    assert("string" == type(method_name))
    assert("string" == type(request_type))
    assert("string" == type(request_str))
    assert("userdata" == type(c_writer))
    assert("string" == type(response_type))

    local method = assert(self._impl[method_name], "No such method: "..method_name)
    local request = assert(pb.decode(request_type, request_str))  -- XXX check result
    local writer = Writer:new(c_writer, response_type)
    method(request, writer)
end

--- Call client-to-server streaming rpc method.
-- @string method_name method name, like: "RecordRoute"
-- @string request_type request type, like: "routeguide.Point"
-- @tparam userdata c_replier C `ServerReplier` object
-- @string response_type response type, like: "routeguide.Summary"
-- @treturn Reader server reader object
function Service:call_c2s_streaming_method(method_name,
        request_type, c_replier, response_type)
    assert("string" == type(method_name))
    assert("string" == type(request_type))
    assert("userdata" == type(c_replier))
    assert("string" == type(response_type))

    local method = assert(self._impl[method_name], "No such method: "..method_name)
    local replier = Replier:new(c_replier, response_type)
    local reader_impl = method(replier)
    return Reader:new(reader_impl, request_type)
end

--- Call bi-directional streaming rpc method.
-- @string method_name method name, like: "RouteChat"
-- @string request_type request type, like: "routeguide.RouteNote"
-- @tparam userdata c_writer C `ServerWriter` object
-- @string response_type response type, like: "routeguide.RouteNote"
-- @treturn Reader server reader object
function Service:call_bidi_streaming_method(method_name,
        request_type, c_writer, response_type)
    assert("string" == type(method_name))
    assert("string" == type(request_type))
    assert("userdata" == type(c_writer))
    assert("string" == type(response_type))

    local method = assert(self._impl[method_name], "No such method: "..method_name)
    local writer = Writer:new(c_writer, response_type)
    local reader_impl = method(writer)
    return Reader:new(reader_impl, request_type)
end

-------------------------------------------------------------------------------
--- Private functions.
-- @section private

--- Get method.
-- @string method_name
-- @treturn function method implementation function
-- @treturn table method info
function Service:_get_method(method_name)
    local info = assert(self._method_info_map[method_name], "No such method info: "..method_name)
    local method = assert(self._impl[method_name], "No such method impl: "..method_name)
end  -- _get_method()

return Service
