local Util = {}

local has_whichkey, WhichKey = pcall(require, "which-key")

--- @param lhs string
--- @param rhs fun()|string?
--- @param description string?
--- @param opts vim.keymap.set.Opts?
--- @param mode string|string[]?
function Util.set_keymap(lhs, rhs, description, opts, mode)
  if not opts then
    opts = {}
  end
  if not mode then
    mode = "n"
  end
  if has_whichkey then
    local f = type(rhs) == "function" and rhs or nil
    local s = type(rhs) == "string" and rhs or nil
    --- @type wk.Spec
    local mapping = {
      {
        mode = mode,
        callback = f,
        lhs = lhs,
        desc = description,
        rhs = s,
      },
    }
    for k, v in pairs(opts) do
      mapping[k] = v
    end
    WhichKey.add(mapping)
  elseif rhs then
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

return Util
