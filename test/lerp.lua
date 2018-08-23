local lerp = {}

-- Linear lerp function of the form y=mx + b
-- Usage:
--   local f,b = lerp.linear{in1=1, out1=4, in2=100, out2=1, clamp=true}
--   print("The y-intercept is", b)
--   for x=1,100,10 do
--     print("At", x, "the output is", f(x))
--   end
function lerp.linear(inputs)
	local m = (inputs.out2-inputs.out1)/(inputs.in2-inputs.in1)
	local b = inputs.out1 - m*inputs.in1
	if inputs.clamp then
		local min,max = inputs.in1, inputs.in2
		if min>max then min,max = max,min end
		return function(x)
			x = x<min and min or x>max and max or x
			return m*x + b
		end
	else
		return function(x) return m*x + b end
	end
end

-- Asymptotic lerp function of the form y=s/x + b
-- Usage:
--   local width,min = lerp.asymptote{in1=1, out1=4, in2=100, out2=1, clamp=true}
--   print("The asymptote will bottom out at", min)
--   for x=1,100,10 do
--     print("At", x, "the output is", width(x))
--   end
function lerp.asymptote(inputs)
	local s = inputs.in1*inputs.in2*(inputs.out2-inputs.out1) / (inputs.in1-inputs.in2)
	local b = inputs.out1 - s/inputs.in1
	if inputs.clamp then
		local min,max = inputs.in1, inputs.in2
		if min>max then min,max = max,min end
		return function(x)
			x = x<min and min or x>max and max or x
			return s/x + b
		end, b
	else
		return function(x) return s/x + b end, b
	end
end

return lerp