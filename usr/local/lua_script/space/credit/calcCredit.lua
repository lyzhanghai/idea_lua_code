--[[
写操作记录到异步队列
@Author  feiliming
@Date    2015-12-17
]]

local say = ngx.print
local len = string.len
local quote = ngx.quote_sql_str

--require model
local cjson = require "cjson"
local ssdblib = require "resty.ssdb"
local mysqllib = require "resty.mysql"
local TS = require "resty.TS"
local TableUtil = require "social.common.table"
local log = require "social.common.log"

--post args
local request_method = ngx.var.request_method
local args,err
if request_method == "GET" then
    args,err = ngx.req.get_uri_args()
else
    ngx.req.read_body()
    args,err = ngx.req.get_post_args()
end
if not args then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end

local paramstr = args["paramstr"]
local paramstr_t = paramstr and cjson.decode(paramstr) or {}
local person_id = paramstr_t.person_id or ""
local identity_id = paramstr_t.identity_id or ""
local platform_type = paramstr_t.platform_type
local business_type = paramstr_t.business_type
local r_person_id = paramstr_t.r_person_id or ""
local r_identity_id = paramstr_t.r_identity_id or ""
local norepeat_ts = paramstr_t.norepeat_ts or ""

--ngx.log(ngx.ERR,"==========="..platform_type..business_type)

if not platform_type or len(platform_type) == 0 or
        not business_type or len(business_type) == 0 then
    say("{\"success\":false,\"info\":\"参数错误！\"}")
    return
end

--mysql
local mysql, err = mysqllib:new()
if not mysql then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end
local ok, err = mysql:connect{
    host = v_mysql_ip,
    port = v_mysql_port,
    database = v_mysql_database,
    user = v_mysql_user,
    password = v_mysql_password,
    max_packet_size = 1024 * 1024 }
if not ok then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end

--ssdb
local ssdb = ssdblib:new()
local ok, err = ssdb:connect(v_ssdb_ip, v_ssdb_port)
if not ok then
    say("{\"success\":false,\"info\":\""..err.."\"}")
    return
end

--获取person_id详情, 调用基础数据接口
local function getPersonInfo(person_id, identity_id)
    local person = {}
    if person_id and len(person_id) > 0 and identity_id and len(identity_id) > 0 then
        local r = {}
        local personService = require "base.person.services.PersonService"
        --log.debug(person_id..identity_id)
        r  = personService:getPersonInfo(person_id,identity_id)
        if not r or not r.success then
            --say("{\"success\":false,\"info\":\"调用基础数据接口失败\"}")
            return person
        end
        person.province_id = r.table_List and r.table_List.province_id or ""
        person.district_id = r.table_List and r.table_List.district_id or ""
        person.city_id = r.table_List and r.table_List.city_id or ""
        person.school_id = r.table_List and r.table_List.school_id or ""
        person.class_id = r.table_List and r.table_List.class_id or ""
    end
    return person
end

--更新积分统计
local function insertOrUpdateCreditCount(ruleset, rule, rule_log)
    local ccount = {}
    local sql3 = "SELECT * FROM t_social_credit_count WHERE person_id = "..quote(rule_log.person_id).." AND identity_id = "..quote(rule_log.identity_id)
    local sql3r, err = mysql:query(sql3)
    if not sql3r then
        error("查询积分统计失败!")
    end
    if #sql3r == 0 then
        local person = getPersonInfo(rule_log.person_id, rule_log.identity_id)
        ccount.person_id = rule_log.person_id
        ccount.identity_id = rule_log.identity_id
        ccount.province_id = person.province_id or ""
        ccount.city_id = person.city_id or ""
        ccount.district_id = person.district_id or ""
        ccount.school_id = person.school_id or ""
        ccount.class_id = person.class_id or ""
        for i=1,#ruleset do
            ccount[ruleset[i].id] = rule[ruleset[i].id]
        end
        local sql4 = "INSERT INTO t_social_credit_count(%s)values(%s)"
        local values = {}
        for _, v in pairs(ccount) do
            table.insert(values, quote(v))
        end
        sql4 = string.format(sql4, table.concat(TableUtil:keys(ccount),","), table.concat(values,","))
        --ngx.log(ngx.ERR,"=====sss====="..sql4)
        local countset, err = mysql:query(sql4)
        if not countset then
            error("插入积分统计失败!")
        end
        if countset.insert_id then
            ssdb:multi_hset("social_credit_"..ccount.person_id.."_"..ccount.identity_id, ccount)
        end
    elseif #sql3r > 0 then
        ccount = sql3r[1]
        local person = getPersonInfo(rule_log.person_id, rule_log.identity_id)
        ccount.province_id = person.province_id or ""
        ccount.city_id = person.city_id or ""
        ccount.district_id = person.district_id or ""
        ccount.school_id = person.school_id or ""
        ccount.class_id = person.class_id or ""
        for i=1,#ruleset do
            ccount[ruleset[i].id] = ccount[ruleset[i].id] + rule[ruleset[i].id]
        end
        local sql5 = "REPLACE INTO t_social_credit_count(%s)values(%s)"
        local values = {}
        for _, v in pairs(ccount) do
            table.insert(values, quote(v))
        end
        sql5 = string.format(sql5, table.concat(TableUtil:keys(ccount),","), table.concat(values,","))
        --ngx.log(ngx.ERR,"=========="..sql5)
        local countset, err = mysql:query(sql5)
        if not countset then
            error("更新积分统计失败!")
        end
        if countset then
            ssdb:multi_hset("social_credit_"..ccount.person_id.."_"..ccount.identity_id, ccount)
        end
    end
