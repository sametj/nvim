return {
  'neovim/nvim-lspconfig',
  event = 'BufReadPre',
  dependencies = {
    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
  },
  opts = {
    servers = {
      tsserver = { enabled = false },
      ts_ls = { enabled = false },
      vtsls = {
        filetypes = { 'javascript', 'javascriptreact', 'javascript.jsx', 'typescript', 'typescriptreact', 'typescript.tsx' },
        settings = {
          complete_function_calls = true,
          vtsls = {
            enableMoveToFileCodeAction = true,
            autoUseWorkspaceTsdk = true,
            experimental = {
              maxInlayHintLength = 30,
              completion = {
                enableServerSideFuzzyMatch = true,
              },
            },
          },
          typescript = {
            updateImportsOnFileMove = { enabled = 'always' },
            suggest = { completeFunctionCalls = true },
            inlayHints = {
              enumMemberValues = { enabled = true },
              functionLikeReturnTypes = { enabled = true },
              parameterNames = { enabled = 'literals' },
              parameterTypes = { enabled = true },
              propertyDeclarationTypes = { enabled = true },
              variableTypes = { enabled = false },
            },
          },
        },
        keys = {
          {
            'gD',
            function()
              local params = vim.lsp.util.make_position_params()
              LazyVim.lsp.execute {
                command = 'typescript.goToSourceDefinition',
                arguments = { params.textDocument.uri, params.position },
                open = true,
              }
            end,
            desc = 'Goto Source Definition',
          },
          {
            'gR',
            function()
              LazyVim.lsp.execute {
                command = 'typescript.findAllFileReferences',
                arguments = { vim.uri_from_bufnr(0) },
                open = true,
              }
            end,
            desc = 'File References',
          },
          { '<leader>co', LazyVim.lsp.action['source.organizeImports'], desc = 'Organize Imports' },
          { '<leader>cM', LazyVim.lsp.action['source.addMissingImports.ts'], desc = 'Add missing imports' },
          { '<leader>cu', LazyVim.lsp.action['source.removeUnused.ts'], desc = 'Remove unused imports' },
          { '<leader>cD', LazyVim.lsp.action['source.fixAll.ts'], desc = 'Fix all diagnostics' },
          {
            '<leader>cV',
            function()
              LazyVim.lsp.execute { command = 'typescript.selectTypeScriptVersion' }
            end,
            desc = 'Select TS workspace version',
          },
        },
      },
    },
    setup = {
      tsserver = function()
        return true -- disables tsserver setup
      end,
      ts_ls = function()
        return true -- disables ts_ls setup
      end,
      vtsls = function(_, opts)
        -- Attach your custom commands and extend settings here if needed
        LazyVim.lsp.on_attach(function(client, buffer)
          client.commands['_typescript.moveToFileRefactoring'] = function(command, ctx)
            local action, uri, range = unpack(command.arguments)
            local function move(newf)
              client.request('workspace/executeCommand', {
                command = command.command,
                arguments = { action, uri, range, newf },
              })
            end

            local fname = vim.uri_to_fname(uri)
            client.request('workspace/executeCommand', {
              command = 'typescript.tsserverRequest',
              arguments = {
                'getMoveToRefactoringFileSuggestions',
                {
                  file = fname,
                  startLine = range.start.line + 1,
                  startOffset = range.start.character + 1,
                  endLine = range['end'].line + 1,
                  endOffset = range['end'].character + 1,
                },
              },
            }, function(_, result)
              local files = result.body.files
              table.insert(files, 1, 'Enter new path...')
              vim.ui.select(files, {
                prompt = 'Select move destination:',
                format_item = function(f)
                  return vim.fn.fnamemodify(f, ':~:.')
                end,
              }, function(f)
                if f and f:find '^Enter new path' then
                  vim.ui.input({
                    prompt = 'Enter move destination:',
                    default = vim.fn.fnamemodify(fname, ':h') .. '/',
                    completion = 'file',
                  }, function(newf)
                    if newf then
                      move(newf)
                    end
                  end)
                elseif f then
                  move(f)
                end
              end)
            end)
          end
        end, 'vtsls')

        -- Merge typescript settings to javascript
        opts.settings.javascript = vim.tbl_deep_extend('force', {}, opts.settings.typescript, opts.settings.javascript or {})
      end,
    },
  },
}
