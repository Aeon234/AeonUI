-- This addon's table reads through to the base addon's, so its files use AUI as the base's do. What they assign stays
-- in this table.
setmetatable(select(2, ...), { __index = AeonUI })
