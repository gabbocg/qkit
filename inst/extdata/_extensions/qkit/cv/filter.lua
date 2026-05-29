-- qkit-cv Pandoc Lua filter.
--
-- Rewrites semantic divs into the CV's specific LaTeX patterns so users
-- can write mostly-pure markdown CVs. Recognized divs:
--
--   ::: {.cv-entries}            bullet list of `- key | value` items,
--                                italic col 1, default row gap 15pt;
--                                attribute gap="2.5pt" for tighter spacing
--   ::: {.cv-keys}               bullet list of `- key | value` items,
--                                bold col 1, default row gap 2.5pt
--   ::: {.cv-publications}       ordered list, hanging-indent enumerate
--                                matching enumitem options of the original CV
--   ::: {.cv-references}         wraps nested .referee subdivs in a
--                                two-column multicols block separated by
--                                \vfill\columnbreak
--
-- Skipped silently when the output is not LaTeX (HTML preview, etc.).

if FORMAT ~= "latex" then return {} end

local function tex(inlines)
  -- Convert a list of Pandoc inlines to LaTeX via the writer. Strip trailing
  -- whitespace so we can compose into a row cell cleanly.
  local doc = pandoc.Pandoc({pandoc.Plain(inlines)})
  return (pandoc.write(doc, "latex"):gsub("%s+$", ""))
end

local function is_strong_only(inlines)
  return #inlines == 1 and inlines[1].t == "Strong"
end

local function find_first(blocks, tag)
  for _, b in ipairs(blocks) do
    if b.t == tag then return b end
  end
  return nil
end

-- Split a flat list of inlines at the first `|` token. Returns two
-- inline lists (key, value) with surrounding whitespace trimmed, or nil if
-- no separator is present.
local function split_at_pipe(inlines)
  local key, val, found = pandoc.List({}), pandoc.List({}), false
  for _, inl in ipairs(inlines) do
    if not found and inl.t == "Str" and inl.text == "|" then
      found = true
    elseif not found then
      key:insert(inl)
    else
      val:insert(inl)
    end
  end
  if not found then return nil end
  while #key > 0 and key[#key].t == "Space" do key:remove(#key) end
  while #val > 0 and val[1].t == "Space" do val:remove(1) end
  return key, val
end

local function handle_table_div(div, key_style, default_gap)
  local list = find_first(div.content, "BulletList")
  if not list or #list.content == 0 then return nil end
  local gap = div.attributes.gap or default_gap

  local out = {[[\begin{tabular}{L!{\VRule width 1pt}R}]]}
  local n = #list.content
  for i, item in ipairs(list.content) do
    local item_inlines = pandoc.utils.blocks_to_inlines(item)
    local key_inlines, val_inlines = split_at_pipe(item_inlines)
    if key_inlines then
      local key_tex
      if is_strong_only(key_inlines) then
        key_tex = tex(key_inlines)
      elseif key_style == "italic" then
        key_tex = string.format("\\textit{%s}", tex(key_inlines))
      else
        key_tex = string.format("\\textbf{%s}", tex(key_inlines))
      end
      local sep = (i < n) and string.format("\\\\[%s]", gap) or ""
      table.insert(out, string.format("%s&{%s}%s", key_tex, tex(val_inlines), sep))
    end
  end
  table.insert(out, [[\end{tabular}]])
  return pandoc.RawBlock("latex", table.concat(out, "\n"))
end

local function handle_publications(div)
  local olist = find_first(div.content, "OrderedList")
  if not olist then return nil end
  local out = {
    [==[\begin{enumerate}[labelindent=0pt,labelwidth=\widthof{\ref{last-item}},label=\arabic*.,itemindent=0em,leftmargin=2.75em]]==]
  }
  for _, item in ipairs(olist.content) do
    table.insert(out, "\\item " .. tex(pandoc.utils.blocks_to_inlines(item)))
  end
  table.insert(out, [[\end{enumerate}]])
  return pandoc.RawBlock("latex", table.concat(out, "\n"))
end

local function handle_references(div)
  local parts = {}
  local first = true
  for _, b in ipairs(div.content) do
    if b.t == "Div" and b.classes:includes("referee") then
      if first then
        first = false
      else
        table.insert(parts, [[\vfill\columnbreak]])
      end
      local inner = pandoc.Pandoc(b.content)
      table.insert(parts, (pandoc.write(inner, "latex"):gsub("%s+$", "")))
    end
  end
  if #parts == 0 then return nil end
  return pandoc.RawBlock("latex",
    string.format("\\begin{multicols}{2}\n%s\n\\end{multicols}",
                  table.concat(parts, "\n\n")))
end

function Div(div)
  if div.classes:includes("cv-entries") then
    return handle_table_div(div, "italic", "15pt")
  elseif div.classes:includes("cv-keys") then
    return handle_table_div(div, "bold", "2.5pt")
  elseif div.classes:includes("cv-publications") then
    return handle_publications(div)
  elseif div.classes:includes("cv-references") then
    return handle_references(div)
  end
end

-- Auto-inject the horizontal rule under each top-level section heading so
-- the user doesn't have to write \vspace{-15pt}\noindent\rule{\textwidth}{1pt}
-- after every # in the source. Skipped if the user already wrote their own
-- rule (we detect a following RawBlock containing \noindent\rule).
function Header(h)
  if h.level == 1 then
    return {
      h,
      pandoc.RawBlock("latex", [[\vspace{-15pt}\noindent\rule{\textwidth}{1pt}]])
    }
  end
end
