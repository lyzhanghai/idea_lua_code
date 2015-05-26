local Util = {}
local table = require("social.common.table")
--- 将数据转化为可打印的字符串
--
-- @param table data 数据
-- @param string indentStr 缩进字符
-- @param number indentLevel 缩进级别
-- @return string 可打印的字符串
function Util:toString(data, indentStr, indentLevel)
    local dataType = type(data)

    if dataType == "string" then
        return string.format('%q', data)
    elseif dataType == "number" or dataType == "boolean" then
        return tostring(data)
    elseif dataType == "table" then
        return table:toString(data, indentStr or "\t", indentLevel or 1)
    else
        return "<" .. tostring(data) .. ">"
    end
end

--- 打印数据到日志文件中
--
-- @param table data 数据
-- @param string prefix 描述前缀
-- @param string logFile 日志文件路径
function Util:logData(data, prefix, logFile)
    self:writeFile(logFile or "/tmp/lua.log", (prefix or "") .. self:toString(data) .. "\n", true)
end
--- 将字符串内容写入文件
--
-- @param string file 文件路径
-- @param string content 内容
-- @param string append 追加模式(否则为覆盖模式)
function Util:writeFile(file, content, append)
    local fd = io.open(file, append and "a+" or "w+")
    local result, err = fd:write(content)
    fd:close()
    if not result then
        error(err)
    end
end

---字符串分割函数
--传入字符串和分隔符，返回分割后的table
--@param #string str 目标字符串.
--@param #string delimiter 分隔符.
--@return table 分隔后的table
function Util:split(str, delimiter)
    if str==nil or str=='' or delimiter==nil then
        return nil
    end

    local result = {}
    for match in (str..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

---通过ssdb的multi_hget查询回来的结果返回一个类似于hashmap的table
---过滤掉不存在的key,可以解决对应不上和下标乱序问题
--@param #table ssdbResult
--@param #table keys
--    local keys = {"id","total_today","total_yestoday","total","name","logo_url","icon_url","domain"}
--    local ssdbResult = {"id","1","name","zhanghai","logo_url","dfasdf.jpg"}
function Util:multi_hget(ssdbResult,keys)
    local keyResult = {}
    local valueResult = {}
    local len = #ssdbResult;
    for i=1, len do
        if i%2~=0 then
            keyResult[#keyResult+1] = ssdbResult[i]
        else
            valueResult[#valueResult+1] = ssdbResult[i]
        end
    end
    local result = {}
    for i=1,#keys do
        for j =1 ,#keyResult do
            if keys[i] == keyResult[j] then
                result[keys[i]] = valueResult[j]
                break;
            else
                result[keys[i]] = ""
            end
        end
    end
    return result
end

--------------------------------------------------------------------------------
--日期工具，可获取前一天的日期
--
--yyyymmdd
--

function Util:day_step(old_day,step) 
   local y,m,d
   if("0" ~= string.sub(old_day,5,5)) then
      m=string.sub(old_day,5,6)
   else
      m=string.sub(old_day,6,6)
   end
   print(m)
   if("0" ~= string.sub(old_day,7,7)) then
      d=string.sub(old_day,7,8)
   else
      d=string.sub(old_day,8,8)
   end
   y=string.sub(old_day,0,4)
   local old_time=os.time{year=y,month=m,day=d}
   local new_time=old_time+86400*step
   local new_day=os.date("*t",new_time)
   local res=""
   if(tonumber(new_day.day)<10 and tonumber(new_day.month)<10)then
      res=new_day.year.."0"..new_day.month.."0"..new_day.day
   elseif tonumber(new_day.month)<10 then
      res=new_day.year.."0"..new_day.month..new_day.day
   elseif tonumber(new_day.day)<10 then
      res=new_day.year..new_day.month.."0"..new_day.day
   else
      res=new_day.year..new_day.month..new_day.day
   end
   return res
end

return Util
