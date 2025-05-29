--- @class Debouncer
--- @field new fun(deb: Debouncer, make_acc: (fun(): any), acc_fn: (fun(accumulator: any, item: any): any), handler: fun(accumulator: any), timer: integer): Debouncer
--- @field close fun(deb: Debouncer)
--- @field push fun(deb: Debouncer): boolean
--- @field handle fun(deb: Debouncer, item: any)
--- Member Attributes
--- @field _accumulator any?
--- @field _make_acc fun(): any
--- @field _acc_fn fun(accumulator: any, item: any): any
--- @field _handler fun(accumulator: any)
--- @field private _timer uv.uv_timer_t?
--- @field private _is_ready boolean
--- @field private _interval integer
local Debouncer = {}
Debouncer.__index = Debouncer

function Debouncer:new(make_acc, acc_fn, handler, timer)
  local vim_timer, error_msg, err_name = vim.uv.new_timer()
  if not vim_timer then
    error(err_name .. ": " .. error_msg)
  end
  local new = {
    _accumulator = nil,
    _make_acc = make_acc,
    _acc_fn = acc_fn,
    _handler = handler,
    _timer = vim_timer,
    _is_ready = false,
    _interval = timer,
  }
  setmetatable(new, self)
  return new
end

function Debouncer:handle(item)
  if not self._is_ready then
    if not self._accumulator then
      self._accumulator = self._make_acc()
    end
    self._accumulator = self._acc_fn(self._accumulator, item)
  else
    self._is_ready = false
    self._timer:start(
      self._interval,
      self._interval,
      vim.schedule_wrap(function()
        if not self._is_ready then
          if not self:push() then
            self._timer:stop()
          end
        end
      end)
    )
  end
end

function Debouncer:push()
  local committed = false
  if self._accumulator ~= nil then
    self._handler(self._accumulator)
    self._accumulator = nil
    committed = true
  end
  self._is_ready = true
  return committed
end

function Debouncer:close()
  if self._timer:is_active() then
    self._timer:stop()
  end
  if not self._is_ready then
    self:push()
  end
  self._timer:close()
end

return Debouncer
