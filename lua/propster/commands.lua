local M = {}

local https = require("ssl.https")
local json = require("dkjson") -- For JSON encoding
local ltn12 = require("ltn12") -- For source and sink handling


--local conversation_history = {}
local windows_list = {}
local is_close = true

local function create_parent_window()
    local screen_width = vim.o.columns
    local screen_height = vim.o.lines
    local win_width = math.floor(screen_width * 0.8)
    local win_height = math.floor(screen_height * 0.65)
    local row = math.floor((screen_height - win_height) / 2)
    local col = math.floor((screen_width - win_width) / 2)

    local parent_buf = vim.api.nvim_create_buf(false, true)
    local parent_opts = {
        relative = 'editor',
        width = win_width,
        height = win_height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'single'
    }

    local parent_win = vim.api.nvim_open_win(parent_buf, true, parent_opts)

    return parent_buf, parent_win
end

local function create_input_section(parent_win, relative_row, relative_col, width, height, content)
    local child_buf = vim.api.nvim_create_buf(false, true)
    local parent_config = vim.api.nvim_win_get_config(parent_win)
    local parent_width = parent_config.width
    local parent_height = parent_config.height

    local child_opts = {
        relative = 'win',
        win = parent_win,
        width = math.floor(parent_width * width),
        height = math.floor(parent_height * height),
        row = math.floor(parent_height * relative_row),
        col = relative_col,
        style = 'minimal',
        border = 'rounded'
    }

    local child_win = vim.api.nvim_open_win(child_buf, true, child_opts)
    vim.api.nvim_buf_set_lines(child_buf, 0, -1, false, content)
    vim.api.nvim_buf_set_option(child_buf, "modifiable", true)

    return child_buf, child_win
end

function M.close_window()
    if #windows_list == 0 then
        return
    end

    for _, id in ipairs(windows_list) do
        if vim.api.nvim_win_is_valid(id) then
            vim.api.nvim_win_close(id, true)
        end
    end
    windows_list = {}
    is_close = true

    vim.keymap.del('n', '<leader>q') -- Removes the normal mode keymap for <leader>cw
    vim.keymap.del('n', '<leader>d')
    vim.keymap.del('n', '<CR>')
end

function M.resize_screen()
    if (is_close == false) then
        M.close_window()
        M.setup_chat()
    end
end

function M.processing_prompt(input_buf, output_buf)
    local input = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
    local window_text = table.concat(input, "\n")

    local api_key = "AIzaSyCEL1gMB3WhZVXPjtFOedl-DT_X0OIv0xI"

    -- Check if the API key is the default (optional, based on your script)
    if api_key == "YOUR_DEFAULT_API_KEY" then
        print("Warning: Using default API key. Please set your own API_KEY.")
    end

    -- Create the payload
    local payload = {
        contents = {
            {
                role = "user",
                parts = {
                    {
                        text = window_text
                    }
                }
            }
        },
        generationConfig = {
            temperature = 1,
            topK = 40,
            topP = 0.95,
            maxOutputTokens = 8192,
            responseMimeType = "text/plain"
        }
    }

    -- Encode the payload into JSON
    local json_payload = json.encode(payload)

    -- Define the URL
    local url =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-thinking-exp-1219:generateContent?key=" ..
        api_key

    -- Make the POST request
    local response_body = {}
    local _, status_code, response_headers = https.request {
        url = url,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#json_payload), -- Set content-length header
        },
        source = ltn12.source.string(json_payload),       -- Use ltn12 to send the string as the source
        sink = ltn12.sink.table(response_body)            -- Capture the response body in the table
    }

    if status_code ~= 200 then
        print("Request failed with status: ", status_code)
    else
        local full_response = table.concat(response_body)
        local decoded, pos, err = json.decode(full_response, 1, nil)
        if err then
            print("Failed to decode JSON: ", err)
            return
        end

        local parts = decoded.candidates[1].content.parts
        local text_values = {}
        for _, part in ipairs(parts) do
            table.insert(text_values, part.text)
        end

        -- Concatenate all text values into a single string
        local full_text = table.concat(text_values, "\n")
        vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, vim.split(full_text, "\n"))
    end
end

function M.setup_chat()
    local parent_buf, parent_win = create_parent_window()
    local outPut_buf, outPut_win = create_input_section(parent_win, 0, 0, 0.98, 0.65, { "Conversation Area" })
    local input_buf, input_win   = create_input_section(parent_win, 0.71, 0, 0.98, 0.25, { "Input Area" })
    table.insert(windows_list, outPut_win)
    table.insert(windows_list, input_win)
    table.insert(windows_list, parent_win)

    vim.api.nvim_set_keymap('n', '<CR>', "",
        {
            callback = function() M.processing_prompt(input_buf, outPut_buf) end,
            desc = "Process Prompt",
            noremap = true,
            silent = true,
        }
    )

    vim.api.nvim_set_keymap("n", "<leader>q", "", {
        callback = function() vim.api.nvim_set_current_win(outPut_win) end,
        desc = "Output",
        noremap = true,
        silent = true,
    })

    vim.api.nvim_set_keymap("n", "<leader>d", "", {
        callback = function() vim.api.nvim_set_current_win(input_win) end,
        desc = "Output",
        noremap = true,
        silent = true,
    })

    is_close = false
end

return M
