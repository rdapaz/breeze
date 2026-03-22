-- Breeze Compiler / Emitter Tests
-- Verifies that Breeze.transpile() produces expected Lua output patterns.

--------------------------------------------------------------------------------
-- Helper: transpile and return the Lua string
--------------------------------------------------------------------------------
local function t(src)
  return Breeze.transpile(src)
end

--------------------------------------------------------------------------------
-- 1. Variables
--------------------------------------------------------------------------------
describe("Variables", function()
  it("declares a new variable with local", function()
    local out = t("x = 42")
    assert_contains(out, "local x = 42")
  end)

  it("does not re-declare an already assigned variable", function()
    local out = t("x = 1\nx = 2")
    -- First assignment gets local
    assert_contains(out, "local x = 1")
    -- Second should NOT have 'local'
    assert_match(out, "x = 2")
    -- Count occurrences of 'local x'
    local _, count = out:gsub("local x", "")
    assert_eq(count, 1, "should only declare local once")
  end)

  it("handles multiple distinct variables", function()
    local out = t("a = 1\nb = 2")
    assert_contains(out, "local a = 1")
    assert_contains(out, "local b = 2")
  end)
end)

--------------------------------------------------------------------------------
-- 2. Arrow Functions (thin arrow)
--------------------------------------------------------------------------------
describe("Arrow Functions", function()
  it("produces function() for arrow", function()
    local out = t("f = (x) -> x * 2")
    assert_contains(out, "function(x)")
  end)

  it("produces implicit return for single-expression body", function()
    local out = t("f = (x) -> x * 2")
    assert_contains(out, "return")
    assert_match(out, "x %* 2")
  end)

  it("handles no-param arrow", function()
    local out = t("f = () -> 42")
    assert_contains(out, "function()")
    assert_contains(out, "return 42")
  end)

  it("handles multi-param arrow", function()
    local out = t("f = (a, b) -> a + b")
    assert_contains(out, "function(a, b)")
  end)
end)

--------------------------------------------------------------------------------
-- 3. Fat Arrow Functions
--------------------------------------------------------------------------------
describe("Fat Arrow Functions", function()
  it("includes self as first parameter", function()
    local out = t("f = (x) => x")
    assert_contains(out, "function(self, x)")
  end)

  it("compiles @field to self.field in body", function()
    local out = t("f = () => @name")
    assert_contains(out, "self")
    assert_contains(out, "self.name")
  end)
end)

--------------------------------------------------------------------------------
-- 4. String Interpolation
--------------------------------------------------------------------------------
describe("String Interpolation", function()
  it("produces tostring() and concatenation", function()
    local out = t('x = "hello #{name}"')
    assert_contains(out, "tostring(")
    assert_contains(out, "..")
  end)

  it("wraps interpolated expression in tostring", function()
    local out = t('x = "val: #{1 + 2}"')
    assert_contains(out, "tostring(")
  end)
end)

--------------------------------------------------------------------------------
-- 5. Classes
--------------------------------------------------------------------------------
describe("Classes", function()
  it("produces __index for a basic class", function()
    local out = t("class Foo")
    assert_contains(out, "__index")
    assert_contains(out, "Foo")
  end)

  it("produces :new method", function()
    local out = t("class Foo")
    assert_contains(out, ":new(")
  end)

  it("produces setmetatable for a child class", function()
    local out = t("class Bar extends Foo")
    assert_contains(out, "setmetatable")
    assert_contains(out, "Foo")
  end)

  it("references parent in child :new", function()
    local out = t("class Bar extends Foo")
    assert_contains(out, "Foo:new(")
  end)
end)

--------------------------------------------------------------------------------
-- 6. Constructor @params
--------------------------------------------------------------------------------
describe("Constructor @params", function()
  it("assigns @param to self.param", function()
    local src = "class Foo\n  constructor: (@name) =>\n    return"
    local out = t(src)
    assert_contains(out, "self.name = name")
  end)

  it("includes the param name in the constructor signature", function()
    local src = "class Foo\n  constructor: (@name, @age) =>\n    return"
    local out = t(src)
    assert_contains(out, "self.name = name")
    assert_contains(out, "self.age = age")
  end)
end)

--------------------------------------------------------------------------------
-- 7. Safe Navigation
--------------------------------------------------------------------------------
describe("Safe Navigation", function()
  it("produces IIFE with nil check", function()
    local out = t("x = a?.b")
    assert_contains(out, "(function()")
    assert_contains(out, "== nil then return nil")
  end)

  it("accesses the field after nil check", function()
    local out = t("x = a?.b")
    assert_match(out, "%.b")
  end)
end)

