
return function(index)
	local meta = {__index = index}
	return setmetatable(index, {
		__call = index.init and
			function(t, ...) local ret = setmetatable({}, meta) ret:init(...) return ret end or
			function(t) return setmetatable({}, meta) end
	})
end

