local M = {}

function M.setup()
  if M.loaded or vim.fn.has("nvim-0.12") ~= 1 then return end
  local query = vim.treesitter.query
  local original = { add_predicate = query.add_predicate, add_directive = query.add_directive }
  for name, register in pairs(original) do
    query[name] = function(id, handler, opts)
      if type(opts) == "table" and opts.all == false then
        local legacy = handler
        handler = function(match, ...)
          local nodes = {}
          for capture, value in pairs(match) do
            nodes[capture] = type(value) == "table" and value[#value] or value
          end
          return legacy(nodes, ...)
        end
      end
      return register(id, handler, opts)
    end
  end
  package.loaded["nvim-treesitter.query_predicates"] = nil
  local ok, err = pcall(require, "nvim-treesitter.query_predicates")
  for name, register in pairs(original) do query[name] = register end
  assert(ok, err)
  M.loaded = true
end

return M
