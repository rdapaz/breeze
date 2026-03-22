-- Comprehensive lexer test suite for Breeze
-- Requires globals: Breeze, describe, it, assert_eq, assert_match, assert_contains, assert_error, assert_truthy, assert_type

-- Helper: filter out whitespace-structure tokens (NEWLINE, INDENT, DEDENT, EOF)
-- so we can focus on content tokens
local function content_tokens(tokens)
  local result = {}
  for _, tok in ipairs(tokens) do
    if tok.type ~= "NEWLINE" and tok.type ~= "INDENT" and tok.type ~= "DEDENT" and tok.type ~= "EOF" then
      result[#result + 1] = tok
    end
  end
  return result
end

-- Helper: get just the types of content tokens
local function content_types(tokens)
  local types = {}
  for _, tok in ipairs(content_tokens(tokens)) do
    types[#types + 1] = tok.type
  end
  return types
end

-- Helper: get just the values of content tokens
local function content_values(tokens)
  local values = {}
  for _, tok in ipairs(content_tokens(tokens)) do
    values[#values + 1] = tok.value
  end
  return values
end

-- Helper: get all token types including structural ones
local function all_types(tokens)
  local types = {}
  for _, tok in ipairs(tokens) do
    types[#types + 1] = tok.type
  end
  return types
end

--------------------------------------------------------------------------------
-- 1. Numbers
--------------------------------------------------------------------------------
describe("Lexer - Numbers", function()
  it("should lex integer literals", function()
    local tokens = Breeze.lex("42")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "NUMBER")
    assert_eq(ct[1].value, "42")
  end)

  it("should lex zero", function()
    local tokens = Breeze.lex("0")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "NUMBER")
    assert_eq(ct[1].value, "0")
  end)

  it("should lex float literals", function()
    local tokens = Breeze.lex("3.14")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "NUMBER")
    assert_eq(ct[1].value, "3.14")
  end)

  it("should lex float starting with dot", function()
    local tokens = Breeze.lex(".5")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "NUMBER")
    assert_eq(ct[1].value, ".5")
  end)

  it("should lex hexadecimal numbers", function()
    local tokens = Breeze.lex("0xFF")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "NUMBER")
    assert_eq(ct[1].value, "0xFF")
  end)

  it("should lex uppercase hex prefix", function()
    local tokens = Breeze.lex("0XAB")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "NUMBER")
    assert_eq(ct[1].value, "0XAB")
  end)

  it("should lex scientific notation", function()
    local tokens = Breeze.lex("1e10")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "NUMBER")
    assert_eq(ct[1].value, "1e10")
  end)

  it("should lex scientific notation with uppercase E", function()
    local tokens = Breeze.lex("2.5E3")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "NUMBER")
    assert_eq(ct[1].value, "2.5E3")
  end)

  it("should lex scientific notation with negative exponent", function()
    local tokens = Breeze.lex("2.5E-3")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "NUMBER")
    assert_eq(ct[1].value, "2.5E-3")
  end)

  it("should lex scientific notation with positive exponent sign", function()
    local tokens = Breeze.lex("1e+5")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "NUMBER")
    assert_eq(ct[1].value, "1e+5")
  end)

  it("should lex multiple numbers separated by operators", function()
    local tokens = Breeze.lex("1 + 2.5")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 3)
    assert_eq(ct[1].type, "NUMBER")
    assert_eq(ct[1].value, "1")
    assert_eq(ct[2].type, "+")
    assert_eq(ct[3].type, "NUMBER")
    assert_eq(ct[3].value, "2.5")
  end)
end)

