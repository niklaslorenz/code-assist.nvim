# The UI Window

Every UI Window class is a subclass of the code-assistant.ui.base-window.BaseWindow class.
It has a buffer as well as a window associated with it, although both can have a nil value,
should the window not be currently visible. Whenever a window or its associated buffer is closed,
its buffer is wiped.

## Creating a Subclass

A subclass of BaseWindow usually follows a simple schema:

```lua
local MySubclass = {}
MySubclass.__index = MySubclass
setmetatable(MySubclass, BaseWindow)

function MySubclass:new(orientation)
	--- @type MySubclass
	local win = BaseWindow.new(self, orientation) --[[@as MySubclass]]
	-- Setup subclass fields here
	return win
end
```

Since every window should have some content, it is **required** to override the `BaseWindow.redraw` method.
The base class will throw an error, if it is not provided. This redraw method is automatically called whenever
the window is shown _after_ the `_setup_buf` method.

```lua
function MySubclass:redraw()
  -- Do not call BaseWindow.redraw(self), because it will raise an error
  -- Implement the window content here
end
```

### Window Events

The BaseWindow class comes with an event dispatcher `on_visibility_change` for whenever the window is shown or hidden.
Custom logic that reacts to this status change can be implemented by subscribing to this dispatcher.

### Overriding default behaviour

Since a new buffer is always created whenever the window is shown, it has to be configured every time.
And there is a method for just that: `BaseWindow._setup_buf`. Just make sure to always call the base class'
function whenever you override it:

```lua
function MySubclass:_setup_buf()
  BaseWindow._setup_buf(self)
  -- Setup buffer configuration here
end
```