--------------------------------------------------------------------------------
-- 8. Null Coalescing
--------------------------------------------------------------------------------
describe("Null Coalescing", function()
  it("produces _nn() call", function()
    local out = t("x = a ?? b")
    assert_contains(out, "_nn(a, b)")
  end)

  it("prepends the _nn helper function", function()
    local out = t("x = a ?? b")
    assert_contains(out, "local function _nn(")
  end)
end)

--------------------------------------------------------------------------------
-- 9. Pipeline
--------------------------------------------------------------------------------
describe("Pipeline", function()
  it("nests the left side into the function call", function()
    local out = t("x = val |> f()")
    assert_contains(out, "f(val)")
  end)

  it("handles chained pipelines", function()
    local out = t("x = val |> f() |> g()")
    assert_contains(out, "g(f(val))")
  end)
end)

--------------------------------------------------------------------------------
-- 10. Ranges
--------------------------------------------------------------------------------
describe("Ranges", function()
  it("produces numeric for with inclusive range", function()
    local out = t("for i in 1..5\n  print(i)")
    assert_contains(out, "for i = 1, 5 do")
  end)

  it("produces exclusive range with minus 1", function()
    local out = t("for i in 1..<5\n  print(i)")
    -- Should produce either (5 - 1) or 4 — check for the subtraction pattern
    assert_match(out, "5 %- 1")
  end)
end)

--------------------------------------------------------------------------------
-- 11. List Comprehensions
--------------------------------------------------------------------------------
describe("List Comprehensions", function()
  it("produces IIFE with _r accumulator", function()
    local out = t("x = [v * 2 for v in items]")
    assert_contains(out, "(function()")
    assert_contains(out, "local _r = {}")
    assert_contains(out, "_r[#_r + 1]")
  end)

  it("includes the iteration", function()
    local out = t("x = [v * 2 for v in items]")
    assert_contains(out, "ipairs(")
  end)
end)

--------------------------------------------------------------------------------
-- 12. For..in
--------------------------------------------------------------------------------
describe("For..in", function()
  it("produces ipairs() call", function()
    local out = t("for x in items\n  print(x)")
    assert_contains(out, "ipairs(")
    assert_contains(out, "items")
  end)
end)

--------------------------------------------------------------------------------
-- 13. For..of
--------------------------------------------------------------------------------
describe("For..of", function()
  it("produces pairs() call", function()
    local out = t("for k of obj\n  print(k)")
    assert_contains(out, "pairs(")
    assert_contains(out, "obj")
  end)
end)

--------------------------------------------------------------------------------
-- 14. Switch/When
--------------------------------------------------------------------------------
describe("Switch/When", function()
  it("produces if/elseif chain", function()
    local src = "switch x\n  when 1\n    print(1)\n  when 2\n    print(2)"
    local out = t(src)
    assert_contains(out, "if ")
    assert_contains(out, "elseif ")
  end)

  it("stores subject in _sw", function()
    local src = "switch x\n  when 1\n    print(1)"
    local out = t(src)
    assert_contains(out, "_sw")
  end)
end)

--------------------------------------------------------------------------------
-- 15. Try/Catch/Finally
--------------------------------------------------------------------------------
describe("Try/Catch/Finally", function()
  it("produces pcall wrapper", function()
    local src = "try\n  risky()\ncatch e\n  handle(e)"
    local out = t(src)
    assert_contains(out, "pcall(")
  end)

  it("assigns error to catch variable", function()
    local src = "try\n  risky()\ncatch e\n  handle(e)"
    local out = t(src)
    assert_contains(out, "_err")
    assert_contains(out, "not _ok")
  end)

  it("includes finally code unconditionally", function()
    local src = "try\n  risky()\ncatch e\n  handle(e)\nfinally\n  cleanup()"
    local out = t(src)
    assert_contains(out, "cleanup()")
  end)
end)

--------------------------------------------------------------------------------
-- 16. Postfix if
--------------------------------------------------------------------------------
describe("Postfix if", function()
  it("produces if-then-end wrapping the expression", function()
    local src = "print(x) if x > 0"
    local out = t(src)
    assert_match(out, "if.*then")
    assert_contains(out, "print(x)")
    assert_contains(out, "end")
  end)

  it("puts condition before the action", function()
    local out = t("print(x) if x > 0")
    assert_match(out, "if.+x > 0.+then")
  end)
end)