--------------------------------------------------------------------------------
-- 2. Strings
--------------------------------------------------------------------------------
describe("Lexer - Strings", function()
  it("should lex single-quoted strings", function()
    local tokens = Breeze.lex("'hello'")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "STRING")
    assert_eq(ct[1].value, "hello")
  end)

  it("should lex double-quoted strings", function()
    local tokens = Breeze.lex('"world"')
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "STRING")
    assert_eq(ct[1].value, "world")
  end)

  it("should lex empty strings", function()
    local tokens = Breeze.lex("''")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "STRING")
    assert_eq(ct[1].value, "")
  end)

  it("should handle escape sequence \\n", function()
    local tokens = Breeze.lex('"hello\\nworld"')
    local ct = content_tokens(tokens)
    assert_eq(ct[1].value, "hello\nworld")
  end)

  it("should handle escape sequence \\t", function()
    local tokens = Breeze.lex('"a\\tb"')
    local ct = content_tokens(tokens)
    assert_eq(ct[1].value, "a\tb")
  end)

  it("should handle escape sequence \\\\", function()
    local tokens = Breeze.lex('"a\\\\b"')
    local ct = content_tokens(tokens)
    assert_eq(ct[1].value, "a\\b")
  end)

  it("should handle escaped quote inside double-quoted string", function()
    local tokens = Breeze.lex('"say \\"hi\\""')
    local ct = content_tokens(tokens)
    assert_eq(ct[1].value, 'say "hi"')
  end)

  it("should handle escaped quote inside single-quoted string", function()
    local tokens = Breeze.lex("'it\\'s'")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].value, "it's")
  end)

  it("should handle escape sequence \\r", function()
    local tokens = Breeze.lex('"a\\rb"')
    local ct = content_tokens(tokens)
    assert_eq(ct[1].value, "a\rb")
  end)

  it("should return table value for string interpolation", function()
    local tokens = Breeze.lex('"hello #{name}"')
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "STRING")
    assert_type(ct[1].value, "table")
    -- Should have two parts: str "hello " and expr "name"
    assert_eq(#ct[1].value, 2)
    assert_eq(ct[1].value[1].type, "str")
    assert_eq(ct[1].value[1].value, "hello ")
    assert_eq(ct[1].value[2].type, "expr")
    assert_eq(ct[1].value[2].value, "name")
  end)

  it("should handle interpolation at start of string", function()
    local tokens = Breeze.lex('"#{x} end"')
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "STRING")
    assert_type(ct[1].value, "table")
    -- First part is empty str, then expr, then str
    assert_eq(ct[1].value[1].type, "str")
    assert_eq(ct[1].value[1].value, "")
    assert_eq(ct[1].value[2].type, "expr")
    assert_eq(ct[1].value[2].value, "x")
    assert_eq(ct[1].value[3].type, "str")
    assert_eq(ct[1].value[3].value, " end")
  end)

  it("should handle multiple interpolations", function()
    local tokens = Breeze.lex('"#{a} and #{b}"')
    local ct = content_tokens(tokens)
    assert_type(ct[1].value, "table")
    local parts = ct[1].value
    -- str("") expr(a) str(" and ") expr(b)
    assert_eq(parts[1].type, "str")
    assert_eq(parts[2].type, "expr")
    assert_eq(parts[2].value, "a")
    assert_eq(parts[3].type, "str")
    assert_eq(parts[3].value, " and ")
    assert_eq(parts[4].type, "expr")
    assert_eq(parts[4].value, "b")
  end)

  it("should not interpolate in single-quoted strings", function()
    local tokens = Breeze.lex("'no #{interp}'")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "STRING")
    assert_type(ct[1].value, "string")
    assert_eq(ct[1].value, "no #{interp}")
  end)

  it("should handle escaped hash in double-quoted strings", function()
    local tokens = Breeze.lex('"no \\#{interp}"')
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "STRING")
    assert_type(ct[1].value, "string")
    assert_eq(ct[1].value, "no #{interp}")
  end)
end)

