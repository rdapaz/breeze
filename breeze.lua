#!/usr/bin/env lua
-- Breeze: A CoffeeScript-like language that compiles to Lua 5.1
-- Usage: lua breeze.lua [file.bz] or lua breeze.lua -e "code" or lua breeze.lua (REPL)

local Breeze = {}

--------------------------------------------------------------------------------
-- TOKEN TYPES
--------------------------------------------------------------------------------
local T = {
  NUMBER = "NUMBER", STRING = "STRING", IDENT = "IDENT",
  BOOL = "BOOL", NIL = "NIL", VARARGS = "VARARGS",
  PLUS = "+", MINUS = "-", STAR = "*", SLASH = "/",
  PERCENT = "%", CARET = "^", CONCAT = "..",
  EQ = "==", NEQ = "!=", LT = "<", GT = ">", LTE = "<=", GTE = ">=",
  ASSIGN = "=", PLUSEQ = "+=", MINUSEQ = "-=", STAREQ = "*=",
  SLASHEQ = "/=", CONCATEQ = "..=", PERCENTEQ = "%=",
  AND = "and", OR = "or", NOT = "not",
  DOT = ".", COLON = ":", HASH = "#", AT = "@", QMARK = "?",
  LPAREN = "(", RPAREN = ")", LBRACKET = "[", RBRACKET = "]",
  LBRACE = "{", RBRACE = "}", COMMA = ",",
  ARROW = "->", FATARROW = "=>",
  IF = "if", ELSE = "else", ELSEIF = "elseif", UNLESS = "unless",
  WHILE = "while", UNTIL = "until",
  FOR = "for", IN = "in", OF = "of",
  RETURN = "return", BREAK = "break",
  CLASS = "class", EXTENDS = "extends", NEW = "new",
  IMPORT = "import", FROM = "from", EXPORT = "export",
  DO = "do", SWITCH = "switch", WHEN = "when",
  TRY = "try", CATCH = "catch", FINALLY = "finally",
  THEN = "then", TYPEOF = "typeof",
  NEWLINE = "NEWLINE", INDENT = "INDENT", DEDENT = "DEDENT", EOF = "EOF",
}

local KEYWORDS = {
  ["if"]=T.IF, ["else"]=T.ELSE, ["elseif"]=T.ELSEIF, ["unless"]=T.UNLESS,
  ["while"]=T.WHILE, ["until"]=T.UNTIL, ["for"]=T.FOR, ["in"]=T.IN, ["of"]=T.OF,
  ["return"]=T.RETURN, ["break"]=T.BREAK, ["class"]=T.CLASS, ["extends"]=T.EXTENDS,
  ["new"]=T.NEW, ["import"]=T.IMPORT, ["from"]=T.FROM, ["export"]=T.EXPORT,
  ["and"]=T.AND, ["or"]=T.OR, ["not"]=T.NOT,
  ["true"]=T.BOOL, ["false"]=T.BOOL, ["nil"]=T.NIL,
  ["do"]=T.DO, ["switch"]=T.SWITCH, ["when"]=T.WHEN,
  ["try"]=T.TRY, ["catch"]=T.CATCH, ["finally"]=T.FINALLY,
  ["then"]=T.THEN, ["typeof"]=T.TYPEOF,
}

