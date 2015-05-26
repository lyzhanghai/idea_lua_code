local ssdblib = require "resty.ssdb"
local SsdbUtil = {}

function SsdbUtil:getDb()
    local ssdb = ssdblib:new()
    local ok, err = ssdb:connect(v_ssdb_ip, v_ssdb_port)
    if not ok then
        return false
    end
    return ssdb;
end
function SsdbUtil:keepalive(ssdb)
    local   ok, err = ssdb: set_keepalive(0, v_pool_size);
    if not ok then
        return false;
    end
    return true;
end

return SsdbUtil;