--------------------------------------------------------------------------------
-- 3. Triple-quoted strings
--------------------------------------------------------------------------------
describe("Lexer - Triple-quoted strings", function()
  it("should lex triple-double-quoted strings", function()
    local tokens = Breeze.lex('"""hello"""')
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "STRING")
    assert_eq(ct[1].value, "hello")
  end)

  it("should lex triple-single-quoted strings", function()
    local tokens = Breeze.lex("'''hello'''")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "STRING")
    assert_eq(ct[1].value, "hello")
  end)

  it("should handle newlines in triple-quoted strings", function()
    local tokens = Breeze.lex('"""line1\nline2"""')
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "STRING")
    assert_truthy(ct[1].value:find("line1"))
    assert_truthy(ct[1].value:find("line2"))
  end)

  it("should skip leading newline after opening triple-quote", function()
    local tokens = Breeze.lex('"""\nhello\n"""')
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "STRING")
    assert_eq(ct[1].value, "hello")
  end)

  it("should dedent triple-quoted strings", function()
    local src = '"""\n    line1\n    line2\n    """'
    local tokens = Breeze.lex(src)
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "STRING")
    assert_eq(ct[1].value, "line1\nline2")
  end)

  it("should handle interpolation in triple-double-quoted strings", function()
    local src = '"""hello #{name}"""'
    local tokens = Breeze.lex(src)
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "STRING")
    assert_type(ct[1].value, "table")
    -- Find the expr part
    local found_expr = false
    for _, part in ipairs(ct[1].value) do
      if part.type == "expr" and part.value == "name" then
        found_expr = true
      end
    end
    assert_truthy(found_expr)
  end)

  it("should not interpolate in triple-single-quoted strings", function()
    local src = "'''no #{interp}'''"
    local tokens = Breeze.lex(src)
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "STRING")
    assert_type(ct[1].value, "string")
    assert_truthy(ct[1].value:find("#{interp}"))
  end)
end)

--------------------------------------------------------------------------------
-- 4. Identifiers and keywords
--------------------------------------------------------------------------------
describe("Lexer - Identifiers and keywords", function()
  it("should lex simple identifiers", function()
    local tokens = Breeze.lex("foo")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].type, "IDENT")
    assert_eq(ct[1].value, "foo")
  end)

  it("should lex identifiers with underscores", function()
    local tokens = Breeze.lex("my_var")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "IDENT")
    assert_eq(ct[1].value, "my_var")
  end)

  it("should lex identifiers starting with underscore", function()
    local tokens = Breeze.lex("_private")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "IDENT")
    assert_eq(ct[1].value, "_private")
  end)

  it("should lex identifiers with digits", function()
    local tokens = Breeze.lex("x2")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "IDENT")
    assert_eq(ct[1].value, "x2")
  end)

  it("should map 'if' to IF", function()
    local tokens = Breeze.lex("if")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "if")
    assert_eq(ct[1].value, "if")
  end)

  it("should map 'else' to ELSE", function()
    local tokens = Breeze.lex("else")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "else")
  end)

  it("should map 'elseif' to ELSEIF", function()
    local tokens = Breeze.lex("elseif")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "elseif")
  end)

  it("should map 'class' to CLASS", function()
    local tokens = Breeze.lex("class")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "class")
  end)

  it("should map 'for' to FOR", function()
    local tokens = Breeze.lex("for")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "for")
  end)

  it("should map 'in' to IN", function()
    local tokens = Breeze.lex("in")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "in")
  end)

  it("should map 'of' to OF", function()
    local tokens = Breeze.lex("of")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "of")
  end)

  it("should map 'return' to RETURN", function()
    local tokens = Breeze.lex("return")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "return")
  end)

  it("should map 'true' and 'false' to BOOL", function()
    local tokens = Breeze.lex("true")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "BOOL")
    assert_eq(ct[1].value, "true")

    tokens = Breeze.lex("false")
    ct = content_tokens(tokens)
    assert_eq(ct[1].type, "BOOL")
    assert_eq(ct[1].value, "false")
  end)

  it("should map 'nil' to NIL", function()
    local tokens = Breeze.lex("nil")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "NIL")
  end)

  it("should map 'and', 'or', 'not' to their types", function()
    local tokens = Breeze.lex("and")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "and")

    tokens = Breeze.lex("or")
    ct = content_tokens(tokens)
    assert_eq(ct[1].type, "or")

    tokens = Breeze.lex("not")
    ct = content_tokens(tokens)
    assert_eq(ct[1].type, "not")
  end)

  it("should map all other keywords correctly", function()
    local keyword_tests = {
      {"while", "while"}, {"until", "until"}, {"unless", "unless"},
      {"break", "break"}, {"extends", "extends"}, {"new", "new"},
      {"super", "super"}, {"import", "import"}, {"from", "from"},
      {"export", "export"}, {"do", "do"}, {"switch", "switch"},
      {"when", "when"}, {"try", "try"}, {"catch", "catch"},
      {"finally", "finally"}, {"then", "then"}, {"typeof", "typeof"},
      {"by", "by"},
    }
    for _, pair in ipairs(keyword_tests) do
      local tokens = Breeze.lex(pair[1])
      local ct = content_tokens(tokens)
      assert_eq(ct[1].type, pair[2])
      assert_eq(ct[1].value, pair[1])
    end
  end)

  it("should not treat keyword prefixes as keywords", function()
    local tokens = Breeze.lex("iffy")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "IDENT")
    assert_eq(ct[1].value, "iffy")
  end)
