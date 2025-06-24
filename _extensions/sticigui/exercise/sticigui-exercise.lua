return {
  ['sticigui-exercise'] = function(args, kwargs, meta, raw_args, context)
    if not (kwargs and kwargs.set and meta[kwargs.set]) then
      local html = '<div class="callout callout-warning"><div class="callout-body"><strong>Exercise error:</strong> No exercise data found in metadata. Ensure the YAML file is included via metadata-files.</div></div>'
      return pandoc.RawBlock('html', html)
    end
    local set = meta[kwargs.set]
    local question = pandoc.utils.stringify(set.question)
    local exercises = set.exercises
    if exercises and exercises.c then exercises = exercises.c end
    if not exercises or #exercises == 0 then
      local html = '<div class="callout callout-warning"><div class="callout-body"><strong>Exercise error:</strong> No exercises found in YAML file.</div></div>'
      return pandoc.RawBlock('html', html)
    end
    -- Determine if random selection is requested (for choice randomization)
    -- Support both exercise-set level (legacy) and exercise-level randomization
    local set_random = set.random == true or set.random == 'true'
    
    local ex_idx = 1
    -- For legacy compatibility, still support exercise-level randomization if no inputs
    local ex = exercises[ex_idx]
    if ex and not ex.inputs then
      if set_random then
        math.randomseed(os.time() + math.random(100000))
        ex_idx = math.random(1, #exercises)
        ex = exercises[ex_idx]
      end
    end
    -- Helper function to randomize choices if random is enabled
    local function get_choices(input_choices, should_randomize)
      local choices = input_choices or {'Valid', 'Fallacious'}
      if should_randomize then
        local shuffled = {}
        for i, choice in ipairs(choices) do
          local val = pandoc.utils.stringify(choice)
          table.insert(shuffled, val)
        end
        -- Fisher-Yates shuffle
        for i = #shuffled, 2, -1 do
          local j = math.random(i)
          shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end
        return shuffled
      else
        local result = {}
        for i, choice in ipairs(choices) do
          result[i] = pandoc.utils.stringify(choice)
        end
        return result
      end
    end
    
    -- If the exercise has 'inputs', check if we should show one or all
    if ex and ex.inputs then
      local ex_question = ex.question and pandoc.utils.stringify(ex.question) or question
      local inputs = ex.inputs
      if inputs and inputs.c then inputs = inputs.c end
      if not inputs or #inputs == 0 then
        local html = '<div class="callout callout-warning"><div class="callout-body"><strong>Exercise error:</strong> No sub-questions found in YAML file.</div></div>'
        return pandoc.RawBlock('html', html)
      end
      
      -- Check for exercise-level randomization, fallback to set-level
      local ex_random = ex.random == true or ex.random == 'true' or set_random
      
      -- If random is true, select a single input instead of showing all
      if ex_random then
        math.randomseed(os.time() + math.random(100000))
        local selected_idx = math.random(1, #inputs)
        local selected_input = inputs[selected_idx]
        
        -- Treat selected input as a single statement exercise
        local prompt = pandoc.utils.stringify(selected_input.prompt)
        local answer = pandoc.utils.stringify(selected_input.answer)
        local explanation = pandoc.utils.stringify(selected_input.explanation)
        local input_type = selected_input.type and pandoc.utils.stringify(selected_input.type) or 'dropdown'
        local correct = answer == 'Valid' and 0 or 1
        
        -- Check for input-level randomization for choice order
        local input_random = selected_input.random == true or selected_input.random == 'true'
        local choices = get_choices({'Valid', 'Fallacious'}, input_random)
        
        -- Update correct answer index if choices were randomized
        for i, choice in ipairs(choices) do
          if choice == answer then
            correct = i - 1
            break
          end
        end
        
        local uniq = tostring(os.time()) .. tostring(math.random(100000,999999))
        local input_name = 'answer_' .. uniq
        local html = string.format([[<div class="callout callout-tip callout-style-default callout-tip callout-appearance-minimal">
  <div class="callout-body">
    <p><strong>Exercise:</strong> %s</p>
    <div class="logic-exercise-statement"><em>%s</em></div>
    <div id="logic-exercise-%s"></div>
    <script type="text/javascript">
    (function() {
      const choices = %s;
      const correct = %d;
      const explanation = %s;
      const inputType = '%s';
      const uniq = '%s';
      function renderExercise() {
        let inputHtml = '';
        if (inputType === 'select' || inputType === 'dropdown') {
          inputHtml = `<select id="logic-select-${uniq}" class="form-select form-select-sm logic-exercise-select">`;
          inputHtml += '<option value="">Select...</option>';
          for (let i = 0; i < choices.length; ++i) {
            inputHtml += `<option value="${i}">${choices[i]}</option>`;
          }
          inputHtml += '</select>';
        } else if (inputType === 'checkbox') {
          inputHtml = '<div class="logic-exercise-checkbox-group">';
          for (let i = 0; i < choices.length; ++i) {
            inputHtml += `<div class="form-check"><input type="checkbox" class="form-check-input" name="choice-${uniq}" id="choice-${uniq}-${i}" value="${i}">`;
            inputHtml += `<label class="form-check-label" for="choice-${uniq}-${i}">${choices[i]}</label></div>`;
          }
          inputHtml += '</div>';
        } else if (inputType === 'button') {
          inputHtml = '<div class="btn-group logic-exercise-btn-group" role="group">';
          for (let i = 0; i < choices.length; ++i) {
            inputHtml += `<input type="radio" class="btn-check" name="%s" id="choice-${uniq}-${i}" autocomplete="off" value="${i}">`;
            inputHtml += `<label class="btn btn-outline-primary logic-exercise-btn" for="choice-${uniq}-${i}">${choices[i]}</label>`;
          }
          inputHtml += '</div>';
        }
        document.getElementById('logic-exercise-' + uniq).innerHTML = `
          <form id="logic-form-%s">
            ${inputHtml}
            <button type="submit" class="btn btn-secondary btn-sm check-answer-btn">Check Answer</button>
            <button type="button" id="solution-btn-%s" class="btn btn-info btn-sm solution-btn">Solution <span class="solution-arrow">&#x25BC;</span></button>
          </form>
          <div id="logic-feedback-%s" class="logic-feedback"></div>
          <div id="logic-solution-%s" class="logic-solution"></div>
        `;
        document.getElementById('logic-form-' + uniq).onsubmit = function(e) {
          e.preventDefault();
          let val = null;
          if (inputType === 'dropdown') {
            val = document.getElementById('logic-select-' + uniq).value;
          } else if (inputType === 'button') {
            const checked = document.querySelector('#logic-form-' + uniq + ' input[name="%s"]:checked');
            if (checked) val = checked.value;
          }
          if (val === null || val === '') return;
          const feedback = (parseInt(val) === correct)
            ? `<span style=\"color:green;\">Correct!</span>`
            : `<span style=\"color:red;\">Incorrect.</span>`;
          document.getElementById('logic-feedback-' + uniq).innerHTML = feedback;
        };
        document.getElementById('solution-btn-' + uniq).onclick = function(e) {
          const btn = document.getElementById('solution-btn-' + uniq);
          const arrow = btn.querySelector('.solution-arrow');
          if (btn.getAttribute('data-bs-toggle') === 'popover') {
            // Hide popover
            bootstrap.Popover.getInstance(btn).dispose();
            btn.removeAttribute('data-bs-toggle');
            btn.removeAttribute('data-bs-placement');
            btn.removeAttribute('data-bs-html');
            btn.removeAttribute('data-bs-content');
            if (arrow) arrow.innerHTML = '\u25BC'; // ▼
          } else {
            // Show popover
            btn.setAttribute('data-bs-toggle', 'popover');
            btn.setAttribute('data-bs-placement', 'bottom');
            btn.setAttribute('data-bs-html', 'true');
            btn.setAttribute('data-bs-content', explanation);
            if (arrow) arrow.innerHTML = '\u25B2'; // ▲
            new bootstrap.Popover(btn, {trigger: 'focus', placement: 'bottom', html: true, content: explanation});
            btn.focus();
          }
        };
      }
      renderExercise();
    })();
    </script>
  </div>
</div>
]],
          ex_question,
          prompt,
          uniq,
          pandoc.utils.stringify(pandoc.json.encode(choices)),
          tonumber(correct),
          pandoc.utils.stringify(pandoc.json.encode(explanation)),
          input_type,
          uniq,
          input_name,
          uniq,
          uniq,
          uniq,
          uniq,
          uniq,
          input_name
        )
        return pandoc.RawBlock('html', html)
      end
      
      -- Display all inputs simultaneously (automatic multi-display)
      local uniq = tostring(os.time()) .. tostring(math.random(100000,999999))
      local inputs_html = ''
      local answers = {}
      local explanations = {}
      
      for i, input in ipairs(inputs) do
        local prompt = pandoc.utils.stringify(input.prompt)
        local input_type = input.type and pandoc.utils.stringify(input.type) or 'dropdown'
        
        -- Check for input-level randomization, fallback to exercise-level, then set-level
        local input_random = input.random == true or input.random == 'true' or ex_random
        local choices = get_choices(input.choices, input_random)
        
        local answer = input.answer and pandoc.utils.stringify(input.answer) or ''
        local explanation = input.explanation and pandoc.utils.stringify(input.explanation) or ''
        local input_name = 'input_' .. uniq .. '_' .. i
        
        answers[i] = answer
        explanations[i] = explanation
        
        local input_html = ''
        if input_type == 'select' or input_type == 'dropdown' then
          input_html = string.format('<select name="%s" id="%s" class="form-select form-select-sm logic-exercise-select">', input_name, input_name)
          input_html = input_html .. '<option value="">Select...</option>'
          for j = 1, #choices do
            input_html = input_html .. string.format('<option value="%s">%s</option>', choices[j], choices[j])
          end
          input_html = input_html .. '</select>'
        elseif input_type == 'checkbox' then
          input_html = '<div class="logic-exercise-checkbox-group">'
          for j = 1, #choices do
            local checkbox_id = string.format('%s_%d', input_name, j)
            input_html = input_html .. string.format('<div class="form-check"><input type="checkbox" class="form-check-input" name="%s" id="%s" value="%s">', input_name, checkbox_id, choices[j])
            input_html = input_html .. string.format('<label class="form-check-label" for="%s">%s</label></div>', checkbox_id, choices[j])
          end
          input_html = input_html .. '</div>'
        elseif input_type == 'button' then
          input_html = '<div class="btn-group logic-exercise-btn-group" role="group">'
          for j = 1, #choices do
            local btn_id = string.format('%s_%d', input_name, j)
            input_html = input_html .. string.format('<input type="radio" class="btn-check" name="%s" id="%s" autocomplete="off" value="%s">', input_name, btn_id, choices[j])
            input_html = input_html .. string.format('<label class="btn btn-outline-primary logic-exercise-btn" for="%s">%s</label>', btn_id, choices[j])
          end
          input_html = input_html .. '</div>'
        end
        
        inputs_html = inputs_html .. string.format([[
<div class="logic-exercise-item%s">
  <div class="logic-exercise-prompt">%s</div>
  <div class="logic-exercise-input">%s</div>
  <button type="button" class="btn btn-secondary btn-sm check-answer-btn" onclick="checkAnswer(%d, '%s')">Check Answer</button>
  <button type="button" class="btn btn-info btn-sm solution-btn" onclick="showSolution(%d, '%s')">Solution</button>
  <div id="logic-feedback-%s-%d" class="logic-feedback"></div>
  <div id="logic-solution-%s-%d" class="logic-solution"></div>
</div>
]], input_type == 'checkbox' and ' checkbox-input' or '', prompt, input_html, i, uniq, i, uniq, uniq, i, uniq, i)
      end
        
      local html = string.format([[<div class="callout callout-tip callout-style-default callout-tip callout-appearance-minimal">
  <div class="callout-body">
    <p><strong>Exercise:</strong> %s</p>
    <div id="logic-form-%s">
      %s
    </div>
    <script type="text/javascript">
    (function() {
      const answers = %s;
      const explanations = %s;
      const uniq = '%s';
      
      window.checkAnswer = function(inputIndex, uniqueId) {
        if (uniqueId !== uniq) return;
        const inputName = 'input_' + uniq + '_' + inputIndex;
        let val = '';
        const el = document.getElementsByName(inputName);
        if (el.length > 0) {
          if (el[0].type === 'radio') {
            const checked = Array.from(el).find(x => x.checked);
            if (checked) val = checked.value;
          } else if (el[0].type === 'checkbox') {
            const checked = Array.from(el).filter(x => x.checked);
            val = checked.map(x => x.value).sort().join(',');
          } else {
            val = el[0].value;
          }
        }
        let feedback = '';
        let expectedAnswer = answers[inputIndex - 1];
        // Handle array answers for checkbox inputs
        if (Array.isArray(expectedAnswer)) {
          expectedAnswer = expectedAnswer.sort().join(',');
        }
        if (val === '' || val != expectedAnswer) {
          feedback = '<span style="color:red;">Incorrect.</span>';
        } else {
          feedback = '<span style="color:green;">Correct!</span>';
        }
        document.getElementById('logic-feedback-' + uniq + '-' + inputIndex).innerHTML = feedback;
      };
      
      window.showSolution = function(inputIndex, uniqueId) {
        if (uniqueId !== uniq) return;
        document.getElementById('logic-solution-' + uniq + '-' + inputIndex).innerHTML = explanations[inputIndex - 1];
      };
    })();
    </script>
  </div>
</div>
]],
        ex_question,
        uniq,
        inputs_html,
        pandoc.utils.stringify(pandoc.json.encode(answers)),
        pandoc.utils.stringify(pandoc.json.encode(explanations)),
        uniq
      )
      return pandoc.RawBlock('html', html)
    end
    -- If not multi-input, treat as single-statement exercise (legacy style)
    local statement = pandoc.utils.stringify(ex.statement)
    local answer = pandoc.utils.stringify(ex.answer)
    local explanation = pandoc.utils.stringify(ex.explanation)
    local ex_type = ex.type and pandoc.utils.stringify(ex.type) or nil
    local correct = answer == 'Valid' and 0 or 1
    
    -- Check for exercise-level randomization, fallback to set-level
    local ex_random = ex.random == true or ex.random == 'true' or set_random
    local choices = get_choices({'Valid', 'Fallacious'}, ex_random)
    -- Update correct answer index if choices were randomized
    for i, choice in ipairs(choices) do
      if choice == answer then
        correct = i - 1
        break
      end
    end
    local input_type = ex_type or 'dropdown'
    local uniq = tostring(os.time()) .. tostring(math.random(100000,999999))
    local input_name = 'answer_' .. uniq
    local html = string.format([[<div class="callout callout-tip callout-style-default callout-tip callout-appearance-minimal">
  <div class="callout-body">
    <p><strong>Exercise:</strong> %s</p>
    <div class="logic-exercise-statement"><em>%s</em></div>
    <div id="logic-exercise-%s"></div>
    <script type="text/javascript">
    (function() {
      const choices = %s;
      const correct = %d;
      const explanation = %s;
      const inputType = '%s';
      const uniq = '%s';
      function renderExercise() {
        let inputHtml = '';
        if (inputType === 'dropdown') {
          inputHtml = `<select id="logic-select-${uniq}" class="form-select form-select-sm logic-exercise-select">`;
          inputHtml += '<option value="">Select...</option>';
          for (let i = 0; i < choices.length; ++i) {
            inputHtml += `<option value="${i}">${choices[i]}</option>`;
          }
          inputHtml += '</select>';
        } else if (inputType === 'button') {
          inputHtml = '<div class="btn-group logic-exercise-btn-group" role="group">';
          for (let i = 0; i < choices.length; ++i) {
            inputHtml += `<input type="radio" class="btn-check" name="%s" id="choice-${uniq}-${i}" autocomplete="off" value="${i}">`;
            inputHtml += `<label class="btn btn-outline-primary logic-exercise-btn" for="choice-${uniq}-${i}">${choices[i]}</label>`;
          }
          inputHtml += '</div>';
        }
        document.getElementById('logic-exercise-' + uniq).innerHTML = `
          <form id="logic-form-%s">
            ${inputHtml}
            <button type="submit" class="btn btn-secondary btn-sm check-answer-btn">Check Answer</button>
            <button type="button" id="solution-btn-%s" class="btn btn-info btn-sm solution-btn">Solution <span class="solution-arrow">&#x25BC;</span></button>
          </form>
          <div id="logic-feedback-%s" class="logic-feedback"></div>
          <div id="logic-solution-%s" class="logic-solution"></div>
        `;
        document.getElementById('logic-form-' + uniq).onsubmit = function(e) {
          e.preventDefault();
          let val = null;
          if (inputType === 'dropdown') {
            val = document.getElementById('logic-select-' + uniq).value;
          } else if (inputType === 'button') {
            const checked = document.querySelector('#logic-form-' + uniq + ' input[name="%s"]:checked');
            if (checked) val = checked.value;
          }
          if (val === null || val === '') return;
          const feedback = (parseInt(val) === correct)
            ? `<span style=\"color:green;\">Correct!</span>`
            : `<span style=\"color:red;\">Incorrect.</span>`;
          document.getElementById('logic-feedback-' + uniq).innerHTML = feedback;
        };
        document.getElementById('solution-btn-' + uniq).onclick = function(e) {
          const btn = document.getElementById('solution-btn-' + uniq);
          const arrow = btn.querySelector('.solution-arrow');
          if (btn.getAttribute('data-bs-toggle') === 'popover') {
            // Hide popover
            bootstrap.Popover.getInstance(btn).dispose();
            btn.removeAttribute('data-bs-toggle');
            btn.removeAttribute('data-bs-placement');
            btn.removeAttribute('data-bs-html');
            btn.removeAttribute('data-bs-content');
            if (arrow) arrow.innerHTML = '\u25BC'; // ▼
          } else {
            // Show popover
            btn.setAttribute('data-bs-toggle', 'popover');
            btn.setAttribute('data-bs-placement', 'bottom');
            btn.setAttribute('data-bs-html', 'true');
            btn.setAttribute('data-bs-content', explanation);
            if (arrow) arrow.innerHTML = '\u25B2'; // ▲
            new bootstrap.Popover(btn, {trigger: 'focus', placement: 'bottom', html: true, content: explanation});
            btn.focus();
          }
        };
      }
      renderExercise();
    })();
    </script>
  </div>
</div>
]],
      question,
      statement,
      uniq,
      pandoc.utils.stringify(pandoc.json.encode(choices)),
      tonumber(correct),
      pandoc.utils.stringify(pandoc.json.encode(explanation)),
      input_type,
      uniq,
      input_name,
      uniq,
      uniq,
      uniq,
      uniq,
      uniq,
      uniq,
      input_name
    )
    return pandoc.RawBlock('html', html)
  end
}
