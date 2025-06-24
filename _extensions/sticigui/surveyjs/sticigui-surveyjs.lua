-- SticIGui SurveyJS Extension for Quarto
-- Simple implementation that loads and renders SurveyJS from JSON files

local function load_file(file_path)
  local file = io.open(file_path, "r")
  if not file then
    return nil
  end
  local content = file:read("*all")
  file:close()
  return content
end

local function substitute_placeholders(template, substitutions)
  local result = template
  for placeholder, value in pairs(substitutions) do
    -- Escape % characters in value to prevent gsub interpretation issues
    local escaped_value = value:gsub("%%", "%%%%")
    result = result:gsub("{{" .. placeholder .. "}}", escaped_value)
  end
  return result
end

local function list_json_files(dir)
  local files = {}
  if pandoc.system and pandoc.system.list_directory then
    for _, file in ipairs(pandoc.system.list_directory(dir)) do
      if file:match("%.json$") then
        table.insert(files, dir .. "/" .. file)
      end
    end
  else
    -- fallback: use ls shell command
    local result = pandoc.pipe("ls", {"-1", dir}, "")
    for file in result:gmatch("[^\n]+") do
      if file:match("%.json$") then
        table.insert(files, dir .. "/" .. file)
      end
    end
  end
  return files
end

return {
  ['sticigui-surveyjs'] = function(args, kwargs, meta)
    -- Ignore theme parameter if present
    kwargs.theme = nil

    local file_path = pandoc.utils.stringify(kwargs.file or "")
    local dir_path = pandoc.utils.stringify(kwargs.directory or "")
    local randomize = pandoc.utils.stringify(kwargs.random or "0") == "1"

    if dir_path ~= "" then
      local files = list_json_files(dir_path)
      if #files == 0 then
        return pandoc.RawBlock('html', '<div class="alert alert-warning">No JSON files found in directory: ' .. dir_path .. '</div>')
      end
      if randomize then
        math.randomseed(os.time() + math.random(1000,9999))
        file_path = files[math.random(#files)]
      else
        table.sort(files)
        file_path = files[1]
      end
    end

    if file_path == "" then
      return pandoc.RawBlock('html', '<div class="alert alert-warning">No file specified for SurveyJS</div>')
    end

    local file = io.open(file_path, "r")
    if not file then
      return pandoc.RawBlock('html', '<div class="alert alert-warning">Could not open file: ' .. file_path .. '</div>')
    end
    local json_content = file:read("*all")
    file:close()

    local survey_id = "survey_" .. os.time() .. math.random(1000, 9999)
    local template_path = "_extensions/sticigui/surveyjs/survey-template.html"
    local template = load_file(template_path)
    if not template then
      return pandoc.RawBlock('html', '<div class="alert alert-warning">Could not load survey template</div>')
    end

    -- Load and inline the JS functions file
    -- I don't think there's a way to configure quarto to bundle this up into the output as with CSS
    local js_path = "_extensions/sticigui/surveyjs/sticigui-functions.js"
    local js_code = load_file(js_path)
    local js_tag = ""
    if js_code then
      js_tag = "<script>\n" .. js_code .. "\n</script>\n"
    end

    local html = substitute_placeholders(template, {
      SURVEY_ID = survey_id,
      SURVEY_JSON = json_content
    })

    -- Prepend the JS tag to the HTML output
    html = js_tag .. html

    return pandoc.RawBlock('html', html)
  end
}