end)

--------------------------------------------------------------------------------
-- 5. Operators
--------------------------------------------------------------------------------
describe("Lexer - Operators", function()
  it("should lex single-char operators", function()
    local tests = {
      {"+", "+"}, {"-", "-"}, {"*", "*"}, {"/", "/"},
      {"%", "%"}, {"^", "^"}, {".", "."}, {":", ":"},
      {"@", "@"}, {",", ","},
    }
    for _, pair in ipairs(tests) do
      -- wrap in expression context to avoid ambiguity
      local tokens = Breeze.lex("a " .. pair[1] .. " b")
      local ct = content_tokens(tokens)
      assert_eq(ct[2].type, pair[2])
    end
  end)

  it("should lex parentheses, brackets, braces", function()
    local tokens = Breeze.lex("([]{})")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "(")
    assert_eq(ct[2].type, "[")
    assert_eq(ct[3].type, "]")
    assert_eq(ct[4].type, "{")
    assert_eq(ct[5].type, "}")
    assert_eq(ct[6].type, ")")
  end)

  it("should lex comparison operators", function()
    local tokens = Breeze.lex("a == b")
    local ct = content_tokens(tokens)
    assert_eq(ct[2].type, "==")

    tokens = Breeze.lex("a != b")
    ct = content_tokens(tokens)
    assert_eq(ct[2].type, "!=")

    tokens = Breeze.lex("a <= b")
    ct = content_tokens(tokens)
    assert_eq(ct[2].type, "<=")

    tokens = Breeze.lex("a >= b")
    ct = content_tokens(tokens)
    assert_eq(ct[2].type, ">=")

    tokens = Breeze.lex("a < b")
    ct = content_tokens(tokens)
    assert_eq(ct[2].type, "<")

    tokens = Breeze.lex("a > b")
    ct = content_tokens(tokens)
    assert_eq(ct[2].type, ">")
  end)

  it("should lex arrow operators", function()
    local tokens = Breeze.lex("->")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "->")
    assert_eq(ct[1].value, "->")

    tokens = Breeze.lex("=>")
    ct = content_tokens(tokens)
    assert_eq(ct[1].type, "=>")
    assert_eq(ct[1].value, "=>")
  end)

  it("should lex pipe operator", function()
    local tokens = Breeze.lex("a |> b")
    local ct = content_tokens(tokens)
    assert_eq(ct[2].type, "|>")
  end)

  it("should lex safe navigation operators", function()
    local tokens = Breeze.lex("a?.b")
    local ct = content_tokens(tokens)
    assert_eq(ct[2].type, "?.")

    tokens = Breeze.lex("a?[0]")
    ct = content_tokens(tokens)
    assert_eq(ct[2].type, "?[")
  end)

  it("should lex nil coalescing operator", function()
    local tokens = Breeze.lex("a ?? b")
    local ct = content_tokens(tokens)
    assert_eq(ct[2].type, "??")
  end)

  it("should lex question mark alone", function()
    local tokens = Breeze.lex("a ? b")
    local ct = content_tokens(tokens)
    assert_eq(ct[2].type, "?")
  end)

  it("should lex range operator", function()
    local tokens = Breeze.lex("1 ..< 10")
    local ct = content_tokens(tokens)
    assert_eq(ct[2].type, "..<")
  end)

  it("should lex concat operator", function()
    local tokens = Breeze.lex("a .. b")
    local ct = content_tokens(tokens)
    assert_eq(ct[2].type, "..")
  end)

  it("should lex assignment operators", function()
    local tokens = Breeze.lex("a = b")
    local ct = content_tokens(tokens)
    assert_eq(ct[2].type, "=")

    local compound_ops = {
      {"a += b", "+="}, {"a -= b", "-="},
      {"a *= b", "*="}, {"a /= b", "/="},
      {"a ..= b", "..="}, {"a %= b", "%="},
    }
    for _, pair in ipairs(compound_ops) do
      tokens = Breeze.lex(pair[1])
      ct = content_tokens(tokens)
      assert_eq(ct[2].type, pair[2])
    end
  end)

  it("should lex varargs", function()
    local tokens = Breeze.lex("...")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "VARARGS")
    assert_eq(ct[1].value, "...")
  end)

  it("should lex ! as 'not'", function()
    local tokens = Breeze.lex("!x")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "not")
    assert_eq(ct[1].value, "not")
  end)
