
return function(index)
	return setmetatable({},{
		__index = index,
		__call = index.init and function(t, ...)
			local ret = setmetatable({},t) ret:init(...) return ret
		end or function(t)
			return setmetatable({},t)
		end
	})
end