--------------------------------------------------------------------------------
-- LEXER
--------------------------------------------------------------------------------
function Breeze.lex(source, filename)
  filename = filename or "<input>"
  local tokens = {}
  local pos = 1
  local line = 1
  local col = 1
  local indent_stack = {0}
  local at_line_start = true
  local paren_depth = 0
  local arrow_indent_stack = {}  -- stack of base indent levels for nested arrow bodies inside parens

  local function char(offset)
    local i = pos + (offset or 0)
    if i > #source then return "" end
    return source:sub(i, i)
  end

  local function advance(n)
    for i = 1, (n or 1) do
      if pos <= #source then
        if source:sub(pos, pos) == "\n" then line = line + 1; col = 1
        else col = col + 1 end
        pos = pos + 1
      end
    end
  end

  local function emit(tp, val) tokens[#tokens+1] = {type=tp, value=val, line=line, col=col, file=filename} end
  local function err(msg) error(filename..":"..line..":"..col..": "..msg) end

  local function skip_comment()
    while pos <= #source and char() ~= "\n" do advance() end
  end

  local function read_string(quote)
    local sline = line
    advance() -- skip opening quote
    local parts, buf = {}, {}
    local is_interp = (quote == '"')

    while pos <= #source and char() ~= quote do
      if char() == "\\" then
        advance()
        local c = char()
        if c == "n" then buf[#buf+1] = "\n"
        elseif c == "t" then buf[#buf+1] = "\t"
        elseif c == "r" then buf[#buf+1] = "\r"
        elseif c == "\\" then buf[#buf+1] = "\\"
        elseif c == quote then buf[#buf+1] = quote
        elseif c == "#" then buf[#buf+1] = "#"
        else buf[#buf+1] = "\\"..c end
        advance()
      elseif is_interp and char() == "#" and char(1) == "{" then
        if #buf > 0 or #parts == 0 then
          parts[#parts+1] = {type="str", value=table.concat(buf)}; buf = {}
        end
        advance(2)
        local depth, ec = 1, {}
        while pos <= #source and depth > 0 do
          if char() == "{" then depth = depth + 1
          elseif char() == "}" then depth = depth - 1 end
          if depth > 0 then ec[#ec+1] = char(); advance() end
        end
        advance()
        parts[#parts+1] = {type="expr", value=table.concat(ec)}
      else
        buf[#buf+1] = char(); advance()
      end
    end
    if pos > #source then error(filename..":"..sline..": unterminated string") end
    advance()

    if #parts == 0 then
      emit(T.STRING, table.concat(buf))
    else
      if #buf > 0 then parts[#parts+1] = {type="str", value=table.concat(buf)} end
      emit(T.STRING, parts)
    end
  end

  local function read_number()
    local s = pos
    if char() == "0" and (char(1) == "x" or char(1) == "X") then
      advance(2)
      while pos <= #source and char():match("[%da-fA-F]") do advance() end
    else
      while pos <= #source and char():match("%d") do advance() end
      if char() == "." and char(1) ~= "." then
        advance()
        while pos <= #source and char():match("%d") do advance() end
      end
      if char() == "e" or char() == "E" then
        advance()
        if char() == "+" or char() == "-" then advance() end
        while pos <= #source and char():match("%d") do advance() end
      end
    end
    emit(T.NUMBER, source:sub(s, pos-1))
  end

  local function read_ident()
    local s = pos
    while pos <= #source and char():match("[%w_]") do advance() end
    local w = source:sub(s, pos-1)
    emit(KEYWORDS[w] or T.IDENT, w)
  end

  while pos <= #source do
    if at_line_start then
      local ind = 0
      while pos <= #source and (char() == " " or char() == "\t") do
        ind = ind + (char() == "\t" and 4 or 1); advance()
      end

      local skip = false
      if pos <= #source and (char() == "\n" or char() == "\r") then
        advance(); if pos <= #source and char() == "\n" then advance() end
        skip = true
      elseif pos <= #source and char() == "#" then
        skip_comment(); skip = true
      elseif pos > #source then break
      end

      if skip then
        -- at_line_start stays true, loop again
      else
        at_line_start = false
        -- Emit INDENT/DEDENT when outside parens, OR when tracking arrow bodies inside parens
        if paren_depth == 0 or #arrow_indent_stack > 0 then
          local cur = indent_stack[#indent_stack]
          if ind > cur then
            indent_stack[#indent_stack+1] = ind; emit(T.INDENT, ind)
          elseif ind < cur then
            while #indent_stack > 1 and indent_stack[#indent_stack] > ind do
              indent_stack[#indent_stack] = nil; emit(T.DEDENT, ind)
            end
            -- Pop any arrow levels we've dedented past
            while #arrow_indent_stack > 0 and paren_depth > 0 and ind <= arrow_indent_stack[#arrow_indent_stack] do
              arrow_indent_stack[#arrow_indent_stack] = nil
            end
          end
        end
      end
    end

    if not at_line_start then
      local c = char()
      if c == " " or c == "\t" or c == "\r" then advance()
      elseif c == "\n" then
        local last_type = #tokens > 0 and tokens[#tokens].type or nil
        local after_arrow = (last_type == T.ARROW or last_type == T.FATARROW)
        if after_arrow then arrow_indent_stack[#arrow_indent_stack+1] = indent_stack[#indent_stack] end
        if (paren_depth == 0 or #arrow_indent_stack > 0) and #tokens > 0 and last_type ~= T.NEWLINE and last_type ~= T.INDENT then
          emit(T.NEWLINE, "\n")
        end
        advance(); at_line_start = true
      elseif c == "#" then
        -- Disambiguate: # as comment vs length operator
        -- # is length when previous token expects an expression to follow
        local is_len = false
        if char(1) == "{" then
          -- string interpolation inside string handled elsewhere; standalone #{
          is_len = false
        elseif #tokens > 0 then
          local pt = tokens[#tokens].type
          -- # is length operator when preceded by a token that expects an expression
          local expr_starters = {
            [T.LBRACKET]=1, [T.LPAREN]=1, [T.COMMA]=1, [T.ASSIGN]=1,
            [T.PLUSEQ]=1, [T.MINUSEQ]=1, [T.STAREQ]=1, [T.SLASHEQ]=1,
            [T.CONCATEQ]=1, [T.PERCENTEQ]=1,
            [T.PLUS]=1, [T.MINUS]=1, [T.STAR]=1, [T.SLASH]=1,
            [T.PERCENT]=1, [T.CARET]=1, [T.CONCAT]=1,
            [T.EQ]=1, [T.NEQ]=1, [T.LT]=1, [T.GT]=1, [T.LTE]=1, [T.GTE]=1,
            [T.AND]=1, [T.OR]=1, [T.NOT]=1,
            [T.RETURN]=1, [T.LBRACE]=1, [T.COLON]=1,
            [T.ARROW]=1, [T.FATARROW]=1,
            [T.INDENT]=1, [T.NEWLINE]=1,
            [T.IF]=1, [T.UNLESS]=1, [T.WHILE]=1, [T.UNTIL]=1,
            [T.ELSEIF]=1, [T.THEN]=1, [T.ELSE]=1,
            [T.FOR]=1, [T.IN]=1, [T.OF]=1, [T.DO]=1,
            [T.WHEN]=1, [T.SWITCH]=1,
          }
          if expr_starters[pt] then
            is_len = true
          end
        end
        if is_len then
          advance(); emit(T.HASH, "#")
        else
          skip_comment()
        end
      elseif c:match("%d") or (c == "." and char(1):match("%d")) then read_number()
      elseif c == '"' or c == "'" then read_string(c)
      elseif c:match("[%a_]") then read_ident()
      elseif c == "+" then advance(); if char() == "=" then advance(); emit(T.PLUSEQ,"+=") else emit(T.PLUS,"+") end
      elseif c == "-" then advance(); if char() == ">" then advance(); emit(T.ARROW,"->") elseif char() == "=" then advance(); emit(T.MINUSEQ,"-=") else emit(T.MINUS,"-") end
      elseif c == "*" then advance(); if char() == "=" then advance(); emit(T.STAREQ,"*=") else emit(T.STAR,"*") end
      elseif c == "/" then advance(); if char() == "=" then advance(); emit(T.SLASHEQ,"/=") else emit(T.SLASH,"/") end
      elseif c == "%" then advance(); if char() == "=" then advance(); emit(T.PERCENTEQ,"%=") else emit(T.PERCENT,"%") end
      elseif c == "^" then advance(); emit(T.CARET,"^")
      elseif c == "." then
        advance()
        if char() == "." then
          advance()
          if char() == "." then advance(); emit(T.VARARGS,"...")
          elseif char() == "=" then advance(); emit(T.CONCATEQ,"..=")
          else emit(T.CONCAT,"..") end
        else emit(T.DOT,".") end
      elseif c == "=" then advance(); if char() == "=" then advance(); emit(T.EQ,"==") elseif char() == ">" then advance(); emit(T.FATARROW,"=>") else emit(T.ASSIGN,"=") end
      elseif c == "!" then advance(); if char() == "=" then advance(); emit(T.NEQ,"!=") else emit(T.NOT,"not") end
      elseif c == "<" then advance(); if char() == "=" then advance(); emit(T.LTE,"<=") else emit(T.LT,"<") end
      elseif c == ">" then advance(); if char() == "=" then advance(); emit(T.GTE,">=") else emit(T.GT,">") end
      elseif c == "(" then paren_depth=paren_depth+1; advance(); emit(T.LPAREN,"(")
      elseif c == ")" then paren_depth=paren_depth-1; advance(); emit(T.RPAREN,")")
      elseif c == "[" then paren_depth=paren_depth+1; advance(); emit(T.LBRACKET,"[")
      elseif c == "]" then paren_depth=paren_depth-1; advance(); emit(T.RBRACKET,"]")
      elseif c == "{" then paren_depth=paren_depth+1; advance(); emit(T.LBRACE,"{")
      elseif c == "}" then paren_depth=paren_depth-1; advance(); emit(T.RBRACE,"}")
      elseif c == "," then advance(); emit(T.COMMA,",")
      elseif c == ":" then advance(); emit(T.COLON,":")
      elseif c == "@" then advance(); emit(T.AT,"@")
      elseif c == "?" then advance(); emit(T.QMARK,"?")
      else err("unexpected character: "..c) end
    end
  end

  while #indent_stack > 1 do indent_stack[#indent_stack] = nil; emit(T.DEDENT, 0) end

  -- Check for unmatched delimiters
  if paren_depth > 0 then
    error(filename..":"..line..":1: unmatched opening delimiter (missing closing paren, bracket, or brace)")
  elseif paren_depth < 0 then
    error(filename..":"..line..":1: extra closing delimiter (unexpected closing paren, bracket, or brace)")
  end

  emit(T.EOF, "")
  return tokens
end

--------------------------------------------------------------------------------
-- AST NODE
--------------------------------------------------------------------------------
local function N(tag, t) t.tag = tag; return t end

--------------------------------------------------------------------------------
-- PARSER
--------------------------------------------------------------------------------
function Breeze.parse(tokens, filename)
  filename = filename or "<input>"
  local pos = 1

  local function cur() return tokens[pos] or tokens[#tokens] end
  local function pk(off) return tokens[pos+(off or 0)] or tokens[#tokens] end
  local function is(tp, val)
    local t = cur()
    if val then return t.type == tp and t.value == val end
    return t.type == tp
  end
  local function adv() local t = cur(); pos = pos + 1; return t end
  local function expect(tp, val)
    if not is(tp, val) then
      local t = cur()
      error(filename..":"..t.line..":"..t.col..": expected "
        ..(val and (tp.." '"..val.."'") or tp)
        ..", got "..t.type.." '"..tostring(t.value).."'")
    end
    return adv()
  end
  local function skip_nl() while is(T.NEWLINE) do adv() end end
  local function try_match(tp, val) if is(tp, val) then return adv() end end

  -- Forward declarations
  local parse_expr, parse_expr_no_postfix, parse_stmt, parse_block

  -- String interpolation
  local function make_string(tok)
    if type(tok.value) == "table" then
      local parts = {}
      for _, p in ipairs(tok.value) do
        if p.type == "str" then
          parts[#parts+1] = N("Str", {value=p.value})
        else
          local st = Breeze.lex(p.value, filename)
          local sa = Breeze.parse(st, filename)
          local e = (sa and sa.body and sa.body[1])
          if e and e.tag == "ExprStmt" then e = e.expr end
          parts[#parts+1] = N("Interp", {expr=e or N("Nil",{})})
        end
      end
      return N("StrInterp", {parts=parts})
    end
    return N("Str", {value=tok.value})
  end

  local parse_postfix  -- forward declaration for use in parse_primary

  -- Table literal { key: val }
  local function parse_table()
    expect(T.LBRACE); skip_nl()
    local entries = {}
    while not is(T.RBRACE) and not is(T.EOF) do
      skip_nl(); if is(T.RBRACE) then break end
      if is(T.IDENT) and pk(1).type == T.COLON then
        local k = adv().value; adv(); skip_nl()
        entries[#entries+1] = N("Entry", {key=N("Str",{value=k}), value=parse_expr()})
      elseif is(T.LBRACKET) then
        adv(); local k = parse_expr(); expect(T.RBRACKET); expect(T.COLON); skip_nl()
        entries[#entries+1] = N("Entry", {key=k, value=parse_expr()})
      else
        entries[#entries+1] = N("Entry", {key=nil, value=parse_expr()})
      end
      skip_nl(); try_match(T.COMMA); skip_nl()
    end
    expect(T.RBRACE)
    return N("Table", {entries=entries})
  end

  -- Array literal or list comprehension
  local function parse_array()
    expect(T.LBRACKET); skip_nl()
    if is(T.RBRACKET) then adv(); return N("Table", {entries={}}) end

    local first = parse_expr_no_postfix()
    skip_nl()

    -- List comprehension: [expr for x in iter]
    if is(T.FOR) then
      adv()
      local v1 = expect(T.IDENT).value
      local v2 = nil
      if try_match(T.COMMA) then v2 = expect(T.IDENT).value end
      expect(T.IN); skip_nl()
      local iter = parse_expr_no_postfix()
      skip_nl()
      local guard = nil
      if is(T.IF) or is(T.WHEN) then adv(); guard = parse_expr_no_postfix() end
      skip_nl()
      expect(T.RBRACKET)
      return N("ListComp", {expr=first, var1=v1, var2=v2, iter=iter, guard=guard})
    end

    -- Regular array
    local entries = {N("Entry", {key=nil, value=first})}
    while try_match(T.COMMA) do
      skip_nl(); if is(T.RBRACKET) then break end
      entries[#entries+1] = N("Entry", {key=nil, value=parse_expr()})
      skip_nl()
    end
    expect(T.RBRACKET)
    return N("Table", {entries=entries})
  end

  -- Parse function params: (a, b = 1, @c, ...)
  local function parse_params()
    local params, defaults = {}, {}
    expect(T.LPAREN)
    while not is(T.RPAREN) and not is(T.EOF) do
      if is(T.VARARGS) then adv(); params[#params+1] = "..."
      elseif is(T.AT) then
        adv(); local nm = expect(T.IDENT).value; params[#params+1] = "@"..nm
        if try_match(T.ASSIGN) then defaults[#params] = parse_expr_no_postfix() end
      else
        local nm = expect(T.IDENT).value; params[#params+1] = nm
        if try_match(T.ASSIGN) then defaults[#params] = parse_expr_no_postfix() end
      end
      if not try_match(T.COMMA) then break end
    end
    expect(T.RPAREN)
    return params, defaults
  end

  local function parse_arrow_body()
    skip_nl()
    if is(T.INDENT) then return parse_block() end
    -- Single-line body: parse as a full statement to support assignments
    return N("Block", {body={parse_stmt()}})
  end

  local function parse_fn(params, defaults, fat)
    return N("Fn", {params=params or {}, defaults=defaults or {}, body=parse_arrow_body(), fat=fat or false})
  end

  -- Primary expression
  local function parse_primary()
    skip_nl()

    if is(T.LPAREN) then
      local saved = pos
      local ok, p, d = pcall(function() local a,b = parse_params(); return a,b end)
      if ok and (is(T.ARROW) or is(T.FATARROW)) then
        local fat = adv().type == T.FATARROW
        return parse_fn(p, d, fat)
      end
      pos = saved
      expect(T.LPAREN); skip_nl(); local e = parse_expr(); skip_nl(); expect(T.RPAREN)
      return N("Group", {expr=e})
    end

    if is(T.ARROW) or is(T.FATARROW) then
      local fat = adv().type == T.FATARROW
      return parse_fn({}, {}, fat)
    end

    if is(T.NUMBER) then return N("Num", {value=adv().value}) end
    if is(T.STRING) then return make_string(adv()) end
    if is(T.BOOL) then return N("Bool", {value=adv().value=="true"}) end
    if is(T.NIL) then adv(); return N("Nil", {}) end
    if is(T.VARARGS) then adv(); return N("Varargs", {}) end

    if is(T.AT) then
      adv()
      if is(T.IDENT) then return N("SelfDot", {field=adv().value}) end
      return N("Self", {})
    end

    if is(T.NOT) then adv(); return N("Unop", {op="not", expr=parse_postfix(parse_primary())}) end
    if is(T.MINUS) then adv(); return N("Unop", {op="-", expr=parse_postfix(parse_primary())}) end
    if is(T.HASH) then adv(); return N("Unop", {op="#", expr=parse_postfix(parse_primary())}) end
    if is(T.TYPEOF) then adv(); return N("Unop", {op="typeof", expr=parse_postfix(parse_primary())}) end

    if is(T.NEW) then
      adv(); local cls = parse_primary()
      local args = {}
      if try_match(T.LPAREN) then
        skip_nl()
        while not is(T.RPAREN) and not is(T.EOF) do
          args[#args+1] = parse_expr(); skip_nl()
          if not try_match(T.COMMA) then break end; skip_nl()
        end
        expect(T.RPAREN)
      end
      return N("New", {class=cls, args=args})
    end

    if is(T.LBRACE) then return parse_table() end
    if is(T.LBRACKET) then return parse_array() end

    if is(T.DO) then adv(); skip_nl(); return N("Do", {body=parse_block()}) end

    if is(T.IDENT) then return N("Id", {name=adv().value}) end

    local t = cur()
    error(filename..":"..t.line..":"..t.col..": unexpected: "..t.type.." '"..tostring(t.value).."'")
  end

  -- Postfix: calls, indexing, member access
  parse_postfix = function(expr)
    while true do
      if is(T.DOT) then
        adv(); expr = N("Dot", {obj=expr, field=expect(T.IDENT).value})
      elseif is(T.COLON) then
        adv(); local m = expect(T.IDENT).value
        if is(T.LPAREN) then
          adv(); skip_nl(); local args = {}
          while not is(T.RPAREN) and not is(T.EOF) do
            args[#args+1] = parse_expr(); skip_nl()
            if not try_match(T.COMMA) then break end; skip_nl()
          end
          expect(T.RPAREN)
          expr = N("MethodCall", {obj=expr, method=m, args=args})
        else
          expr = N("MethodRef", {obj=expr, method=m})
        end
      elseif is(T.LPAREN) then
        adv(); skip_nl(); local args = {}
        while not is(T.RPAREN) and not is(T.EOF) do
          args[#args+1] = parse_expr(); skip_nl()
          if not try_match(T.COMMA) then break end; skip_nl()
        end
        expect(T.RPAREN)
        expr = N("Call", {fn=expr, args=args})
      elseif is(T.LBRACKET) and not is(T.NEWLINE) then
        adv(); skip_nl(); local idx = parse_expr(); skip_nl(); expect(T.RBRACKET)
        expr = N("Idx", {obj=expr, index=idx})
      elseif is(T.QMARK) then
        adv(); expr = N("Exist", {expr=expr})
      else break end
    end
    return expr
  end

  local binop_prec = {
    ["or"]=1, ["and"]=2,
    ["=="]=3, ["!="]=3, ["<"]=3, [">"]=3, ["<="]=3, [">="]=3,
    [".."]=4, ["+"]=5, ["-"]=5, ["*"]=6, ["/"]=6, ["%"]=6, ["^"]=7,
  }
  local right_assoc = {["^"]=true, [".."]=true}

  local function get_prec()
    local t = cur()
    if t.type == T.AND then return 2 end
    if t.type == T.OR then return 1 end
    return binop_prec[t.type] or binop_prec[t.value]
  end

  local function parse_binop(min)
    local left = parse_postfix(parse_primary())
    while true do
      local p = get_prec()
      if not p or p < min then break end
      local tok = adv()
      local op = tok.value or tok.type
      skip_nl()
      local right = parse_binop(right_assoc[op] and p or (p+1))
      left = N("Binop", {op=op, left=left, right=right})
    end
    return left
  end

  -- Expression without postfix if/unless (used inside array literals, comprehensions, params)
  parse_expr_no_postfix = function()
    return parse_binop(1)
  end

  -- Full expression (may have postfix if/unless)
  parse_expr = function()
    local e = parse_binop(1)
    if is(T.IF) then adv(); return N("PostIf", {expr=e, cond=parse_expr()}) end
    if is(T.UNLESS) then adv(); return N("PostUnless", {expr=e, cond=parse_expr()}) end
    return e
  end

  -- If / unless statement
  local function parse_if()
    local kw = adv()
    local cond = parse_expr()
    local neg = (kw.type == T.UNLESS)
    skip_nl(); try_match(T.THEN); skip_nl()
    local body
    if is(T.INDENT) then body = parse_block()
    else body = N("Block", {body={N("ExprStmt", {expr=parse_expr()})}}) end

    local els = nil; skip_nl()
    if is(T.ELSEIF) then
      els = N("Block", {body={parse_if()}})
    elseif try_match(T.ELSE) then
      skip_nl()
      if is(T.IF) or is(T.UNLESS) then els = N("Block", {body={parse_if()}})
      elseif is(T.INDENT) then els = parse_block()
      else els = N("Block", {body={N("ExprStmt", {expr=parse_expr()})}}) end
    end
    return N("If", {cond=cond, body=body, els=els, neg=neg})
  end

  local function parse_while()
    local kw = adv(); local cond = parse_expr()
    local neg = (kw.type == T.UNTIL)
    skip_nl(); return N("While", {cond=cond, body=parse_block(), neg=neg})
  end

  local function parse_for()
    adv()
    local v1 = expect(T.IDENT).value
    local v2 = nil
    if try_match(T.COMMA) then v2 = expect(T.IDENT).value end

    if try_match(T.IN) then
      skip_nl(); local iter = parse_expr(); skip_nl()
      return N("ForIn", {v1=v1, v2=v2, iter=iter, body=parse_block()})
    elseif try_match(T.OF) then
      skip_nl(); local iter = parse_expr(); skip_nl()
      return N("ForOf", {v1=v1, v2=v2, iter=iter, body=parse_block()})
    else
      expect(T.ASSIGN)
      local s = parse_expr(); expect(T.COMMA); local e = parse_expr()
      local step = nil; if try_match(T.COMMA) then step = parse_expr() end
      skip_nl()
      return N("ForNum", {var=v1, start=s, stop=e, step=step, body=parse_block()})
    end
  end

  local function parse_class()
    adv(); local name = expect(T.IDENT).value
    local parent = nil
    if try_match(T.EXTENDS) then parent = expect(T.IDENT).value end
    skip_nl()
    local methods = {}
    if is(T.INDENT) then
      expect(T.INDENT)
      while not is(T.DEDENT) and not is(T.EOF) do
        skip_nl(); if is(T.DEDENT) or is(T.EOF) then break end
        if is(T.IDENT) then
          local mn = adv().value
          if try_match(T.COLON) then
            skip_nl(); methods[#methods+1] = N("Method", {name=mn, fn=parse_expr()})
          end
        elseif is(T.AT) then
          adv(); local fn = expect(T.IDENT).value
          if try_match(T.COLON) then
            skip_nl(); methods[#methods+1] = N("Method", {name=fn, fn=parse_expr()})
          elseif try_match(T.ASSIGN) then
            methods[#methods+1] = N("Field", {name=fn, value=parse_expr()})
          end
        end
        skip_nl()
      end
      if is(T.DEDENT) then adv() end
    end
    return N("Class", {name=name, parent=parent, methods=methods})
  end

  local function parse_return()
    adv()
    if is(T.NEWLINE) or is(T.DEDENT) or is(T.EOF) then return N("Return", {vals={}}) end
    local vals = {parse_expr()}
    while try_match(T.COMMA) do vals[#vals+1] = parse_expr() end
    return N("Return", {vals=vals})
  end

  local function parse_switch()
    adv(); local subj = parse_expr(); skip_nl(); expect(T.INDENT)
    local cases, default = {}, nil
    while not is(T.DEDENT) and not is(T.EOF) do
      skip_nl(); if is(T.DEDENT) or is(T.EOF) then break end
      if is(T.WHEN) then
        adv(); local vals = {parse_expr()}
        while try_match(T.COMMA) do skip_nl(); vals[#vals+1] = parse_expr() end
        skip_nl(); try_match(T.THEN); skip_nl()
        local body; if is(T.INDENT) then body = parse_block()
        else body = N("Block", {body={N("ExprStmt", {expr=parse_expr()})}}) end
        cases[#cases+1] = {values=vals, body=body}
      elseif is(T.ELSE) then
        adv(); skip_nl()
        if is(T.INDENT) then default = parse_block()
        else default = N("Block", {body={N("ExprStmt", {expr=parse_expr()})}}) end
      end
      skip_nl()
    end
    if is(T.DEDENT) then adv() end
    return N("Switch", {subj=subj, cases=cases, default=default})
  end

  local function parse_try()
    adv(); skip_nl(); local body = parse_block()
    local cv, cb, fb = nil, nil, nil
    skip_nl()
    if try_match(T.CATCH) then
      if is(T.IDENT) then cv = adv().value end
      skip_nl(); cb = parse_block()
    end
    skip_nl()
    if try_match(T.FINALLY) then skip_nl(); fb = parse_block() end
    return N("Try", {body=body, catch_var=cv, catch_body=cb, finally_body=fb})
  end

  local function parse_import()
    adv(); local names = {}
    if is(T.LBRACE) then
      adv()
      while not is(T.RBRACE) and not is(T.EOF) do
        names[#names+1] = expect(T.IDENT).value
        if not try_match(T.COMMA) then break end
      end
      expect(T.RBRACE)
    elseif is(T.IDENT) then
      names[#names+1] = adv().value
      while try_match(T.COMMA) do names[#names+1] = expect(T.IDENT).value end
    end
    expect(T.FROM)
    local src = expect(T.STRING).value
    if type(src) == "table" then src = src[1] and src[1].value or "" end
    return N("Import", {names=names, source=src})
  end

  parse_stmt = function()
    skip_nl()
    if is(T.IF) or is(T.UNLESS) then return parse_if() end
    if is(T.WHILE) or is(T.UNTIL) then return parse_while() end
    if is(T.FOR) then return parse_for() end
    if is(T.CLASS) then return parse_class() end
    if is(T.RETURN) then return parse_return() end
    if is(T.BREAK) then adv(); return N("Break", {}) end
    if is(T.SWITCH) then return parse_switch() end
    if is(T.TRY) then return parse_try() end
    if is(T.IMPORT) then return parse_import() end
    if is(T.EXPORT) then adv(); return N("Export", {stmt=parse_stmt()}) end

    local expr = parse_expr()
    local aops = {[T.ASSIGN]="=", [T.PLUSEQ]="+=", [T.MINUSEQ]="-=",
      [T.STAREQ]="*=", [T.SLASHEQ]="/=", [T.CONCATEQ]="..=", [T.PERCENTEQ]="%="}
    local aop = aops[cur().type]
    if aop then
      adv(); skip_nl(); local val = parse_expr()
      -- For compound assignment with postfix-if: x += 1 if cond -> if cond then x = x + 1 end
      local postfix_tag, postfix_cond
      if val.tag == "PostIf" or val.tag == "PostUnless" then
        postfix_tag = val.tag; postfix_cond = val.cond; val = val.expr
      end
      if aop ~= "=" then
        val = N("Binop", {op=aop:sub(1,-2), left=expr, right=val})
      end
      if postfix_tag then
        val = N(postfix_tag, {expr=val, cond=postfix_cond})
      end
      return N("Assign", {target=expr, value=val})
    end

    return N("ExprStmt", {expr=expr})
  end

  parse_block = function()
    expect(T.INDENT)
    local stmts = {}
    while not is(T.DEDENT) and not is(T.EOF) do
      skip_nl(); if is(T.DEDENT) or is(T.EOF) then break end
      stmts[#stmts+1] = parse_stmt(); skip_nl()
    end
    if is(T.DEDENT) then adv() end
    return N("Block", {body=stmts})
  end

  local stmts = {}; skip_nl()
  while not is(T.EOF) do stmts[#stmts+1] = parse_stmt(); skip_nl() end
  return N("Block", {body=stmts})
end

--------------------------------------------------------------------------------
-- CODE GENERATOR
--------------------------------------------------------------------------------
function Breeze.compile(ast, opts)
  opts = opts or {}
  local out = {}
  local lvl = 0
  local tab = opts.indent or "  "
  local exports = {}
  -- Track declared locals to avoid re-declaring
  local scopes = {{}}  -- stack of sets

  local function push_scope() scopes[#scopes+1] = {} end
  local function pop_scope() scopes[#scopes] = nil end
  local function declare(name)
    scopes[#scopes][name] = true
  end
  local function is_declared(name)
    for i = #scopes, 1, -1 do
      if scopes[i][name] then return true end
    end
    return false
  end

  local function w(s) out[#out+1] = s end
  local function ind() for i=1,lvl do w(tab) end end
  local function ln(s) ind(); w(s); w("\n") end

  local ce, cs, cb, cb_ret  -- compile_expr, compile_stmt, compile_block, compile_block_returning

  local function esc(s) return s:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t") end

  ce = function(n)
    if not n then return "nil" end
    local t = n.tag
    if t == "Num" then return n.value end
    if t == "Str" then return '"'..esc(n.value)..'"' end
    if t == "StrInterp" then
      local ps = {}
      for _, p in ipairs(n.parts) do
        if p.tag == "Str" then ps[#ps+1] = '"'..esc(p.value)..'"'
        else ps[#ps+1] = "tostring("..ce(p.expr)..")" end
      end
      return #ps == 1 and ps[1] or ("("..table.concat(ps, " .. ")..")")
    end
    if t == "Bool" then return n.value and "true" or "false" end
    if t == "Nil" then return "nil" end
    if t == "Varargs" then return "..." end
    if t == "Id" then return n.name end
    if t == "Self" then return "self" end
    if t == "SelfDot" then return "self."..n.field end
    if t == "Group" then return "("..ce(n.expr)..")" end
    if t == "Unop" then
      if n.op == "typeof" then return "type("..ce(n.expr)..")" end
      if n.op == "not" then return "not "..ce(n.expr) end
      if n.op == "#" then return "#"..ce(n.expr) end
      return "(-"..ce(n.expr)..")"
    end
    if t == "Binop" then
      local op = n.op
      if op == "!=" then op = "~=" end
      return "("..ce(n.left).." "..op.." "..ce(n.right)..")"
    end
    if t == "Dot" then return ce(n.obj).."."..n.field end
    if t == "MethodRef" then return ce(n.obj)..":"..n.method end
    if t == "MethodCall" then
      local a = {}; for _,v in ipairs(n.args) do a[#a+1] = ce(v) end
      return ce(n.obj)..":"..n.method.."("..table.concat(a,", ")..")"
    end
    if t == "Call" then
      local a = {}; for _,v in ipairs(n.args) do a[#a+1] = ce(v) end
      return ce(n.fn).."("..table.concat(a,", ")..")"
    end
    if t == "Idx" then return ce(n.obj).."["..ce(n.index).."]" end
    if t == "Exist" then return "("..ce(n.expr).." ~= nil)" end
    if t == "New" then
      local a = {}; for _,v in ipairs(n.args) do a[#a+1] = ce(v) end
      return ce(n.class)..":new("..table.concat(a,", ")..")"
    end
    if t == "PostIf" then
      return "(function() if "..ce(n.cond).." then return "..ce(n.expr).." end end)()"
    end
    if t == "PostUnless" then
      return "(function() if not ("..ce(n.cond)..") then return "..ce(n.expr).." end end)()"
    end
    if t == "Table" then
      if #n.entries == 0 then return "{}" end
      local ps = {}
      for _, e in ipairs(n.entries) do
        if not e.key then ps[#ps+1] = ce(e.value)
        elseif e.key.tag == "Str" then ps[#ps+1] = e.key.value.." = "..ce(e.value)
        else ps[#ps+1] = "["..ce(e.key).."] = "..ce(e.value) end
      end
      return "{"..table.concat(ps, ", ").."}"
    end
    if t == "ListComp" then
      local r = "(function()\n"
      r = r .. tab.."local _r = {}\n"
      if n.var2 then
        r = r .. tab.."for "..n.var1..", "..n.var2.." in ipairs("..ce(n.iter)..") do\n"
      else
        r = r .. tab.."for _, "..n.var1.." in ipairs("..ce(n.iter)..") do\n"
      end
      if n.guard then
        r = r .. tab..tab.."if "..ce(n.guard).." then\n"
        r = r .. tab..tab..tab.."_r[#_r + 1] = "..ce(n.expr).."\n"
        r = r .. tab..tab.."end\n"
      else
        r = r .. tab..tab.."_r[#_r + 1] = "..ce(n.expr).."\n"
      end
      r = r .. tab.."end\n"..tab.."return _r\nend)()"
      return r
    end
    if t == "Fn" then
      local params, self_assigns = {}, {}
      for _, p in ipairs(n.params) do
        if type(p) == "string" and p:sub(1,1) == "@" then
          local real = p:sub(2); params[#params+1] = real; self_assigns[#self_assigns+1] = real
        else params[#params+1] = p end
      end
      if n.fat then table.insert(params, 1, "self") end

      local r = "function("..table.concat(params, ", ")..")\n"
      lvl = lvl + 1
      -- defaults
      for i, def in pairs(n.defaults) do
        local pn = params[n.fat and (i+1) or i]
        if pn and pn ~= "..." then
          r = r .. tab:rep(lvl).."if "..pn.." == nil then "..pn.." = "..ce(def).." end\n"
        end
      end
      -- @param assigns
      for _, nm in ipairs(self_assigns) do
        r = r .. tab:rep(lvl).."self."..nm.." = "..nm.."\n"
      end
      -- body with implicit return
      if n.body and n.body.body then
        local saved = table.concat(out); out = {}
        cb_ret(n.body)
        r = r .. table.concat(out); out = {}
        w(saved)
      end
      lvl = lvl - 1
      r = r .. tab:rep(lvl).."end"
      return r
    end
    if t == "Do" then
      local r = "(function()\n"
      lvl = lvl + 1
      if n.body and n.body.body then
        local saved = table.concat(out); out = {}
        cb_ret(n.body)
        r = r .. table.concat(out); out = {}
        w(saved)
      end
      lvl = lvl - 1
      r = r .. tab:rep(lvl).."end)()"
      return r
    end
    return "nil --[[ unknown: "..tostring(t).." ]]"
  end

  cs = function(n)
    if not n then return end
    local t = n.tag

    if t == "ExprStmt" then
      if n.expr.tag == "PostIf" then
        ln("if "..ce(n.expr.cond).." then")
        lvl=lvl+1; ln(ce(n.expr.expr)); lvl=lvl-1; ln("end")
      elseif n.expr.tag == "PostUnless" then
        ln("if not ("..ce(n.expr.cond)..") then")
        lvl=lvl+1; ln(ce(n.expr.expr)); lvl=lvl-1; ln("end")
      else
        ln(ce(n.expr))
      end
    elseif t == "Assign" then
      local tgt = ce(n.target)
      -- Postfix if/unless on assignment: x = val if cond -> if cond then x = val end
      if n.value.tag == "PostIf" or n.value.tag == "PostUnless" then
        local cond = ce(n.value.cond)
        if n.value.tag == "PostUnless" then cond = "not ("..cond..")" end
        local val = ce(n.value.expr)
        if n.target.tag == "Id" and not is_declared(n.target.name) then declare(n.target.name) end
        ln("if "..cond.." then")
        lvl=lvl+1
        if n.target.tag == "Id" then ln(tgt.." = "..val) else ln(tgt.." = "..val) end
        lvl=lvl-1; ln("end")
      elseif n.target.tag == "Id" then
        local is_new = not is_declared(n.target.name)
        if is_new then declare(n.target.name) end
        -- For function assignments to simple identifiers, use forward-declare pattern
        -- to allow recursion: local f; f = function(...)...end
        if n.value.tag == "Fn" then
          local val = ce(n.value)
          if is_new then
            ln("local "..tgt)
            ln(tgt.." = "..val)
          else
            ln(tgt.." = "..val)
          end
        else
          local val = ce(n.value)
          if is_new then
            ln("local "..tgt.." = "..val)
          else
            ln(tgt.." = "..val)
          end
        end
      else
        local val = ce(n.value)
        ln(tgt.." = "..val)
      end
    elseif t == "If" then
      local cond = ce(n.cond)
      if n.neg then cond = "not ("..cond..")" end
      ln("if "..cond.." then")
      lvl=lvl+1; cb(n.body); lvl=lvl-1
      if n.els then
        if n.els.body and #n.els.body == 1 and n.els.body[1].tag == "If" then
          local ei = n.els.body[1]
          local ec = ce(ei.cond)
          if ei.neg then ec = "not ("..ec..")" end
          ln("elseif "..ec.." then")
          lvl=lvl+1; cb(ei.body); lvl=lvl-1
          if ei.els then ln("else"); lvl=lvl+1; cb(ei.els); lvl=lvl-1 end
        else
          ln("else"); lvl=lvl+1; cb(n.els); lvl=lvl-1
        end
      end
      ln("end")
    elseif t == "While" then
      local cond = ce(n.cond)
      if n.neg then cond = "not ("..cond..")" end
      ln("while "..cond.." do")
      lvl=lvl+1; cb(n.body); lvl=lvl-1; ln("end")
    elseif t == "ForIn" then
      if n.v2 then ln("for "..n.v1..", "..n.v2.." in ipairs("..ce(n.iter)..") do")
      else ln("for _, "..n.v1.." in ipairs("..ce(n.iter)..") do") end
      lvl=lvl+1
      push_scope(); declare(n.v1); if n.v2 then declare(n.v2) end
      cb(n.body)
      pop_scope()
      lvl=lvl-1; ln("end")
    elseif t == "ForOf" then
      if n.v2 then ln("for "..n.v1..", "..n.v2.." in pairs("..ce(n.iter)..") do")
      else ln("for "..n.v1..", _ in pairs("..ce(n.iter)..") do") end
      lvl=lvl+1
      push_scope(); declare(n.v1); if n.v2 then declare(n.v2) end
      cb(n.body)
      pop_scope()
      lvl=lvl-1; ln("end")
    elseif t == "ForNum" then
      local step = n.step and (", "..ce(n.step)) or ""
      ln("for "..n.var.." = "..ce(n.start)..", "..ce(n.stop)..step.." do")
      lvl=lvl+1
      push_scope(); declare(n.var)
      cb(n.body)
      pop_scope()
      lvl=lvl-1; ln("end")
    elseif t == "Return" then
      if #n.vals == 0 then ln("return")
      else
        local vs = {}; for _,v in ipairs(n.vals) do vs[#vs+1] = ce(v) end
        ln("return "..table.concat(vs, ", "))
      end
    elseif t == "Break" then ln("break")
    elseif t == "Class" then
      local nm, par = n.name, n.parent
      declare(nm)
      ln("local "..nm.." = {}"); ln(nm..".__index = "..nm)
      if par then ln("setmetatable("..nm..", {__index = "..par.."})") end
      w("\n")
      -- :new
      ln("function "..nm..":new(...)"); lvl=lvl+1
      if par then ln("local self = setmetatable("..par..":new(...) or {}, "..nm..")")
      else ln("local self = setmetatable({}, "..nm..")") end
      for _, m in ipairs(n.methods) do
        if m.tag == "Field" then ln("self."..m.name.." = "..ce(m.value)) end
      end
      local has_ctor = false
      for _, m in ipairs(n.methods) do
        if m.tag == "Method" and m.name == "constructor" then has_ctor = true end
      end
      if has_ctor then ln("self:constructor(...)") end
      ln("return self"); lvl=lvl-1; ln("end"); w("\n")
      -- methods
      for _, m in ipairs(n.methods) do
        if m.tag == "Method" then
          local fn = m.fn
          if fn.tag == "Fn" then
            local params, sa = {}, {}
            for _, p in ipairs(fn.params) do
              if type(p)=="string" and p:sub(1,1)=="@" then
                local r = p:sub(2); params[#params+1] = r; sa[#sa+1] = r
              else params[#params+1] = p end
            end
            ln("function "..nm..":"..m.name.."("..table.concat(params, ", ")..")")
            lvl=lvl+1
            for i, def in pairs(fn.defaults) do
              local pn = params[i]
              if pn and pn ~= "..." then
                ln("if "..pn.." == nil then "..pn.." = "..ce(def).." end")
              end
            end
            for _, s in ipairs(sa) do ln("self."..s.." = "..s) end
            if fn.body and fn.body.body then
              push_scope()
              if m.name == "constructor" then
                cb(fn.body)
              else
                cb_ret(fn.body)
              end
              pop_scope()
            end
            lvl=lvl-1; ln("end"); w("\n")
          end
        end
      end
    elseif t == "Switch" then
      local sv = ce(n.subj)
      ln("local _sw = "..sv)
      for i, c in ipairs(n.cases) do
        local conds = {}
        for _, v in ipairs(c.values) do conds[#conds+1] = "_sw == "..ce(v) end
        ln((i==1 and "if " or "elseif ")..table.concat(conds, " or ").." then")
        lvl=lvl+1; cb(c.body); lvl=lvl-1
      end
      if n.default then ln("else"); lvl=lvl+1; cb(n.default); lvl=lvl-1 end
      if #n.cases > 0 or n.default then ln("end") end
    elseif t == "Try" then
      ln("local _ok, _err = pcall(function()"); lvl=lvl+1; cb(n.body); lvl=lvl-1; ln("end)")
      if n.catch_body then
        ln("if not _ok then"); lvl=lvl+1
        if n.catch_var then declare(n.catch_var); ln("local "..n.catch_var.." = _err") end
        cb(n.catch_body); lvl=lvl-1; ln("end")
      end
      if n.finally_body then cb(n.finally_body) end
    elseif t == "Import" then
      local mod = n.source
      if #n.names == 1 then
        declare(n.names[1])
        ln('local '..n.names[1]..' = require("'..esc(mod)..'")')
      else
        ln('local _m = require("'..esc(mod)..'")')
        for _, nm in ipairs(n.names) do
          declare(nm)
          ln("local "..nm.." = _m."..nm)
        end
      end
    elseif t == "Export" then
      -- Pre-declare so the inner Assign skips 'local' — making this a global
      if n.stmt.tag == "Assign" and n.stmt.target.tag == "Id" then
        declare(n.stmt.target.name)
        exports[#exports+1] = n.stmt.target.name
      elseif n.stmt.tag == "Class" then
        declare(n.stmt.name)
        exports[#exports+1] = n.stmt.name
      end
      cs(n.stmt)
    elseif t == "Block" then cb(n)
    end
  end

  cb = function(block)
    if not block then return end
    if block.tag == "Block" then
      for _, s in ipairs(block.body) do cs(s) end
    else cs(block) end
  end

  -- Compile a block where the last statement gets an implicit return.
  -- Recurses into If/Switch so all branches get returns.
  cb_ret = function(block)
    if not block then return end
    local stmts = block.body
    if not stmts then cs(block); return end
    for i, s in ipairs(stmts) do
      if i < #stmts then
        cs(s)
      else
        -- Last statement: add implicit return
        if s.tag == "ExprStmt" then
          ln("return "..ce(s.expr))
        elseif s.tag == "If" then
          -- Compile if with implicit returns in each branch
          local cond = ce(s.cond)
          if s.neg then cond = "not ("..cond..")" end
          ln("if "..cond.." then")
          lvl=lvl+1; cb_ret(s.body); lvl=lvl-1
          if s.els then
            if s.els.body and #s.els.body == 1 and s.els.body[1].tag == "If" then
              local ei = s.els.body[1]
              local ec = ce(ei.cond)
              if ei.neg then ec = "not ("..ec..")" end
              ln("elseif "..ec.." then")
              lvl=lvl+1; cb_ret(ei.body); lvl=lvl-1
              if ei.els then ln("else"); lvl=lvl+1; cb_ret(ei.els); lvl=lvl-1 end
            else
              ln("else"); lvl=lvl+1; cb_ret(s.els); lvl=lvl-1
            end
          end
          ln("end")
        elseif s.tag == "Switch" then
          local sv = ce(s.subj)
          ln("local _sw = "..sv)
          for j, c in ipairs(s.cases) do
            local conds = {}
            for _, v in ipairs(c.values) do conds[#conds+1] = "_sw == "..ce(v) end
            ln((j==1 and "if " or "elseif ")..table.concat(conds, " or ").." then")
            lvl=lvl+1; cb_ret(c.body); lvl=lvl-1
          end
          if s.default then ln("else"); lvl=lvl+1; cb_ret(s.default); lvl=lvl-1 end
          if #s.cases > 0 or s.default then ln("end") end
        elseif s.tag == "Return" then
          cs(s)
        else
          cs(s)
        end
      end
    end
  end

  push_scope()
  cb(ast)
  pop_scope()

  if #exports > 0 then
    w("\n")
    local ps = {}; for _, nm in ipairs(exports) do ps[#ps+1] = nm.." = "..nm end
    ln("return {"..table.concat(ps, ", ").."}")
  end

  return table.concat(out)
end

--------------------------------------------------------------------------------
-- HIGH-LEVEL API
--------------------------------------------------------------------------------
function Breeze.transpile(source, filename)
  return Breeze.compile(Breeze.parse(Breeze.lex(source, filename), filename))
end

function Breeze.run(source, filename)
  local code = Breeze.transpile(source, filename)
  local fn, err = loadstring(code, filename)
  if not fn then
    io.stderr:write("Lua compile error:\n"..code.."\n\n"..err.."\n"); os.exit(1)
  end
  return fn()
end

--------------------------------------------------------------------------------
-- CLI
--------------------------------------------------------------------------------
if arg then
  local mode, input_file, eval_code, print_lua = nil, nil, nil, false
  local i = 1
  while i <= #arg do
    if arg[i] == "-e" then mode = "eval"; i = i+1; eval_code = arg[i]
    elseif arg[i] == "-c" or arg[i] == "--compile" then print_lua = true
    elseif arg[i] == "-h" or arg[i] == "--help" then
      print([[
Breeze - A CoffeeScript-like language for Lua 5.1

Usage:
  lua breeze.lua                    Start REPL
  lua breeze.lua file.bz            Run a Breeze file
  lua breeze.lua -c file.bz         Compile and print Lua output
  lua breeze.lua -e "code"          Evaluate Breeze code
  lua breeze.lua -e "code" -c       Print compiled Lua for code

Language features:
  - Significant whitespace (indentation-based blocks)
  - Arrow functions: (x) -> x * 2
  - Fat arrows: (x) => @value + x  (binds self)
  - Implicit returns (last expression in a function)
  - String interpolation: "hello #{name}"
  - @ shorthand for self: @name = value
  - Classes with inheritance: class Dog extends Animal
  - List comprehensions: [x * 2 for x in items]
  - unless/until keywords
  - Postfix conditionals: print(x) if x > 0
  - Existential operator: value?
  - switch/when expressions
  - try/catch/finally
  - for..in (ipairs), for..of (pairs)
  - import {a, b} from "module"
  - Compound assignment: +=, -=, *=, /=, ..=
  - new ClassName(args)
  - typeof expr
]])
      os.exit(0)
    elseif arg[i]:sub(1,1) ~= "-" then mode = "file"; input_file = arg[i]
    end
    i = i + 1
  end

  if mode == "eval" and eval_code then
    if print_lua then print(Breeze.transpile(eval_code, "<eval>"))
    else Breeze.run(eval_code, "<eval>") end
  elseif mode == "file" and input_file then
    local f = io.open(input_file, "r")
    if not f then io.stderr:write("Error: cannot open "..input_file.."\n"); os.exit(1) end
    local src = f:read("*a"); f:close()
    if print_lua then print(Breeze.transpile(src, input_file))
    else Breeze.run(src, input_file) end
  elseif not mode then
    io.write("Breeze v0.1.0 (Lua 5.1 target)\nType expressions or statements. Ctrl+D to exit.\n\n")
    local buf = ""
    while true do
      io.write(buf == "" and "breeze> " or "     .. ")
      local line = io.read()
      if not line then print(); break end
      buf = buf .. line .. "\n"
      local ok, result = pcall(Breeze.transpile, buf, "<repl>")
      if ok then
        local expr_code = "return " .. result:gsub("^local ", "")
        local fn = loadstring(expr_code, "<repl>") or loadstring(result, "<repl>")
        if fn then
          local s, v = pcall(fn)
          if s and v ~= nil then print("=> "..tostring(v))
          elseif not s then io.stderr:write("Error: "..tostring(v).."\n") end
        end
        buf = ""
      elseif result:match("EOF") or result:match("DEDENT") then
        -- incomplete, keep reading
      else io.stderr:write("Error: "..tostring(result).."\n"); buf = "" end
    end
  end
end

return Breeze