end)

--------------------------------------------------------------------------------
-- 6. Indentation
--------------------------------------------------------------------------------
describe("Lexer - Indentation", function()
  it("should emit INDENT for nested block", function()
    local src = "if true\n  x = 1"
    local tokens = Breeze.lex(src)
    local types = all_types(tokens)
    assert_truthy(table.concat(types, ","):find("INDENT"))
  end)

  it("should emit DEDENT when returning to previous level", function()
    local src = "if true\n  x = 1\ny = 2"
    local tokens = Breeze.lex(src)
    local types = all_types(tokens)
    local joined = table.concat(types, ",")
    assert_truthy(joined:find("INDENT"))
    assert_truthy(joined:find("DEDENT"))
  end)

  it("should handle multiple indent levels", function()
    local src = "a\n  b\n    c\nd"
    local tokens = Breeze.lex(src)
    local indent_count = 0
    local dedent_count = 0
    for _, tok in ipairs(tokens) do
      if tok.type == "INDENT" then indent_count = indent_count + 1 end
      if tok.type == "DEDENT" then dedent_count = dedent_count + 1 end
    end
    assert_eq(indent_count, 2)
    assert_eq(dedent_count, 2)
  end)

  it("should emit multiple DEDENTs when jumping back to zero", function()
    local src = "a\n  b\n    c\n      d\ne"
    local tokens = Breeze.lex(src)
    local indent_count = 0
    local dedent_count = 0
    for _, tok in ipairs(tokens) do
      if tok.type == "INDENT" then indent_count = indent_count + 1 end
      if tok.type == "DEDENT" then dedent_count = dedent_count + 1 end
    end
    assert_eq(indent_count, 3)
    assert_eq(dedent_count, 3)
  end)

  it("should emit trailing DEDENTs at end of input", function()
    local src = "a\n  b\n    c"
    local tokens = Breeze.lex(src)
    local dedent_count = 0
    for _, tok in ipairs(tokens) do
      if tok.type == "DEDENT" then dedent_count = dedent_count + 1 end
    end
    assert_eq(dedent_count, 2)
  end)
end)