end

--插入规则日志
local function insertRuleLog(rule, rule_log)
    local create_time = os.date("%Y-%m-%d %H:%M:%S")
    local ts = TS.getTs()
    rule_log.total_num = 1
    rule_log.cycle_num = 1
    rule_log.cycle_start_time = create_time
    rule_log.last_ts = ts
    rule_log.last_time = create_time
    --查询启用的体系
    local sql = "SELECT * FROM t_social_credit_setting WHERE B_USE = 1"
    local ruleset, err = mysql:query(sql)
    if not ruleset then
        error("查询积分体系失败!")
    end
    for i=1,#ruleset do
        rule_log[ruleset[i].id] = rule[ruleset[i].id]
    end
    --插入规则日志
    local sql2 = "INSERT INTO t_social_credit_rule_log(%s)values(%s)"
    local values = {}
    for _, v in pairs(rule_log) do
        table.insert(values, quote(v))
    end
    sql2 = string.format(sql2, table.concat(TableUtil:keys(rule_log),","), table.concat(values,","))
    --ngx.log(ngx.ERR,"=========="..sql2)
    local rulelogset, err = mysql:query(sql2)
    if not rulelogset then
        error("插入规则日志失败!")
    end
    --更新积分统计
    --log.debug(rule_log)
    insertOrUpdateCreditCount(ruleset, rule, rule_log)
end

--update规则日志
local function updateRuleLog(rule, rule_log)
    if not rule or not rule_log then
        return
    end
    --ngx.log(ngx.ERR,"*********"..rule.cycle_type)
    --1.一次性
    if rule.cycle_type == 1 then
        return
    --2.每天
    elseif rule.cycle_type == 2 then
        local create_time = os.date("%Y-%m-%d %H:%M:%S")
        local ts = TS.getTs()
        local create_time_t = os.date("*t")
        local last_time_t = {
            year = tonumber(string.sub(rule_log.last_time, 1, 4)),
            month = tonumber(string.sub(rule_log.last_time, 6, 7)),
            day = tonumber(string.sub(rule_log.last_time, 9, 10))
        }
        --2.1是否同一天
        if create_time_t.year == last_time_t.year
                and create_time_t.month == last_time_t.month
                and create_time_t.day == last_time_t.day then
            --2.1.1如果周期最大奖励次数大于当前周期执行次数则执行，否则返回
            if rule.reward_num > rule_log.cycle_num then
                rule_log.cycle_num = rule_log.cycle_num + 1
                rule_log.cycle_start_time = rule_log.cycle_start_time
            else
                return
            end
        --2.2如果不是同一天，则重新计数
        else
            rule_log.cycle_num = 1
            rule_log.cycle_start_time = create_time
        end
        rule_log.total_num = rule_log.total_num + 1
        rule_log.last_ts = ts
        rule_log.last_time = create_time
    --3.不限
    elseif rule.cycle_type == 3 then
        local create_time = os.date("%Y-%m-%d %H:%M:%S")
        local ts = TS.getTs()
        rule_log.total_num = rule_log.total_num + 1
        rule_log.cycle_num = rule_log.cycle_num + 1
        rule_log.cycle_start_time = rule_log.cycle_start_time
        rule_log.last_ts = ts
        rule_log.last_time = create_time
    end
    --查询启用的体系
    local sql = "SELECT * FROM t_social_credit_setting WHERE B_USE = 1"
    local ruleset, err = mysql:query(sql)
    if not ruleset then
        error("查询积分体系失败!")
    end
    for i=1,#ruleset do
        rule_log[ruleset[i].id] =  rule_log[ruleset[i].id] + rule[ruleset[i].id]
    end
    --更新规则日志
    local sql2 = "REPLACE into t_social_credit_rule_log(%s)values(%s)"
    --ngx.log(ngx.ERR,"==========="..cjson.encode(rule_log))
    local values = {}
    for _, v in pairs(rule_log) do
        table.insert(values, quote(v))
    end
    sql2 = string.format(sql2, table.concat(TableUtil:keys(rule_log),","), table.concat(values,","))
    --ngx.log(ngx.ERR,"====update======="..sql2)
    local rulelogset, err = mysql:query(sql2)
    if not rulelogset then
        error("更新规则日志失败!")
    end
    --更新积分统计
    insertOrUpdateCreditCount(ruleset, rule, rule_log)
