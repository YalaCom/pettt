local M = {}
function M.clamp(x, a, b) return math.max(a, math.min(b, x)) end
function M.number(x, fallback, lo, hi)
    if type(x) ~= 'number' or x ~= x or math.abs(x) == math.huge then return fallback end
    return M.clamp(x, lo or -1e12, hi or 1e12)
end
function M.copy(t)
    if type(t) ~= 'table' then return t end
    local r = {}; for k, v in pairs(t) do r[k] = M.copy(v) end; return r
end
function M.exists(path)
    local f = io.open(path, 'rb'); if not f then return false end; f:close(); return true
end
function M.profile(name) return tostring(name or 'default'):gsub('[^A-Za-z0-9_-]', '_'):sub(1, 64) end
function M.inHours(hour, a, b)
    if a < b then return hour >= a and hour < b end
    return hour >= a or hour < b
end
function M.day(t) return os.date('%Y-%m-%d', t) end
function M.minute(t) return tonumber(os.date('%H', t)) * 60 + tonumber(os.date('%M', t)) end
return M