--------------------------------------------------------------------------------
-- 7. Newlines
--------------------------------------------------------------------------------
describe("Lexer - Newlines", function()
  it("should emit NEWLINE between statements", function()
    local src = "a\nb"
    local tokens = Breeze.lex(src)
    local types = all_types(tokens)
    -- Expect: IDENT NEWLINE IDENT EOF
    assert_eq(types[1], "IDENT")
    assert_eq(types[2], "NEWLINE")
    assert_eq(types[3], "IDENT")
  end)

  it("should not emit NEWLINE inside parentheses", function()
    local src = "(\na\n)"
    local tokens = Breeze.lex(src)
    local has_newline = false
    for _, tok in ipairs(tokens) do
      if tok.type == "NEWLINE" then has_newline = true end
    end
    assert_eq(has_newline, false)
  end)

  it("should not emit NEWLINE inside brackets", function()
    local src = "[\na\n]"
    local tokens = Breeze.lex(src)
    local has_newline = false
    for _, tok in ipairs(tokens) do
      if tok.type == "NEWLINE" then has_newline = true end
    end
    assert_eq(has_newline, false)
  end)

  it("should not emit NEWLINE inside braces", function()
    local src = "{\na\n}"
    local tokens = Breeze.lex(src)
    local has_newline = false
    for _, tok in ipairs(tokens) do
      if tok.type == "NEWLINE" then has_newline = true end
    end
    assert_eq(has_newline, false)
  end)

  it("should not emit consecutive NEWLINEs", function()
    local src = "a\n\n\nb"
    local tokens = Breeze.lex(src)
    local prev_type = nil
    for _, tok in ipairs(tokens) do
      if tok.type == "NEWLINE" and prev_type == "NEWLINE" then
        error("consecutive NEWLINEs found")
      end
      prev_type = tok.type
    end
  end)

  it("should not emit NEWLINE after INDENT", function()
    local src = "if true\n  x"
    local tokens = Breeze.lex(src)
    for i = 1, #tokens - 1 do
      if tokens[i].type == "INDENT" then
        assert_truthy(tokens[i + 1].type ~= "NEWLINE")
      end
    end
  end)
end)

