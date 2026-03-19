# Breeze

A CoffeeScript-inspired language that compiles to Lua 5.1. Breeze adds modern syntactic sugar — significant whitespace, arrow functions, string interpolation, classes with inheritance, list comprehensions, and more — while targeting the lightweight, embeddable Lua runtime.

**Zero dependencies** — the compiler is a single Lua file with no external libraries required. No LPeg, no C extensions, no build step. If you have `lua` (5.1+), you have Breeze. This makes it trivially deployable anywhere Lua runs: Wireshark plugins, Nmap scripts, embedded devices, game engines, CI pipelines.

## Features

- **Indentation-based blocks** — no `end` keywords
- **Arrow functions** (`->`) with implicit returns
- **Fat arrows** (`=>`) for automatic `self` binding
- **String interpolation** — `"Hello #{name}"`
- **Classes with inheritance** — `class Dog extends Animal`
- **List comprehensions** — `[x * 2 for x in items]`
- **Switch/when** expressions
- **Try/catch/finally** error handling
- **Existential operator** (`?`) for nil checking
- **Safe navigation** (`?.`) — `user?.profile?.city` (nil-safe chaining)
- **Default operator** (`??`) — `x ?? "fallback"` (preserves `false`, unlike `or`)
- **Pipeline operator** (`|>`) — `data |> parse() |> validate()` (left-to-right chaining)
- **Range literals** — `for i in 1..10`, `1..<5`, `0..100 by 2`
- **Multi-line strings** — `"""..."""` with interpolation, `'''...'''` raw
- **Shorthand properties** — `{ name, age }` expands to `{ name: name, age: age }`
- **Unless/until** — negated `if`/`while`
- **Postfix conditionals** — `return x if valid`
- **Compound assignment** — `+=`, `-=`, `*=`, `/=`, `..=`, `%=`
- **`@` shorthand** for `self.` references
- **Import/export** module system

## Use Cases

Because Breeze compiles to standard Lua 5.1, it can target any application that embeds Lua as a scripting engine. Write cleaner, more readable code in Breeze and transpile to Lua for deployment.

### Wireshark Dissectors

Write custom protocol dissectors with readable, concise syntax instead of verbose Lua. Breeze's string interpolation, clean control flow, and indentation-based blocks make dissector code significantly easier to author and maintain.

```bash
# Compile dissector to Lua
lua breeze.lua -c examples/wireshark_dissectors/modbus_tcp.bz > modbus_tcp.lua

# Install: copy the .lua file to Wireshark's plugins folder
#   Windows: %APPDATA%\Wireshark\plugins\
#   Linux:   ~/.local/lib/wireshark/plugins/
#   macOS:   ~/.local/lib/wireshark/plugins/
```

See [`examples/wireshark_dissectors/`](examples/wireshark_dissectors/) for included dissectors.

### Nmap NSE Scripts

The Nmap Scripting Engine (NSE) runs Lua 5.1 — write network scanning scripts in Breeze and compile to Lua for use with Nmap.

```bash
lua breeze.lua -c my_scan.bz > my_scan.nse
# Copy to Nmap's script directory
```

### Game Scripting & Modding

Many game engines embed Lua for modding and scripting (LOVE2D, Corona/Solar2D, Defold, WoW addons, Roblox, etc.). Use Breeze for a more expressive scripting experience, then compile to Lua for the target engine.

### Embedded Systems & IoT (ESP32 / NodeMCU)

