--[[
    This is a probably not very good and probably innefficient profiler utility.
    Basically add something like
    BeginCommand = function(self) startProfiler()) end
    to an actor in a screen, and periodically the game will display a sorted table by trace executions
]]
function startProfiler(updateInterval, depth, usevmmode, tablePrinter, topN)
    local profile = require("jit.profile")
    local t = {}
    depth = depth or 1
    updateInterval = updateInterval or 1
    profile.start(
        "f",
        usevmmode and function(th, samples, vmmode)
                local f = require("jit.profile").dumpstack(th, "pl", depth)
                if not t[f] then
                    t[f] = {}
                end
                t[f][vmmode] = (t[f][vmmode] or 0) + samples
            end or function(th, samples, vmmode)
                local f = require("jit.profile").dumpstack(th, "pl", depth)
                t[f] = samples + (t[f] or 0)
            end
    )
    tablePrinter = tablePrinter or function(o)
            if type(o) == "table" then
                local s = "{ "
                for k, v in pairs(o) do
                    if type(k) ~= "number" then
                        k = '"' .. k .. '"'
                    end
                    s = s .. "[" .. k .. "] = " .. dump(v) .. ",\n"
                end
                return s .. "} "
            else
                return tostring(o)
            end
        end
    SCREENMAN:GetTopScreen():setInterval(
        function()
            local tmp = {}
            local n = 0
            for k, v in pairs(t) do
                tmp[n + 1] = {k, v}
                n = n + 1
            end
            table.sort(
                tmp,
                function(a, b)
                    return a[2] > b[2]
                end
            )
            local str = ""
            for i = 1, topN and math.min(#tmp, topN) or (#tmp) do
                v = tmp[i]
                str = str .. tablePrinter(v[1]) .. " =" .. tostring(v[2]) .. "\n"
            end
            SCREENMAN:SystemMessage(str)
        end,
        updateInterval
    )
end