--------------------------------------------------------------------------------
-- 8. Comments
--------------------------------------------------------------------------------
describe("Lexer - Comments", function()
  it("should skip line comments", function()
    local src = "a # this is a comment\nb"
    local tokens = Breeze.lex(src)
    local ct = content_tokens(tokens)
    assert_eq(#ct, 2)
    assert_eq(ct[1].value, "a")
    assert_eq(ct[2].value, "b")
  end)

  it("should skip comment-only lines", function()
    local src = "# just a comment"
    local tokens = Breeze.lex(src)
    local ct = content_tokens(tokens)
    assert_eq(#ct, 0)
  end)

  it("should handle # as length operator in expression context", function()
    -- After [, #x should be length operator
    local tokens = Breeze.lex("a[#b]")
    local ct = content_tokens(tokens)
    -- a [ # b ]
    assert_eq(ct[1].type, "IDENT")
    assert_eq(ct[1].value, "a")
    assert_eq(ct[2].type, "[")
    assert_eq(ct[3].type, "#")
    assert_eq(ct[4].type, "IDENT")
    assert_eq(ct[4].value, "b")
    assert_eq(ct[5].type, "]")
  end)

  it("should treat # as length after assignment", function()
    local tokens = Breeze.lex("x = #arr")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "IDENT")
    assert_eq(ct[2].type, "=")
    assert_eq(ct[3].type, "#")
    assert_eq(ct[4].type, "IDENT")
    assert_eq(ct[4].value, "arr")
  end)

  it("should treat # as length after return", function()
    local tokens = Breeze.lex("return #arr")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "return")
    assert_eq(ct[2].type, "#")
    assert_eq(ct[3].type, "IDENT")
  end)

  it("should treat # as comment after identifier", function()
    local src = "x # comment"
    local tokens = Breeze.lex(src)
    local ct = content_tokens(tokens)
    assert_eq(#ct, 1)
    assert_eq(ct[1].value, "x")
  end)
end)

--------------------------------------------------------------------------------
-- 9. Edge cases
--------------------------------------------------------------------------------
describe("Lexer - Edge cases", function()
  it("should handle empty input", function()
    local tokens = Breeze.lex("")
    assert_eq(#tokens, 1)
    assert_eq(tokens[1].type, "EOF")
  end)

  it("should handle whitespace-only input", function()
    local tokens = Breeze.lex("   \t  ")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 0)
  end)

  it("should handle comment-only input", function()
    local tokens = Breeze.lex("# just a comment\n# another")
    local ct = content_tokens(tokens)
    assert_eq(#ct, 0)
  end)

  it("should always end with EOF", function()
    local tokens = Breeze.lex("x = 1")
    assert_eq(tokens[#tokens].type, "EOF")
  end)

  it("should error on unterminated double-quoted string", function()
    assert_error(function()
      Breeze.lex('"unterminated')
    end)
  end)

  it("should error on unterminated single-quoted string", function()
    assert_error(function()
      Breeze.lex("'unterminated")
    end)
  end)

  it("should error on unmatched opening paren", function()
    assert_error(function()
      Breeze.lex("(a + b")
    end)
  end)

  it("should error on unmatched opening bracket", function()
    assert_error(function()
      Breeze.lex("[1, 2")
    end)
  end)

  it("should error on unmatched opening brace", function()
    assert_error(function()
      Breeze.lex("{a: 1")
    end)
  end)

  it("should error on extra closing paren", function()
    assert_error(function()
      Breeze.lex("a + b)")
    end)
  end)

  it("should error on unexpected character", function()
    assert_error(function()
      Breeze.lex("a | b")
    end)
  end)

  it("should track line numbers", function()
    local tokens = Breeze.lex("a\nb\nc")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].line, 1)
    assert_eq(ct[2].line, 2)
    assert_eq(ct[3].line, 3)
  end)

  it("should track column numbers", function()
    local tokens = Breeze.lex("ab cd")
    local ct = content_tokens(tokens)
    -- col is captured at end of token read, so "ab" at col 3, "cd" at col 6
    assert_eq(ct[1].col, 3)
    assert_eq(ct[2].col, 6)
  end)

  it("should lex a complex expression", function()
    local tokens = Breeze.lex("x = (a + b) * c")
    local ct = content_tokens(tokens)
    local types = {}
    for _, tok in ipairs(ct) do types[#types + 1] = tok.type end
    assert_eq(types[1], "IDENT")   -- x
    assert_eq(types[2], "=")       -- =
    assert_eq(types[3], "(")       -- (
    assert_eq(types[4], "IDENT")   -- a
    assert_eq(types[5], "+")       -- +
    assert_eq(types[6], "IDENT")   -- b
    assert_eq(types[7], ")")       -- )
    assert_eq(types[8], "*")       -- *
    assert_eq(types[9], "IDENT")   -- c
  end)

  it("should handle tabs as 4 spaces for indentation", function()
    local src = "a\n\tb"
    local tokens = Breeze.lex(src)
    local has_indent = false
    for _, tok in ipairs(tokens) do
      if tok.type == "INDENT" then has_indent = true end
    end
    assert_truthy(has_indent)
  end)

  it("should lex the @ operator", function()
    local tokens = Breeze.lex("@field")
    local ct = content_tokens(tokens)
    assert_eq(ct[1].type, "@")
    assert_eq(ct[2].type, "IDENT")
    assert_eq(ct[2].value, "field")
  end)
end)
