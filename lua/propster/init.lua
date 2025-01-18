local M = {}

local commands = require("propster.commands")

function M.setup_commands()
    vim.api.nvim_create_user_command(
        'NeoPrompterStart',
        commands.setup_chat,
        { desc = "Prints a greeting message" }
    )

    vim.api.nvim_create_user_command(
        'NeoPrompterClose',
        commands.close_window,
        { desc = "Prints a greeting message" }
    )

    vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
            commands.resize_screen()
        end,
    })

    vim.api.nvim_set_keymap("n", "<leader>l", "", {
        callback = function() commands.setup_chat() end,
        desc = "Open Propster",
        noremap = true,
        silent = true,
    })

    vim.api.nvim_set_keymap("n", "<Esc>", "", {
        callback = function() commands.close_window() end,
        desc = "Close Propster",
        noremap = true,
        silent = true,
    })
end

return M
