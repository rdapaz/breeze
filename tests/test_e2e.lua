-- Breeze End-to-End Test Suite
-- Tests that compile AND execute Breeze code, verifying runtime results.
-- Relies on test runner globals: describe, it, assert_eq, assert_match,
-- assert_contains, assert_error, assert_truthy, assert_type, Breeze

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function run_and_capture(source)
  local code = Breeze.transpile(source, "<test>")
  local fn, err = loadstring(code, "<test>")
  if not fn then error("Compile error: " .. tostring(err) .. "\nCode:\n" .. code) end
  local old_print = print
  local output = {}
  print = function(...)
    local args = {...}
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts+1] = tostring(args[i]) end
    output[#output+1] = table.concat(parts, "\t")
  end
  local ok, result = pcall(fn)
  print = old_print
  if not ok then error("Runtime error: " .. tostring(result) .. "\nCode:\n" .. code) end
  return output, result
end

local function run_code(source)
  local code = Breeze.transpile(source, "<test>")
  local fn, err = loadstring(code, "<test>")
  if not fn then error("Compile error: " .. tostring(err) .. "\nCode:\n" .. code) end
  local ok, result = pcall(fn)
  if not ok then error("Runtime error: " .. tostring(result) .. "\nCode:\n" .. code) end
  return result
end

------------------------------------------------------------------------
-- 1. Arithmetic & Arrow Functions
------------------------------------------------------------------------

describe("Arithmetic & Arrow Functions", function()

  it("defines and calls a square function", function()
    local output = run_and_capture([=[
square = (x) -> x * x
print(square(5))
]=])
    assert_eq(output[1], "25")
  end)

  it("handles basic arithmetic operations", function()
    local output = run_and_capture([=[
print(2 + 3)
print(10 - 4)
print(3 * 7)
print(10 / 2)
print(10 % 3)
print(2 ^ 8)
]=])
    assert_eq(output[1], "5")
    assert_eq(output[2], "6")
    assert_eq(output[3], "21")
    assert_eq(output[4], "5")
    assert_eq(output[5], "1")
    assert_eq(output[6], "256")
  end)

  it("supports multi-line arrow functions with implicit return", function()
    local output = run_and_capture([=[
add_and_double = (a, b) ->
  sum = a + b
  sum * 2
print(add_and_double(3, 4))
]=])
    assert_eq(output[1], "14")
  end)

  it("supports no-arg arrow functions", function()
    local output = run_and_capture([=[
greet = -> "hello!"
print(greet())
]=])
    assert_eq(output[1], "hello!")
  end)

end)

------------------------------------------------------------------------
-- 2. String Interpolation
------------------------------------------------------------------------

describe("String Interpolation", function()

  it("interpolates a variable into a double-quoted string", function()
    local output = run_and_capture([=[
name = "World"
print("Hello #{name}!")
]=])
    assert_eq(output[1], "Hello World!")
  end)

  it("interpolates expressions", function()
    local output = run_and_capture([=[
print("2 + 2 = #{2 + 2}")
]=])
    assert_eq(output[1], "2 + 2 = 4")
  end)

  it("does not interpolate single-quoted strings", function()
    local output = run_and_capture([=[
print('no #{interpolation}')
]=])
    assert_eq(output[1], 'no #{interpolation}')
  end)

end)

------------------------------------------------------------------------
-- 3. List Comprehensions
------------------------------------------------------------------------

describe("List Comprehensions", function()

  it("doubles each element", function()
    local output = run_and_capture([=[
doubles = [n * 2 for n in [1, 2, 3]]
for item in doubles
  print(item)
]=])
    assert_eq(output[1], "2")
    assert_eq(output[2], "4")
    assert_eq(output[3], "6")
  end)

  it("filters with an if guard", function()
    local output = run_and_capture([=[
evens = [x for x in [1, 2, 3, 4, 5, 6] if x % 2 == 0]
for item in evens
  print(item)
]=])
    assert_eq(output[1], "2")
    assert_eq(output[2], "4")
    assert_eq(output[3], "6")
  end)

  it("transforms and filters combined", function()
    local output = run_and_capture([=[
big_squares = [x * x for x in [1, 2, 3, 4, 5, 6, 7] if x > 4]
for item in big_squares
  print(item)
]=])
    assert_eq(output[1], "25")
    assert_eq(output[2], "36")
    assert_eq(output[3], "49")
  end)

end)

------------------------------------------------------------------------
-- 4. For Loops
------------------------------------------------------------------------

describe("For Loops", function()

  it("iterates values with for..in", function()
    local output = run_and_capture([=[
for item in [10, 20, 30]
  print(item)
]=])
    assert_eq(output[1], "10")
    assert_eq(output[2], "20")
    assert_eq(output[3], "30")
  end)

  it("iterates with index using for i, item in", function()
    local output = run_and_capture([=[
for i, item in [10, 20, 30]
  print(i, item)
]=])
    assert_eq(output[1], "1\t10")
    assert_eq(output[2], "2\t20")
    assert_eq(output[3], "3\t30")
  end)

  it("iterates pairs with for..of", function()
    local output = run_and_capture([=[
data = {x: 10}
for key, value of data
  print(key, value)
]=])
    assert_eq(output[1], "x\t10")
  end)

  it("supports numeric for with start, end", function()
    local output = run_and_capture([=[
for i = 1, 4
  print(i)
]=])
    assert_eq(#output, 4)
    assert_eq(output[1], "1")
    assert_eq(output[4], "4")
  end)

end)

------------------------------------------------------------------------
-- 5. Classes
------------------------------------------------------------------------

describe("Classes", function()

  it("creates a class with constructor and methods", function()
    local output = run_and_capture([=[
class Animal
  constructor: (@name) ->
    @legs = 4

  speak: ->
    "#{@name} speaks"

  get_legs: ->
    @legs

a = new Animal("Rex")
print(a:speak())
print(a:get_legs())
]=])
    assert_eq(output[1], "Rex speaks")
    assert_eq(output[2], "4")
  end)

  it("supports @ parameter auto-assignment in constructors", function()
    local output = run_and_capture([=[
class Point
  constructor: (@x, @y) ->
    @z = 0

p = new Point(3, 7)
print(p.x, p.y)
]=])
    assert_eq(output[1], "3\t7")
  end)

end)

------------------------------------------------------------------------
-- 6. Inheritance & Super
------------------------------------------------------------------------

describe("Inheritance & Super", function()

  it("child class inherits parent methods", function()
    local output = run_and_capture([=[
class Animal
  constructor: (@name) ->
    @sound = "..."

  speak: ->
    "#{@name} says #{@sound}"

class Dog extends Animal
  constructor: (@name) ->
    @sound = "Woof!"

d = new Dog("Rex")
print(d:speak())
]=])
    assert_eq(output[1], "Rex says Woof!")
  end)

  it("super() calls parent constructor", function()
    local output = run_and_capture([=[
class Base
  constructor: (@value) ->
    @ready = true

  get_value: ->
    @value

class Child extends Base
  constructor: (v) =>
    super(v * 10)

c = new Child(5)
print(c:get_value())
]=])
    assert_eq(output[1], "50")
  end)

  it("super() calls parent method from overridden method", function()
    local output = run_and_capture([=[
class Animal
  constructor: (@name) ->
    @sound = "..."

  speak: ->
    "#{@name} says #{@sound}"

class Dog extends Animal
  constructor: (@name) ->
    @sound = "Woof!"

  speak: =>
    parent_says = super()
    parent_says .. " (LOUDER)"

d = new Dog("Rex")
print(d:speak())
]=])
    assert_eq(output[1], "Rex says Woof! (LOUDER)")
  end)

end)

------------------------------------------------------------------------
-- 7. Safe Navigation
------------------------------------------------------------------------

describe("Safe Navigation", function()

  it("returns nil when navigating through nil", function()
    local output = run_and_capture([=[
x = nil
result = x?.foo
print(result)
]=])
    assert_eq(output[1], "nil")
  end)

  it("returns the field value when object exists", function()
    local output = run_and_capture([=[
obj = {foo: "bar"}
result = obj?.foo
print(result)
]=])
    assert_eq(output[1], "bar")
  end)

  it("chains safe navigation through nested objects", function()
    local output = run_and_capture([=[
user = { profile: { address: { city: "Melbourne" } } }
print(user?.profile?.address?.city)

nobody = nil
print(nobody?.profile?.address?.city)
]=])
    assert_eq(output[1], "Melbourne")
    assert_eq(output[2], "nil")
  end)

end)

------------------------------------------------------------------------
-- 8. Null Coalescing (??)
------------------------------------------------------------------------

describe("Null Coalescing (??)", function()

  it("returns default when left is nil", function()
    local output = run_and_capture([=[
x = nil
result = x ?? "default"
print(result)
]=])
    assert_eq(output[1], "default")
  end)

  it("preserves false (unlike or)", function()
    local output = run_and_capture([=[
flag = false
result = flag ?? true
print(result)
]=])
    assert_eq(output[1], "false")
  end)

  it("returns left when left is not nil", function()
    local output = run_and_capture([=[
val = 42
result = val ?? 0
print(result)
]=])
    assert_eq(output[1], "42")
  end)

  it("chains multiple defaults", function()
    local output = run_and_capture([=[
a = nil
b = nil
c = "found"
result = a ?? b ?? c
print(result)
]=])
    assert_eq(output[1], "found")
  end)

end)

------------------------------------------------------------------------
-- 9. Pipeline Operator
------------------------------------------------------------------------

describe("Pipeline Operator", function()

  it("pipes value as first argument to function", function()
    local output = run_and_capture([=[
double = (x) -> x * 2
result = 5 |> double()
print(result)
]=])
    assert_eq(output[1], "10")
  end)

  it("chains multiple pipeline stages", function()
    local output = run_and_capture([=[
double = (x) -> x * 2
add_one = (x) -> x + 1
result = 5 |> double() |> add_one()
print(result)
]=])
    assert_eq(output[1], "11")
  end)

  it("pipes with additional arguments", function()
    local output = run_and_capture([=[
add = (a, b) -> a + b
result = 10 |> add(5)
print(result)
]=])
    assert_eq(output[1], "15")
  end)

end)

------------------------------------------------------------------------
-- 10. Switch / When
------------------------------------------------------------------------

describe("Switch / When", function()

  it("matches the correct when branch", function()
    local output = run_and_capture([=[
check = (day) ->
  switch day
    when "monday"
      "Weekday"
    when "saturday", "sunday"
      "Weekend"
    else
      "Unknown"

print(check("monday"))
print(check("sunday"))
print(check("xyz"))
]=])
    assert_eq(output[1], "Weekday")
    assert_eq(output[2], "Weekend")
    assert_eq(output[3], "Unknown")
  end)

  it("matches numeric values", function()
    local output = run_and_capture([=[
x = 2
switch x
  when 1
    print("one")
  when 2
    print("two")
  else
    print("other")
]=])
    assert_eq(output[1], "two")
  end)

end)

------------------------------------------------------------------------
-- 11. Try / Catch / Finally
------------------------------------------------------------------------

describe("Try / Catch / Finally", function()

  it("catches an error", function()
    local output = run_and_capture([=[
try
  error("oops")
catch err
  print("caught")
]=])
    assert_eq(output[1], "caught")
  end)

  it("runs finally block after catch", function()
    local output = run_and_capture([=[
try
  error("oops")
catch err
  print("caught")
finally
  print("done")
]=])
    assert_eq(output[1], "caught")
    assert_eq(output[2], "done")
  end)

  it("runs finally when no error occurs", function()
    local output = run_and_capture([=[
try
  print("ok")
catch err
  print("caught")
finally
  print("done")
]=])
    assert_eq(output[1], "ok")
    assert_eq(output[2], "done")
  end)

end)

------------------------------------------------------------------------
-- 12. Existential Operator
------------------------------------------------------------------------

describe("Existential Operator", function()

  it("nil? is false", function()
    local output = run_and_capture([=[
x = nil
if x?
  print("exists")
else
  print("nil")
]=])
    assert_eq(output[1], "nil")
  end)

  it("42? is true", function()
    local output = run_and_capture([=[
x = 42
if x?
  print("exists")
else
  print("nil")
]=])
    assert_eq(output[1], "exists")
  end)

  it("false? is true (false is not nil)", function()
    local output = run_and_capture([=[
x = false
if x?
  print("exists")
else
  print("nil")
]=])
    assert_eq(output[1], "exists")
  end)

end)

------------------------------------------------------------------------
-- 13. Default Parameters
------------------------------------------------------------------------

describe("Default Parameters", function()

  it("uses default when argument is omitted", function()
    local output = run_and_capture([=[
greet = (name, greeting = "Hello") ->
  "#{greeting}, #{name}!"

print(greet("Alice"))
]=])
    assert_eq(output[1], "Hello, Alice!")
  end)

  it("uses provided value when given", function()
    local output = run_and_capture([=[
greet = (name, greeting = "Hello") ->
  "#{greeting}, #{name}!"

print(greet("Bob", "Hi"))
]=])
    assert_eq(output[1], "Hi, Bob!")
  end)

  it("supports multiple default parameters", function()
    local output = run_and_capture([=[
make = (x = 1, y = 2, z = 3) ->
  x + y + z

print(make())
print(make(10))
print(make(10, 20))
print(make(10, 20, 30))
]=])
    assert_eq(output[1], "6")
    assert_eq(output[2], "15")
    assert_eq(output[3], "33")
    assert_eq(output[4], "60")
  end)

end)

------------------------------------------------------------------------
-- 14. Compound Assignment
------------------------------------------------------------------------

describe("Compound Assignment", function()

  it("+= adds to existing value", function()
    local output = run_and_capture([=[
x = 10
x += 5
print(x)
]=])
    assert_eq(output[1], "15")
  end)

  it("-= subtracts from existing value", function()
    local output = run_and_capture([=[
x = 10
x -= 3
print(x)
]=])
    assert_eq(output[1], "7")
  end)

  it("*= multiplies existing value", function()
    local output = run_and_capture([=[
x = 10
x *= 4
print(x)
]=])
    assert_eq(output[1], "40")
  end)

  it("/= divides existing value", function()
    local output = run_and_capture([=[
x = 20
x /= 4
print(x)
]=])
    assert_eq(output[1], "5")
  end)

  it("..= concatenates strings", function()
    local output = run_and_capture([=[
msg = "hello"
msg ..= " world"
print(msg)
]=])
    assert_eq(output[1], "hello world")
  end)

end)

------------------------------------------------------------------------
-- 15. Unless / Until
------------------------------------------------------------------------

describe("Unless / Until", function()

  it("unless executes when condition is false", function()
    local output = run_and_capture([=[
unless false
  print("executed")
]=])
    assert_eq(output[1], "executed")
  end)

  it("unless does not execute when condition is true", function()
    local output = run_and_capture([=[
unless true
  print("should not run")
print("done")
]=])
    assert_eq(#output, 1)
    assert_eq(output[1], "done")
  end)

  it("until loops while condition is false", function()
    local output = run_and_capture([=[
count = 0
until count == 3
  count += 1
print(count)
]=])
    assert_eq(output[1], "3")
  end)

end)

------------------------------------------------------------------------
-- 16. Postfix Conditionals
------------------------------------------------------------------------

describe("Postfix Conditionals", function()

  it("executes statement when postfix if is true", function()
    local output = run_and_capture([=[
print("yes") if true
]=])
    assert_eq(output[1], "yes")
  end)

  it("does not execute statement when postfix if is false", function()
    local output = run_and_capture([=[
print("no") if false
print("done")
]=])
    assert_eq(#output, 1)
    assert_eq(output[1], "done")
  end)

  it("postfix unless executes when condition is false", function()
    local output = run_and_capture([=[
print("yes") unless false
]=])
    assert_eq(output[1], "yes")
  end)

  it("postfix unless does not execute when condition is true", function()
    local output = run_and_capture([=[
print("no") unless true
print("done")
]=])
    assert_eq(#output, 1)
    assert_eq(output[1], "done")
  end)

end)

------------------------------------------------------------------------
-- 17. Ranges
------------------------------------------------------------------------

describe("Ranges", function()

  it("inclusive range 1..3 iterates 1, 2, 3", function()
    local output = run_and_capture([=[
for i in 1..3
  print(i)
]=])
    assert_eq(#output, 3)
    assert_eq(output[1], "1")
    assert_eq(output[2], "2")
    assert_eq(output[3], "3")
  end)

  it("exclusive range 1..<3 iterates 1, 2", function()
    local output = run_and_capture([=[
for i in 1..<3
  print(i)
]=])
    assert_eq(#output, 2)
    assert_eq(output[1], "1")
    assert_eq(output[2], "2")
  end)

  it("range with step 0..6 by 2 iterates 0, 2, 4, 6", function()
    local output = run_and_capture([=[
for i in 0..6 by 2
  print(i)
]=])
    assert_eq(#output, 4)
    assert_eq(output[1], "0")
    assert_eq(output[2], "2")
    assert_eq(output[3], "4")
    assert_eq(output[4], "6")
  end)

  it("range in list comprehension", function()
    local output = run_and_capture([=[
squares = [i * i for i in 1..5]
for v in squares
  print(v)
]=])
    assert_eq(output[1], "1")
    assert_eq(output[2], "4")
    assert_eq(output[3], "9")
    assert_eq(output[4], "16")
    assert_eq(output[5], "25")
  end)

end)

------------------------------------------------------------------------
-- 18. Typeof
------------------------------------------------------------------------

describe("Typeof", function()

  it("returns 'number' for a number", function()
    local output = run_and_capture([=[
print(typeof 42)
]=])
    assert_eq(output[1], "number")
  end)

  it("returns 'string' for a string", function()
    local output = run_and_capture([=[
print(typeof "hi")
]=])
    assert_eq(output[1], "string")
  end)

  it("returns 'boolean' for a boolean", function()
    local output = run_and_capture([=[
print(typeof true)
]=])
    assert_eq(output[1], "boolean")
  end)

  it("returns 'table' for a table", function()
    local output = run_and_capture([=[
print(typeof {})
]=])
    assert_eq(output[1], "table")
  end)

  it("returns 'nil' for nil", function()
    local output = run_and_capture([=[
print(typeof nil)
]=])
    assert_eq(output[1], "nil")
  end)

end)

------------------------------------------------------------------------
-- 19. Tables / Object Literals
------------------------------------------------------------------------

describe("Tables / Object Literals", function()

  it("creates a table with key: value syntax", function()
    local output = run_and_capture([=[
obj = {a: 1, b: 2, c: 3}
print(obj.a, obj.b, obj.c)
]=])
    assert_eq(output[1], "1\t2\t3")
  end)

  it("creates an array with bracket syntax", function()
    local output = run_and_capture([=[
arr = [10, 20, 30]
print(arr[1], arr[2], arr[3])
]=])
    assert_eq(output[1], "10\t20\t30")
  end)

  it("supports shorthand properties", function()
    local output = run_and_capture([=[
name = "Alice"
age = 30
person = { name, age, active: true }
print(person.name, person.age, person.active)
]=])
    assert_eq(output[1], "Alice\t30\ttrue")
  end)

  it("supports empty array", function()
    local output = run_and_capture([=[
arr = []
print(#arr)
]=])
    assert_eq(output[1], "0")
  end)

end)

------------------------------------------------------------------------
-- 20. Multi-line Strings
------------------------------------------------------------------------

describe("Multi-line Strings", function()

  it("double triple-quotes produce multi-line with interpolation", function()
    local output = run_and_capture([=[
name = "World"
msg = """
Hello #{name}!
Welcome.
"""
print(msg)
]=])
    assert_eq(output[1], "Hello World!\nWelcome.\n")
  end)

  it("single triple-quotes produce raw text without interpolation", function()
    local output = run_and_capture([=[
raw = '''
No #{interp} here.
Just text.
'''
print(raw)
]=])
    assert_eq(output[1], "No #{interp} here.\nJust text.")
  end)

end)

------------------------------------------------------------------------
-- 21. Import / Export
------------------------------------------------------------------------

describe("Import / Export", function()

  it("destructured import from a standard module works", function()
    local output = run_and_capture([=[
import {insert, concat} from "table"
arr = {}
insert(arr, "hello")
insert(arr, "world")
print(concat(arr, " "))
]=])
    assert_eq(output[1], "hello world")
  end)

  it("export produces a return table", function()
    local code = Breeze.transpile([=[
export x = 42
export y = "hello"
]=], "<test>")
    -- The compiled code should end with a return table
    assert_contains(code, "return {")
    -- Execute it and check the returned module table
    local fn = loadstring(code, "<test>")
    local mod = fn()
    assert_type(mod, "table")
    assert_eq(mod.x, 42)
    assert_eq(mod.y, "hello")
  end)

end)

------------------------------------------------------------------------
-- 22. Do Blocks
------------------------------------------------------------------------

describe("Do Blocks", function()

  it("evaluates and returns the last expression", function()
    local output = run_and_capture([=[
result = do
  x = 10
  y = 20
  x + y
print(result)
]=])
    assert_eq(output[1], "30")
  end)

  it("scopes variables inside the do block", function()
    local output = run_and_capture([=[
result = do
  temp = 100
  temp * 2
print(result)
]=])
    assert_eq(output[1], "200")
  end)

end)

------------------------------------------------------------------------
-- 23. Fibonacci (Real Program Test)
------------------------------------------------------------------------

describe("Fibonacci", function()

  it("computes fibonacci recursively", function()
    local output = run_and_capture([=[
fibonacci = (n) ->
  if n <= 1
    n
  else
    fibonacci(n - 1) + fibonacci(n - 2)

print(fibonacci(0))
print(fibonacci(1))
print(fibonacci(5))
print(fibonacci(10))
]=])
    assert_eq(output[1], "0")
    assert_eq(output[2], "1")
    assert_eq(output[3], "5")
    assert_eq(output[4], "55")
  end)

  it("computes fibonacci iteratively", function()
    local output = run_and_capture([=[
fib_iter = (n) ->
  if n <= 1
    n
  else
    a = 0
    b = 1
    for i in 2..n
      temp = b
      b = a + b
      a = temp
    b

print(fib_iter(0))
print(fib_iter(1))
print(fib_iter(10))
print(fib_iter(20))
]=])
    assert_eq(output[1], "0")
    assert_eq(output[2], "1")
    assert_eq(output[3], "55")
    assert_eq(output[4], "6765")
  end)

end)

------------------------------------------------------------------------
-- 24. @ Shorthand in Classes
------------------------------------------------------------------------

describe("@ Shorthand", function()

  it("@field reads and writes self.field", function()
    local output = run_and_capture([=[
class Counter
  constructor: ->
    @count = 0

  increment: ->
    @count += 1
    @count

c = new Counter()
print(c:increment())
print(c:increment())
print(c:increment())
]=])
    assert_eq(output[1], "1")
    assert_eq(output[2], "2")
    assert_eq(output[3], "3")
  end)

  it("@ parameters auto-assign to self in constructor", function()
    local output = run_and_capture([=[
class Rect
  constructor: (@width, @height) ->
    @label = "rect"

  area: ->
    @width * @height

r = new Rect(5, 10)
print(r:area())
print(r.width, r.height)
]=])
    assert_eq(output[1], "50")
    assert_eq(output[2], "5\t10")
  end)

  it("fat arrow methods preserve self through @", function()
    local output = run_and_capture([=[
class Timer
  constructor: (@name) ->
    @elapsed = 0

  tick: =>
    @elapsed += 1
    @elapsed

t = new Timer("t1")
print(t:tick())
print(t:tick())
print(t.name)
]=])
    assert_eq(output[1], "1")
    assert_eq(output[2], "2")
    assert_eq(output[3], "t1")
  end)

end)

------------------------------------------------------------------------
-- Additional Coverage: Edge Cases & Combinations
------------------------------------------------------------------------

describe("Comparison Operators", function()

  it("!= compiles to ~=", function()
    local output = run_and_capture([=[
print(1 != 2)
print(1 != 1)
]=])
    assert_eq(output[1], "true")
    assert_eq(output[2], "false")
  end)

  it("supports ! as not", function()
    local output = run_and_capture([=[
print(!true)
print(!false)
]=])
    assert_eq(output[1], "false")
    assert_eq(output[2], "true")
  end)

end)

describe("String Concatenation", function()

  it(".. concatenates strings", function()
    local output = run_and_capture([=[
result = "hello" .. " " .. "world"
print(result)
]=])
    assert_eq(output[1], "hello world")
  end)

end)

describe("While Loop", function()

  it("loops while condition is true", function()
    local output = run_and_capture([=[
i = 0
while i < 5
  i += 1
print(i)
]=])
    assert_eq(output[1], "5")
  end)

end)

describe("Safe Navigation with Default Operator", function()

  it("combines ?. and ?? for fallback values", function()
    local output = run_and_capture([=[
config = nil
theme = config?.ui?.theme ?? "dark"
print(theme)
]=])
    assert_eq(output[1], "dark")
  end)

  it("returns real value when chain is valid", function()
    local output = run_and_capture([=[
config = { ui: { theme: "light" } }
theme = config?.ui?.theme ?? "dark"
print(theme)
]=])
    assert_eq(output[1], "light")
  end)

end)

describe("Complex Class Hierarchy", function()

  it("multi-level inheritance works", function()
    local output = run_and_capture([=[
class Shape
  constructor: (@kind) ->
    @id = 0

  describe: ->
    "I am a #{@kind}"

class Polygon extends Shape
  constructor: (@kind, @sides) ->
    @id = 0

  info: ->
    "#{@kind} with #{@sides} sides"

class Triangle extends Polygon
  constructor: ->
    @kind = "triangle"
    @sides = 3

t = new Triangle()
print(t:describe())
print(t:info())
]=])
    assert_eq(output[1], "I am a triangle")
    assert_eq(output[2], "triangle with 3 sides")
  end)

end)

describe("Nested Function Calls", function()

  it("functions as arguments work correctly", function()
    local output = run_and_capture([=[
double = (x) -> x * 2
inc = (x) -> x + 1
print(double(inc(4)))
]=])
    assert_eq(output[1], "10")
  end)

end)

describe("Length Operator", function()

  it("#array returns length", function()
    local output = run_and_capture([=[
arr = [1, 2, 3, 4, 5]
print(#arr)
]=])
    assert_eq(output[1], "5")
  end)

end)

describe("Return Statement", function()

  it("explicit return works in functions", function()
    local output = run_and_capture([=[
find = (list, target) ->
  for item in list
    if item == target
      return true
  false

print(find([1, 2, 3], 2))
print(find([1, 2, 3], 5))
]=])
    assert_eq(output[1], "true")
    assert_eq(output[2], "false")
  end)

end)

describe("Transpile Error Handling", function()

  it("reports compile errors for invalid syntax", function()
    assert_error(function()
      Breeze.transpile("class", "<test>")
    end)
  end)

end)
