_:
let
  cheatsheet = ../cheatsheet.md;
in
{
  extraConfigLua = ''
    local function show_cheatsheet()
      local path = "${cheatsheet}"
      local lines = {}

      local file = io.open(path, "r")
      if file then
        for line in file:lines() do
          table.insert(lines, line)
        end
        file:close()
      else
        lines = { "No cheatsheet found" }
      end

      Snacks.win({
        buf = (function()
          local buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
          vim.bo[buf].filetype = "markdown"
          vim.bo[buf].modifiable = false
          return buf
        end)(),
        width = 0.5,
        height = 0.7,
        border = "rounded",
        title = " Vim Cheatsheet ",
        title_pos = "center",
        keys = {
          q = "close",
          ["<Esc>"] = "close",
        },
      })
    end

    vim.keymap.set("n", "<leader>?", show_cheatsheet, { desc = "Vim Cheatsheet" })
  '';
}
