local function reload_workspace(bufnr)
	local clients = vim.lsp.get_clients { bufnr = bufnr, name = 'rust_analyzer' }
	for _, client in ipairs(clients) do
		vim.notify 'Reloading Cargo Workspace'
		client:request('rust-analyzer/reloadWorkspace', nil, function(err)
			if err then
				error(tostring(err))
			end
			vim.notify 'Cargo workspace reloaded'
		end, 0)
	end
end

local function is_library(fname)
	local user_home = vim.fs.normalize(vim.env.HOME)
	local cargo_home = os.getenv('CARGO_HOME') or user_home .. '/.cargo'
	local registry = cargo_home .. '/registry/src'
	local git_registry = cargo_home .. '/git/checkouts'
	local rustup_home = os.getenv('RUSTUP_HOME') or user_home .. '/.rustup'
	local toolchains = rustup_home .. '/toolchains'

	-- Fixed syntax error: was "for *, item" and "git*registry"
	for _, item in ipairs { toolchains, registry, git_registry } do
		if fname:find('^' .. vim.pesc(item)) then
			local clients = vim.lsp.get_clients { name = 'rust_analyzer' }
			return #clients > 0 and clients[#clients].config.root_dir or nil
		end
	end

	-- Also check for Homebrew rust installations
	local homebrew_rust = '/opt/homebrew/Cellar/rust'
	if fname:find('^' .. vim.pesc(homebrew_rust)) then
		local clients = vim.lsp.get_clients { name = 'rust_analyzer' }
		return #clients > 0 and clients[#clients].config.root_dir or nil
	end
end

vim.lsp.config('rust_analyzer', {
	cmd = { 'rust-analyzer' },
	filetypes = { 'rust' },
	root_dir = function(bufnr, on_dir)
		local fname = vim.api.nvim_buf_get_name(bufnr)

		-- Check if this is a library/dependency file
		local reused_dir = is_library(fname)
		if reused_dir then
			on_dir(reused_dir)
			return
		end

		-- Look for Cargo.toml for user projects
		local cargo_crate_dir = vim.fs.root(fname, { 'Cargo.toml' })
		if cargo_crate_dir == nil then
			-- No Cargo.toml found, try other methods
			on_dir(
				vim.fs.root(fname, { 'rust-project.json' })
				or vim.fs.dirname(vim.fs.find('.git', { path = fname, upward = true })[1])
				or vim.fs.dirname(fname)
			)
			return
		end

		-- Found Cargo.toml, try to get workspace root using cargo metadata
		local cmd = {
			'cargo',
			'metadata',
			'--no-deps',
			'--format-version',
			'1',
			'--manifest-path',
			cargo_crate_dir .. '/Cargo.toml',
		}

		vim.system(cmd, { text = true }, function(output)
			if output.code == 0 and output.stdout then
				local success, result = pcall(vim.json.decode, output.stdout)
				if success and result and result['workspace_root'] then
					local workspace_root = vim.fs.normalize(result['workspace_root'])
					on_dir(workspace_root)
				else
					on_dir(cargo_crate_dir)
				end
			else
				-- cargo metadata failed, but we still have a valid Cargo.toml
				-- This can happen with malformed manifests or missing dependencies
				-- Just use the crate directory
				on_dir(cargo_crate_dir)

				-- Only show error for non-library paths to avoid spam
				if not is_library(fname) then
					vim.schedule(function()
						vim.notify(
							string.format('[rust_analyzer] cargo metadata failed (code %d), using Cargo.toml directory instead',
								output.code),
							vim.log.levels.WARN
						)
					end)
				end
			end
		end)
	end,
	settings = {
		['rust-analyzer'] = {
			cargo = {
				allFeatures = true,
			},
			diagnostics = {
				enable = true,
				experimental = {
					enable = true,
				},
			},
			formatting = {
				enable = true,
			},
			completion = {
				callable = {
					snippets = "fill_arguments",
				},
			},
			hover = {
				actions = {
					enable = true,
				},
			},
			inlayHints = {
				enable = true,
			},
		},
	},
	capabilities = {
		experimental = {
			serverStatusNotification = true,
		},
	},
	before_init = function(init_params, config)
		-- See https://github.com/rust-lang/rust-analyzer/blob/eb5da56d839ae0a9e9f50774fa3eb78eb0964550/docs/dev/lsp-extensions.md?plain=1#L26
		if config.settings and config.settings['rust-analyzer'] then
			init_params.initializationOptions = config.settings['rust-analyzer']
		end
	end,
	on_attach = function(_, bufnr)
		vim.api.nvim_buf_create_user_command(bufnr, 'LspCargoReload', function()
			reload_workspace(bufnr)
		end, { desc = 'Reload current cargo workspace' })
	end,
})