--------------------------------------------------------------------------------
-- 17. Unless
--------------------------------------------------------------------------------
describe("Unless", function()
  it("produces negated condition", function()
    local src = "unless done\n  work()"
    local out = t(src)
    assert_contains(out, "not")
    assert_contains(out, "done")
  end)

  it("wraps body in if block", function()
    local src = "unless done\n  work()"
    local out = t(src)
    assert_match(out, "if.*then")
    assert_contains(out, "work()")
  end)
end)

--------------------------------------------------------------------------------
-- 18. Until
--------------------------------------------------------------------------------
describe("Until", function()
  it("produces while not pattern", function()
    local src = "until done\n  work()"
    local out = t(src)
    assert_contains(out, "while")
    assert_contains(out, "not")
    assert_contains(out, "done")
  end)
end)

--------------------------------------------------------------------------------
-- 19. Compound Assignment
--------------------------------------------------------------------------------
describe("Compound Assignment", function()
  it("expands += to x = x + n", function()
    local out = t("x = 0\nx += 1")
    assert_contains(out, "x = (x + 1)")
  end)

  it("expands -= to x = x - n", function()
    local out = t("x = 0\nx -= 1")
    assert_contains(out, "x = (x - 1)")
  end)

  it("expands *= to x = x * n", function()
    local out = t("x = 1\nx *= 2")
    assert_contains(out, "x = (x * 2)")
  end)

  it("expands ..= for string concat", function()
    local out = t('s = "a"\ns ..= "b"')
    assert_contains(out, 's = (s .. "b")')
  end)
end)

--------------------------------------------------------------------------------
-- 20. Existential operator
--------------------------------------------------------------------------------
describe("Existential Operator", function()
  it("produces ~= nil check", function()
    local out = t("y = x?")
    assert_contains(out, "~= nil")
  end)
end)

--------------------------------------------------------------------------------
-- 21. Typeof
--------------------------------------------------------------------------------
describe("Typeof", function()
  it("produces type() call", function()
    local out = t("y = typeof x")
    assert_contains(out, "type(x)")
  end)
end)

--------------------------------------------------------------------------------
-- 22. Default Parameters
--------------------------------------------------------------------------------
describe("Default Parameters", function()
  it("produces nil check with default value", function()
    local out = t("f = (x = 5) -> x")
    assert_contains(out, "if x == nil then x = 5 end")
  end)

  it("handles multiple defaults", function()
    local out = t("f = (a = 1, b = 2) -> a + b")
    assert_contains(out, "if a == nil then a = 1 end")
    assert_contains(out, "if b == nil then b = 2 end")
  end)
end)

--------------------------------------------------------------------------------
-- 23. Do Blocks (expression IIFE)
--------------------------------------------------------------------------------
describe("Do Blocks", function()
  it("produces an IIFE", function()
    local out = t("x = do\n  42")
    assert_contains(out, "(function()")
    assert_contains(out, "end)()")
  end)
end)

--------------------------------------------------------------------------------
-- 24. Exports
--------------------------------------------------------------------------------
describe("Exports", function()
  it("produces a return table at the end", function()
    local out = t("export x = 1")
    assert_contains(out, "return {")
    assert_contains(out, "x = x")
  end)
end)

--------------------------------------------------------------------------------
-- 25. Import
--------------------------------------------------------------------------------
describe("Import", function()
  it("produces require call for single import", function()
    local out = t('import {a} from "mod"')
    assert_contains(out, 'require("mod")')
  end)

  it("produces require and destructure for multiple imports", function()
    local out = t('import {a, b} from "mod"')
    assert_contains(out, 'require("mod")')
    assert_contains(out, "local a = _m.a")
    assert_contains(out, "local b = _m.b")
  end)
end)

--------------------------------------------------------------------------------
-- 26. New
--------------------------------------------------------------------------------
describe("New", function()
  it("produces Class:new() call", function()
    local out = t("x = new Foo(1, 2)")
    assert_contains(out, "Foo:new(1, 2)")
  end)

  it("handles new with no args", function()
    local out = t("x = new Foo()")
    assert_contains(out, "Foo:new()")
  end)
end)

--------------------------------------------------------------------------------
-- 27. Super
--------------------------------------------------------------------------------
describe("Super", function()
  it("references parent class method", function()
    local src = "class Bar extends Foo\n  greet: () =>\n    super()"
    local out = t(src)
    assert_contains(out, "Foo.greet(self)")
  end)

  it("passes arguments through super", function()
    local src = "class Bar extends Foo\n  greet: (x) =>\n    super(x)"
    local out = t(src)
    assert_contains(out, "Foo.greet(self, x)")
  end)
end)
