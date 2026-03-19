# Breeze Language Reference

**Breeze** is a CoffeeScript-inspired language that compiles to clean Lua 5.1.
It features significant whitespace, arrow functions, implicit returns, classes,
string interpolation, and many syntactic conveniences.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Variables & Assignment](#variables--assignment)
- [Strings & Interpolation](#strings--interpolation)
- [Numbers](#numbers)
- [Booleans & Nil](#booleans--nil)
- [Operators](#operators)
- [Functions](#functions)
- [Control Flow](#control-flow)
- [Loops](#loops)
- [Arrays & Tables](#arrays--tables)
- [List Comprehensions](#list-comprehensions)
- [Classes](#classes)
- [Switch / When](#switch--when)
- [Try / Catch / Finally](#try--catch--finally)
- [Modules](#modules)
- [Pipeline Operator](#pipeline-operator)
- [Safe Navigation](#safe-navigation)
- [Default Operator](#default-operator)
- [Range Literals](#range-literals)
- [Miscellaneous](#miscellaneous)
- [CLI Usage](#cli-usage)

---

## Getting Started

```bash
# Run a file
breeze program.bz

# Compile to Lua (prints to stdout)
breeze -c program.bz

# Evaluate inline code
breeze -e "print('hello')"

# Start the REPL
breeze
```

---

## Variables & Assignment

Variables are automatically declared as `local` on first use.
Subsequent assignments do not re-declare them.

```coffee
name = "Alice"
age = 30
age = 31           # no 're-local', just reassigns
```

**Compound assignment** operators:

```coffee
x = 10
x += 5             # x = x + 5
x -= 2             # x = x - 2
x *= 3             # x = x * 3
x /= 2             # x = x / 2
x %= 4             # x = x % 4
msg = "hello"
msg ..= " world"   # msg = msg .. " world"
```

---

## Strings & Interpolation

Single-quoted strings are literal. Double-quoted strings support `#{expr}` interpolation.

```coffee
name = "World"
greeting = "Hello #{name}!"           # "Hello World!"
result = "2 + 2 = #{2 + 2}"           # "2 + 2 = 4"
literal = 'no #{interpolation} here'  # stays as-is
```

Escape sequences work in both: `\n`, `\t`, `\r`, `\\`, `\"`, `\'`.

### Multi-line Strings

Triple-quoted strings support multi-line content with automatic dedenting.

**Double triple-quotes** (`"""..."""`) support interpolation:

```coffee
html = """
  <div class="greeting">
    <h1>Hello #{name}!</h1>
    <p>Welcome to Breeze.</p>
  </div>
"""
```

**Single triple-quotes** (`'''...'''`) are raw — no interpolation or escape processing:

```coffee
template = '''
  This #{is} raw text.
  No interpolation here.
  Backslashes are literal: \n \t
'''
```

Common leading whitespace is automatically stripped based on the least-indented line, so the content aligns naturally in your source code without extra indentation in the output.

---

## Numbers

```coffee
x = 42
pi = 3.14159
big = 1e6
hex = 0xFF
```

---

## Booleans & Nil

```coffee
yes = true
no = false
nothing = nil
```

---

## Operators

### Arithmetic
```coffee
1 + 2       # addition
5 - 3       # subtraction
4 * 2       # multiplication
10 / 3      # division
10 % 3      # modulo
2 ^ 8       # exponentiation (256)
```

### Comparison
```coffee
a == b      # equal (compiles to ==)
a != b      # not equal (compiles to ~=)
a < b       # less than
a > b       # greater than
a <= b      # less or equal
a >= b      # greater or equal
```

### Logical
```coffee
a and b
a or b
not a
!a          # same as 'not a'
```

### String
```coffee
"hello" .. " world"   # concatenation
```

### Other
```coffee
#list        # length operator
typeof x     # compiles to type(x)
value?       # existential: compiles to (value ~= nil)
```

---

## Functions

### Arrow Functions (`->`)

```coffee
# No parameters
greet = -> "hello!"

# With parameters
square = (x) -> x * x

# Multi-line (indented block)
fibonacci = (n) ->
  if n <= 1
    n
  else
    fibonacci(n - 1) + fibonacci(n - 2)
```

The **last expression** in a function body is automatically returned (implicit return).

### Default Parameters

```coffee
greet = (name, greeting = "Hello") ->
  "#{greeting}, #{name}!"

greet("Alice")         # "Hello, Alice!"
greet("Bob", "Hi")     # "Hi, Bob!"
```

### Fat Arrow (`=>`)

Fat arrows automatically bind `self` as the first parameter.
Use inside classes to create callbacks that retain `self`.

```coffee
class Timer
  start: ->
    # The fat arrow captures self
    @callback = =>
      @elapsed += 1
      print("Tick #{@elapsed}")
```

### Varargs

```coffee
log = (label, ...) ->
  print(label, ...)
```

### `@` Parameters

Parameters prefixed with `@` are automatically assigned to `self`:

```coffee
class Point
  constructor: (@x, @y) ->
    # @x and @y are auto-assigned, no manual self.x = x needed
```

---

## Control Flow

### if / else / elseif

```coffee
if score >= 90
  print("A")
elseif score >= 80
  print("B")
else
  print("C")
```

An optional `then` keyword is allowed for readability:

```coffee
if ready then go()
```

### unless

`unless` is syntactic sugar for `if not`:

```coffee
unless done
  print("still working...")
```

### Postfix Conditionals

Any statement can have a trailing `if` or `unless`:

```coffee
print("big!") if x > 100
print("ok") unless error
```

---

## Loops

### for..in (array iteration)

Iterates values using `ipairs`:

```coffee
for item in [10, 20, 30]
  print(item)

# With index:
for i, item in [10, 20, 30]
  print("#{i}: #{item}")
```

### for..of (table iteration)

Iterates key-value pairs using `pairs`:

```coffee
config = {host: "localhost", port: 8080}
for key, value of config
  print("#{key} = #{value}")
```

### Numeric for

```coffee
for i = 1, 10
  print(i)

# With step:
for i = 0, 100, 5
  print(i)
```

### while / until

```coffee
while running
  update()

until done
  process()
```

### break

```coffee
for item in items
  break if item == "stop"
  print(item)
```

---

## Arrays & Tables

### Arrays

```coffee
empty = []
numbers = [1, 2, 3, 4, 5]
mixed = ["hello", 42, true]
```

### Tables (Objects)

Use `key: value` syntax (no quotes needed on keys):

```coffee
person = {name: "Alice", age: 30}
point = {x: 10, y: 20}
```

### Shorthand Properties

When a key name matches a variable name, use the shorthand form:

```coffee
name = "Alice"
age = 30
person = { name, age, active: true }
# => {name: "Alice", age: 30, active: true}
```

This is equivalent to `{ name: name, age: age, active: true }`.

### Computed Keys

```coffee
key = "color"
obj = {[key]: "red"}
```

### Access

```coffee
person.name          # dot access
person["name"]       # bracket access
list[1]              # index access
#list                # length
```

---

## List Comprehensions

Build arrays with inline `for` and optional `if` guard:

```coffee
# Basic
doubles = [x * 2 for x in [1, 2, 3, 4, 5]]
# => [2, 4, 6, 8, 10]

# With filter
evens = [x for x in [1, 2, 3, 4, 5, 6] if x % 2 == 0]
# => [2, 4, 6]

# With index
indexed = ["#{i}:#{v}" for i, v in ["a", "b", "c"]]

# Transform + filter
big_squares = [x * x for x in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] if x > 5]
# => [36, 49, 64, 81, 100]
```

---

## Classes

### Basic Class

```coffee
class Animal
  constructor: (@name, @sound = "...") ->
    @legs = 4

  speak: ->
    "#{@name} says #{@sound}"

  describe: ->
    "#{@name} has #{@legs} legs"
```

### Inheritance

```coffee
class Dog extends Animal
  constructor: (@name) ->
    @sound = "Woof!"
    @tricks = []

  learn: (trick) ->
    @tricks[#@tricks + 1] = trick
    "#{@name} learned #{trick}!"
```

### Super

Use `super()` to call the parent class's version of the current method:

```coffee
class Dog extends Animal
  constructor: (@name) =>
    super(@name, "Woof!")     # calls Animal's constructor
    @tricks = []

  speak: =>
    parent_says = super()     # calls Animal's speak()
    "#{parent_says} (but LOUDER)"
```

Compiles to `ParentClass.method(self, args...)` — the standard Lua pattern for explicit parent method calls.

### Instantiation

Use `new` to create instances:

```coffee
rex = new Dog("Rex")
print(rex:speak())          # "Rex says Woof! (but LOUDER)"
print(rex:learn("sit"))     # "Rex learned sit!"
```

### Key Concepts

- `@field` is shorthand for `self.field`
- `@` parameters in constructors auto-assign to `self`
- `super(args)` calls the parent's version of the current method
- Methods use `:` for definition and calling (Lua method syntax)
- The `constructor` method is called automatically by `new`
- The last expression in a method is implicitly returned (except in `constructor`)

---

## Switch / When

```coffee
day = "monday"
switch day
  when "monday", "tuesday", "wednesday", "thursday", "friday"
    print("Weekday")
  when "saturday", "sunday"
    print("Weekend")
  else
    print("Unknown")
```

Each `when` can match multiple values (comma-separated).

---

## Try / Catch / Finally

```coffee
try
  result = risky_operation()
  print(result)
catch err
  print("Error: #{err}")
finally
  cleanup()
```

Compiles to `pcall` under the hood.

---

## Modules

### Import

```coffee
# Import a single module
import http from "socket.http"

# Destructured import
import {insert, remove} from "table"
```

### Export

```coffee
export add = (a, b) -> a + b
export sub = (a, b) -> a - b

export class Vector
  constructor: (@x, @y) ->
```

Exported names are collected into a return table at the end of the file.

---

## Pipeline Operator

The pipeline operator `|>` passes the left-hand value as the first argument to the right-hand function. This enables readable left-to-right data transformation chains.

```coffee
double = (x) -> x * 2
add_one = (x) -> x + 1

# Instead of nested calls:
result = add_one(double(5))

# Use pipeline:
result = 5 |> double() |> add_one()
# => 11
```

When the right-hand function takes additional arguments, the piped value is prepended:

```coffee
add = (a, b) -> a + b
result = 10 |> add(5)
# => add(10, 5) => 15
```

A bare function name (without parentheses) is also valid:

```coffee
result = data |> process
# => process(data)
```

The pipeline operator has the lowest precedence, so arithmetic and comparisons bind tighter:

```coffee
result = 1 + 2 |> double()
# => double(3) => 6
```

---

## Safe Navigation

The safe navigation operator `?.` short-circuits to `nil` when the left-hand side is `nil`, avoiding "attempt to index nil" errors.

### Property Access

```coffee
user = { profile: { address: { city: "Melbourne" } } }

city = user?.profile?.address?.city
# => "Melbourne"

nobody = nil
city = nobody?.profile?.address?.city
# => nil (no error)
```

### Safe Indexing

Use `?[` for safe bracket access:

```coffee
items = { tags: ["lua", "breeze"] }
first = items?.tags?[1]     # => "lua"

empty = nil
val = empty?.tags?[1]       # => nil
```

### Safe Method Calls

```coffee
obj?.method(args)
# If obj is nil, returns nil instead of erroring
```

### Combined with Default Operator

```coffee
theme = config?.ui?.theme ?? "dark"
# If any part of the chain is nil, falls back to "dark"
```

---

## Default Operator

The `??` operator returns the right-hand side only when the left is `nil`. Unlike `or`, it preserves `false` values.

```coffee
name = nil
display = name ?? "Anonymous"    # => "Anonymous"

flag = false
val = flag ?? true               # => false (preserved!)
val = flag or true               # => true  (lost!)
```

Chain multiple defaults:

```coffee
a = nil
b = nil
c = "found"
result = a ?? b ?? c             # => "found"
```

---

## Range Literals

Ranges generate sequences of numbers. They are most commonly used in `for..in` loops and list comprehensions.

### Inclusive Range (`..`)

In a `for..in` loop, `..` creates an inclusive range:

```coffee
for i in 1..5
  print(i)
# => 1, 2, 3, 4, 5
```

### Exclusive Range (`..<`)

The `..<` operator excludes the upper bound:

```coffee
for i in 1..<5
  print(i)
# => 1, 2, 3, 4
```

### Step Values (`by`)

Add `by` to specify a step:

```coffee
for i in 0..10 by 3
  print(i)
# => 0, 3, 6, 9

for i in 10..1 by -1
  print(i)
# => 10, 9, 8, ..., 1
```

### In List Comprehensions

Ranges work naturally in comprehensions:

```coffee
squares = [i * i for i in 1..10]
evens = [i for i in 0..<20 by 2]
```

### Standalone Ranges

Use `..<` for standalone range expressions (outside loops):

```coffee
digits = 0..<10
# => {0, 1, 2, 3, 4, 5, 6, 7, 8, 9}
```

> **Note:** Inside `for..in` and list comprehensions, `..` is always treated as a range.
> In other contexts, `..` remains the string concatenation operator.
> Use `..<` when you need an unambiguous range expression outside of loops.

---

## Miscellaneous

### Existential Operator

```coffee
if value?
  print("value exists")

# Compiles to: if (value ~= nil) then
```

### typeof

```coffee
print(typeof 42)        # "number"
print(typeof "hi")      # "string"
print(typeof true)      # "boolean"

# Compiles to: type(x)
```

### do Blocks

Immediately-invoked function expression:

```coffee
result = do
  x = compute()
  y = transform(x)
  x + y
```

### Comments

```coffee
# This is a comment
name = "Alice"  # inline comment
```

> **Note:** `#` is also the length operator. Breeze disambiguates based on context:
> `#list` is length, `# comment text` after a value is a comment.

### Method Calls

Breeze preserves Lua's `:` method call syntax:

```coffee
list = [3, 1, 2]
table.sort(list)          # function call with .
obj:method(arg)           # method call with : (passes self)
```

---

## Pattern Matching (Regex)

Lua 5.1 doesn't have traditional regular expressions — it has **Lua patterns**, a lighter
but capable subset. Since Breeze compiles to Lua, you use the standard `string` library directly.

### Basic Operations

```coffee
# string.match — extract captures
ip = "192.168.1.100"
a, b, c, d = string.match(ip, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
print("#{a}.#{b}.#{c}.#{d}")

# string.find — locate a pattern (returns start, end positions)
s = "Hello World"
start, stop = string.find(s, "Wor")

# string.gmatch — iterate all matches
text = "key1=val1&key2=val2&key3=val3"
for k, v in string.gmatch(text, "(%w+)=(%w+)")
  print("#{k} -> #{v}")

# string.gsub — find and replace
cleaned = string.gsub("  hello   world  ", "%s+", " ")

# Method syntax works too (colon calls)
result = s:match("(%w+)")
cleaned = s:gsub("%s+", " ")
pos = s:find("World")
```

### Pattern Character Classes

| Pattern | Matches |
|---------|---------|
| `.` | Any character |
| `%a` | Letters (A-Z, a-z) |
| `%d` | Digits (0-9) |
| `%w` | Alphanumeric (letters + digits) |
| `%s` | Whitespace |
| `%p` | Punctuation |
| `%l` / `%u` | Lower / upper case |
| `%A`, `%D`, etc. | Complement (non-letters, non-digits, etc.) |
| `[abc]` | Character set |
| `[^abc]` | Negated character set |
| `[a-z]` | Character range |

### Quantifiers

| Pattern | Meaning |
|---------|---------|
| `*` | 0 or more (greedy) |
| `+` | 1 or more (greedy) |
| `-` | 0 or more (lazy) |
| `?` | 0 or 1 |

### Anchors & Captures

| Pattern | Meaning |
|---------|---------|
| `^` | Start of string |
| `$` | End of string |
| `(...)` | Capture group |
| `%1`, `%2` | Back-references (in `gsub` replacement only) |

### Escaping Special Characters

Use `%` to escape magic characters: `( ) . % + - * ? [ ^ $`

```coffee
# Match a literal dot
version = string.match("lua-5.1.4", "(%d+%.%d+%.%d+)")
print(version)  # "5.1.4"
```

### Practical Examples

```coffee
# Validate an email (basic)
is_email = (s) -> s:match("^[%w%.%-]+@[%w%.%-]+%.%w+$") != nil

# Extract filename from path
path = "/home/user/docs/report.pdf"
filename = path:match("([^/]+)$")
print(filename)  # "report.pdf"

# Split a string by delimiter
split = (s, sep) ->
  parts = []
  for part in s:gmatch("([^" .. sep .. "]+)")
    parts[#parts + 1] = part
  parts

words = split("hello,world,breeze", ",")

# Strip ANSI escape codes
strip_ansi = (s) -> s:gsub("\27%[%d+m", "")
```

### Differences from Regular Expressions

- **No alternation** (`|`) — can't do `cat|dog`
- **`%d` not `\d`** — percent prefix, not backslash
- **Lazy quantifier is `-`** not `*?`
- **No `{n,m}` repetition** quantifiers
- **No lookahead/lookbehind**
- **No backreferences in patterns** (only in `gsub` replacements)

For most practical tasks (parsing protocols, log files, configuration) Lua patterns are
more than sufficient. For full PCRE, use the `lrexlib` Lua library if available.

---

## CLI Usage

```
breeze                        Start the interactive REPL
breeze file.bz                Run a Breeze file
breeze -c file.bz             Compile to Lua and print to stdout
breeze -e "code"              Evaluate inline Breeze code
breeze -e "code" -c           Show compiled Lua for inline code
breeze -h                     Show help
```

---

## Quick Comparison

| Breeze                          | Lua 5.1 Equivalent                              |
|---------------------------------|--------------------------------------------------|
| `x = 42`                       | `local x = 42`                                   |
| `x += 1`                       | `x = x + 1`                                      |
| `(x) -> x * x`                 | `function(x) return x * x end`                   |
| `=> @count`                    | `function(self) return self.count end`            |
| `"hi #{name}"`                 | `"hi " .. tostring(name)`                        |
| `@name`                        | `self.name`                                       |
| `x != y`                       | `x ~= y`                                         |
| `unless done`                  | `if not done then`                                |
| `print(x) if ok`              | `if ok then print(x) end`                        |
| `[x*2 for x in list]`         | loop building a table                             |
| `new Dog("Rex")`              | `Dog:new("Rex")`                                  |
| `typeof x`                     | `type(x)`                                         |
| `value?`                       | `(value ~= nil)`                                  |
| `class Dog extends Animal`    | metatable + `__index` chain                       |
| `super(args)`                  | `Parent.method(self, args)`                       |
| `data \|> f() \|> g()`        | `g(f(data))`                                       |
| `obj?.prop`                    | nil-safe property access                           |
| `x ?? y`                      | `if x ~= nil then x else y` (preserves `false`)   |
| `for i in 1..5`               | `for i = 1, 5 do`                                  |
| `for i in 1..<5`              | `for i = 1, 4 do`                                  |
| `"""multi\nline"""`           | triple-quoted multi-line string                    |
| `{ name, age }`               | `{name = name, age = age}`                         |

---

*Breeze v0.5.0 — targeting Lua 5.1*