The [NodeMCU](https://nodemcu.readthedocs.io/) firmware runs Lua 5.1 on ESP32 and ESP8266 microcontrollers. Breeze makes embedded code dramatically more readable — arrow functions replace verbose `function()...end` callbacks, and indentation-based blocks eliminate boilerplate.

```coffee
# ESP32 LED Blink with WiFi — compile and upload as init.lua
LED_PIN = 2

gpio.config({gpio: LED_PIN, dir: gpio.OUT})
led_state = false

blink_timer = tmr.create()
blink_timer:alarm(500, tmr.ALARM_REP, ->
  led_state = not led_state
  if led_state
    gpio.write(LED_PIN, 1)
  else
    gpio.write(LED_PIN, 0)
)

wifi.mode(wifi.STATION, true)
wifi.sta.config({ssid: "MyNetwork", pwd: "MyPassword", auto: true})

wifi.sta.on("got_ip", (name, info) ->
  print("WiFi connected! IP: #{info.ip}")
)
```

```bash
# Compile and upload to ESP32
lua breeze.lua -c examples/esp32_blink.bz > init.lua
# Flash init.lua to the device using ESPlorer or nodemcu-tool
```

See [`examples/esp32_blink.bz`](examples/esp32_blink.bz) for the full example.

## Quick Start

Requires **Lua 5.1** (or LuaJIT).

```bash
# Start the REPL
lua breeze.lua

# Run a Breeze file
lua breeze.lua examples/basics.bz

# Compile to Lua (print to stdout)
lua breeze.lua -c examples/basics.bz

# Evaluate inline code
lua breeze.lua -e "greet = (name) -> 'Hello #{name}'"
```

## Examples

### Variables & Functions

```coffee
name = "World"
greet = (who) -> "Hello #{who}!"
print greet(name)

fib = (n) ->
  if n <= 1
    n
  else
    fib(n - 1) + fib(n - 2)
```

### Classes

```coffee
class Animal
  new: (name) =>
    @name = name

  speak: =>
    print "#{@name} makes a sound"

class Dog extends Animal
  speak: =>
    print "#{@name} barks"

rex = new Dog("Rex")
rex:speak()
```

### List Comprehensions

```coffee
numbers = [1, 2, 3, 4, 5]
doubled = [x * 2 for x in numbers]
evens = [x for x in numbers if x % 2 == 0]
```

### Switch/When

```coffee
describe = (val) ->
  switch typeof(val)
    when "string"
      "a string: #{val}"
    when "number"
      "a number: #{val}"
    else
      "something else"
```

### Wireshark Dissector (Modbus TCP)

```coffee
proto = Proto("modbus_bz", "Modbus TCP (Breeze)")

f_trans_id  = ProtoField.uint16("modbus_bz.trans_id", "Transaction ID", base.HEX)
f_func_code = ProtoField.uint8("modbus_bz.func_code", "Function Code", base.HEX)

func_names = {
  [0x03]: "Read Holding Registers",
  [0x06]: "Write Single Register",
  [0x10]: "Write Multiple Registers"
}

proto.dissector = (buffer, pinfo, tree) ->
  if buffer:len() < 8
    return
  pinfo.cols.protocol = "Modbus TCP"
  subtree = tree:add(proto, buffer(), "Modbus TCP")
  func_code = buffer(7, 1):uint()
  pinfo.cols.info = "Unit #{buffer(6,1):uint()}: #{func_names[func_code]}"
  # ... parse fields ...

tcp_table = DissectorTable.get("tcp.port")
tcp_table:add(502, proto)
```

See [`examples/wireshark_dissectors/modbus_tcp.bz`](examples/wireshark_dissectors/modbus_tcp.bz) for the full dissector.

## Breeze vs Lua at a Glance

| Breeze | Lua |
|--------|-----|
| `x = 42` | `local x = 42` |
| `add = (a, b) -> a + b` | `local function add(a, b) return a + b end` |
| `"Hello #{name}"` | `"Hello " .. tostring(name)` |
| `print x if x > 0` | `if x > 0 then print(x) end` |
| `items = [1, 2, 3]` | `local items = {1, 2, 3}` |
| `for item in items` | `for _, item in ipairs(items) do ... end` |
| `@name = name` | `self.name = name` |
| `data \|> f() \|> g()` | `g(f(data))` |
| `user?.name ?? "anon"` | nil-safe access with default |
| `for i in 1..5` | `for i = 1, 5 do ... end` |
| `"""multi-line"""` | triple-quoted string |
| `{ name, age }` | `{name = name, age = age}` |

## Editor Support

### Sublime Text

Full syntax highlighting, build system, and editor settings included. See [`editor/sublime/`](editor/sublime/) for installation instructions.

## Documentation

See [REFERENCE.md](REFERENCE.md) for the complete language reference.

To regenerate the PDF reference (requires Python + reportlab):

```bash
pip install reportlab
python generate_pdf.py
```

## License

MIT
