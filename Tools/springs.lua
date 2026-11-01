-- A stand-in for LibAeonSettings' springs (`Source/Motion.lua`) for the offline checks: the same calls, the same
-- critically damped motion and rest rule, and Reduce Motion, stepped by `Frames` instead of an OnUpdate. Loaded with
-- `loadfile(...)(lib)`, it adds `CreateSpring` and `ReduceMotion` to the stand-in library and returns the controls.

local lib = ...

local motion = { moving = {}, reduce = false }

local Spring = {}
local springMeta = { __index = Spring }

local function Step(value, velocity, target, response, elapsed)
	local omega = 2 * math.pi / response
	local x = value - target
	local decay = math.exp(-omega * elapsed)
	local slope = velocity + omega * x

	return target + decay * (x + slope * elapsed), decay * (velocity - omega * elapsed * slope)
end

function lib:ReduceMotion()
	return motion.reduce
end

function lib:CreateSpring(value, onUpdate, options)
	options = options or {}

	return setmetatable({
		value = value, velocity = 0, target = value, onUpdate = onUpdate, onRest = options.onRest,
		response = options.response or 0.3, epsilon = options.epsilon or 0.001,
	}, springMeta)
end

function Spring:To(target)
	self.target = target

	if motion.reduce or (math.abs(self.value - target) < self.epsilon and math.abs(self.velocity) < self.epsilon * 10) then
		self:Jump(target)

		return
	end

	motion.moving[self] = true
end

function Spring:Jump(value)
	motion.moving[self] = nil
	self.value, self.target, self.velocity = value, value, 0
	self.onUpdate(value)

	if self.onRest then
		self.onRest(value)
	end
end

function Spring:Stop()
	motion.moving[self] = nil
	self.velocity = 0
end

function Spring:IsMoving()
	return motion.moving[self] == true
end

---Steps every moving spring for `seconds` at 60 frames a second.
---@param seconds number
function motion.Frames(seconds)
	for _ = 1, math.floor(seconds * 60 + 0.5) do
		local list = {}

		for spring in pairs(motion.moving) do
			list[#list + 1] = spring
		end

		for _, spring in ipairs(list) do
			spring.value, spring.velocity = Step(spring.value, spring.velocity, spring.target, spring.response, 1 / 60)

			if math.abs(spring.value - spring.target) < spring.epsilon
				and math.abs(spring.velocity) < spring.epsilon * 10 then
				spring:Jump(spring.target)
			else
				spring.onUpdate(spring.value)
			end
		end
	end
end

---@return boolean moving some spring is still moving
function motion.Moving()
	return next(motion.moving) ~= nil
end

return motion