end

--匹配规则
local function matchRule()
    --1.判断是否匹配规则，一个操作可以匹配多条规则
    local sql1 = "SELECT * FROM t_social_credit_rule WHERE b_use=1 and b_delete=0 and business_type = "..quote(business_type)
    local sql1r, err = mysql:query(sql1)
    if not sql1r then
        error("查询积分规则出错!")
    end
    --1.1不匹配规则，直接返回
    if #sql1r == 0 then
        return
    end
    --1.2匹配规则
    for _,rule in pairs(sql1r) do
        local rule_id = rule.id
        local rule_log = {}
        --给主动person加分
        if rule.person_or_rperson == 1 then
            rule_log.person_id = person_id
            rule_log.identity_id = identity_id
        --给被动r_person加分
        else
            rule_log.person_id = r_person_id
            rule_log.identity_id = r_identity_id
        end
        if rule_log.person_id and len(rule_log.person_id)>0 and rule_log.identity_id and len(rule_log.identity_id)>0 then
            --判断是否已经写过，防止写队列重复写
            local sql3 = "SELECT id FROM t_social_credit_rule_log WHERE person_id = "..quote(rule_log.person_id).." AND identity_id = "..quote(rule_log.identity_id).." AND rule_id = "..rule_id.." AND norepeat_ts = "..quote(norepeat_ts)
            --ngx.log(ngx.ERR,"======"..sql3)
            local sql3r, err = mysql:query(sql3)
            if not sql3r then
                error("查询积分规则日志出错!")
            end
            if #sql3r > 0 then
                return
            end

            local sql2 = "SELECT * FROM t_social_credit_rule_log WHERE person_id = "..quote(rule_log.person_id).." AND identity_id = "..quote(rule_log.identity_id).." AND rule_id = "..rule_id
            local sql2r, err = mysql:query(sql2)
            if not sql2r then
                error("查询积分规则日志出错!")
            end
            --2.1没查到规则日志，则第一次插入
            if #sql2r == 0 then
                rule_log.person_id = rule_log.person_id
                rule_log.identity_id = rule_log.identity_id
                rule_log.rule_id = rule_id
                rule_log.business_type = business_type
                rule_log.norepeat_ts = norepeat_ts
                insertRuleLog(rule, rule_log)
            --2.2查到规则日志，则更新
            else
                rule_log = sql2r[1]
                rule_log.norepeat_ts = norepeat_ts
                updateRuleLog(rule, rule_log)
            end
        end
    end
end

--return
local rr = {}
rr.success = true

--事务控制
mysql:query("START TRANSACTION;")
local status, err = pcall(function()
    matchRule()
end)
if status then
    mysql:query("COMMIT;")
else
    mysql:query("ROLLBACK;")
    rr.success = false
    rr.info = err
end

cjson.encode_empty_table_as_object(false)
say(cjson.encode(rr))

--release
mysql:set_keepalive(0,v_pool_size)
ssdb:set_keepalive(0,v_pool_size)