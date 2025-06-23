local answers_list = require("wordy.answers")
local allowed_list = require("wordy.allowed")

local allowed = {}

for _, w in ipairs(answers_list) do
	allowed[w] = true
end

for _, w in ipairs(allowed_list) do
	allowed[w] = true
end

return {
	answers = answers_list,
	allowed = allowed,
}
