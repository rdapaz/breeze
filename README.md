# Breeze

A CoffeeScript-inspired language that compiles to Lua 5.1. Breeze adds modern syntactic sugar — significant whitespace, arrow functions, string interpolation, classes with inheritance, list comprehensions, and more — while targeting the lightweight, embeddable Lua runtime.

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
- **Unless/until** — negated `if`/`while`
- **Postfix conditionals** — `return x if valid`
- **Compound assignment** — `+=`, `-=`, `*=`, `/=`, `..=`, `%=`
- **`@` shorthand** for `self.` references
- **Import/export** module system

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

## Documentation

See [REFERENCE.md](REFERENCE.md) for the complete language reference.

To regenerate the PDF reference (requires Python + reportlab):

```bash
pip install reportlab
python generate_pdf.py
```

## License

MIT
