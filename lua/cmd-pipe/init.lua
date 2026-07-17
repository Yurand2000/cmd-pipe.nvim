local M = {}

function M.setup(module_opts)
	module_opts = module_opts or {}

	local buf_data_to_string = function(lines)
		local text = table.concat(lines, "\n")
		return text
	end

	local string_to_buf_data = function(s)
		local lines = vim.split(s, "\n", { plain = true })
		return lines
	end

	local read_buffer = function(buffer_id)
		local lines = vim.api.nvim_buf_get_lines(buffer_id, 0, -1, false)
		return buf_data_to_string(lines)
	end

	local split_at_whitespaces = function(str)
		local t = {}
		for w in string.gmatch(str, "%S+") do
			table.insert(t, w)
		end
		return t
	end

	local pipe_fn = function(name, args, opts)
		-- Get current buffer contents
		local curr_buf = vim.api.nvim_get_current_buf()
		local curr_text = read_buffer(curr_buf)

		-- Get explicit file buffer contents
		local buffer_file_pattern = "^%$%$(%d+)$"
		local self_buffer_file_pattern = "^%$%$$"
		local tmpdir = vim.uv.os_tmpdir()
		for argno = 1, #args, 1 do
			local buf_id = nil
			if string.match(args[argno], self_buffer_file_pattern) then
				buf_id = vim.api.nvim_get_current_buf()
			end
			if not buf_id then
				buf_id = tonumber(string.match(args[argno], buffer_file_pattern), 10)
			end

			if not buf_id then
				goto continue
			end

			if not vim.api.nvim_buf_is_valid(buf_id) then
				vim.notify(
					string.format("'%s %s' unknown buffer %s", name, args[1], args[argno]),
					vim.log.levels.ERROR
				)
				print(string.format("Unknown buffer: %s", args[argno]))
				return
			end

			local text = read_buffer(buf_id)

			-- Create temporary file
			local fd, path = vim.uv.fs_mkstemp(tmpdir .. "/XXXXXX")
			if not fd then
				vim.notify(
					string.format("'%s %s' internal error: failed creating tmp file", name, args[1]),
					vim.log.levels.ERROR
				)
				print(string.format("Internal error: failed creating tmp file %s; err: %s", tmpdir .. "XXXXXX", path))
				return
			end

			local _, err = vim.uv.fs_write(fd, text)
			if err then
				vim.notify(
					string.format("'%s %s' internal error: failed writing to tmp file", name, args[1]),
					vim.log.levels.ERROR
				)
				print(string.format("Internal error: failed writing to tmp file %s; err: %s", path, err))
				return
			end

			args[argno] = path

			::continue::
		end

		-- Run shell command
		local sh_args = table.concat(args, " ")
		local res = { stdout = "", stderr = "" }

		-- Create timer for Async notifications
		local timer = vim.uv.new_timer()
		local timer_delay_ms = 300
		local print_delay_ms = 1000
		if not timer then
			vim.notify(
				string.format("'%s %s' internal error: failed creating timer", name, args[1]),
				vim.log.levels.ERROR
			)
			print("Internal error: failed creating timer")
			return
		end

		local timer_note_id = nil
		if MiniNotify and not opts.sync then
			timer_note_id = MiniNotify.add("")
		end

		local on_exit = function()
			if res.code ~= 0 then
				vim.notify(
					string.format("'%s %s' execution error...", name, args[1]),
					vim.log.levels.ERROR
				)
				print(string.format("Error executing: %s", sh_args))
				print(string.format("Status Code %d: %s", res.code, res.stderr))
				return
			end

			-- Create new buffer
			local new_buf = vim.api.nvim_create_buf(true, false)
			if new_buf == 0 then
				vim.notify(
					string.format("'%s %s' internal error: failed creating new buffer", name, args[1]),
					vim.log.levels.ERROR
				)
				print("Internal error: failed creating new buffer")
				return
			end

			-- Fill new buffer
			local new_lines = string_to_buf_data(res.stdout)
			vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, new_lines)

			timer:stop()
			timer:close()
			if opts.sync then
				vim.api.nvim_set_current_buf(new_buf)
			else
				if timer_note_id then
					MiniNotify.remove(timer_note_id)
				end
				vim.notify(
					string.format("'%s %s' executed, new buffer with id %d created", name, args[1], new_buf),
					vim.log.levels.INFO
				)
			end
		end

		local job = vim.fn.jobstart(
			sh_args,
			{
				stderr_buffered = true,
				stdout_buffered = true,
				on_stderr= function (_, data)
					local t = {}
					for i, v in ipairs(data) do
						if v and v ~= "" then t[i] = v end
					end
					res.stderr = table.concat(t, "\n")
				end,
				on_stdout= function (_, data)
					local t = {}
					for i, v in ipairs(data) do
						if v and v ~= "" then t[i] = v end
					end
					res.stdout = table.concat(t, "\n")
				end,
				on_exit= function(_, code)
					res.code = code
					on_exit()
				end,
			})

		if not (job > 0) then
			vim.notify(
				string.format("'%s %s' execution error...", name, args[1]),
				vim.log.levels.ERROR
			)
			print(string.format("Error executing: %s", sh_args))
			print(string.format("Code %d", job))
			return
		end

		vim.fn.chansend(job, curr_text)
		vim.fn.chanclose(job, "stdin")

		local running = "|"
		if not opts.sync then
			timer:start(timer_delay_ms, timer_delay_ms, function ()
				if timer_note_id then
					MiniNotify.update(timer_note_id, {
						msg = string.format("[%s] ':%s %s' running...", running, name, args[1])
					})
				else
					vim.notify(
						string.format("[%s] ':%s %s' running...", running, name, args[1]),
						vim.log.levels.INFO
					)
				end

				if running == "|" then running = "/"
				elseif running == "/" then running = "-"
				elseif running == "-" then running = "\\"
				elseif running == "\\" then running = "|"
				end
			end)
		else
			while vim.fn.jobwait({ job }, print_delay_ms)[1] == -1 do
				vim.api.nvim_echo({{string.format("[%s] Waiting for :%s %s", running, name, sh_args)}}, false, {})

				if running == "|" then running = "/"
				elseif running == "/" then running = "-"
				elseif running == "-" then running = "\\"
				elseif running == "\\" then running = "|"
				end
			end
		end
	end

	vim.api.nvim_create_user_command(
		'Pipe',
		function(args)
			pipe_fn(args.name, args.fargs, { sync = true })
		end,
		{
			nargs = '+',
			complete = 'shellcmdline',
		})

	vim.api.nvim_create_user_command(
		'PipeA',
		function(args)
			pipe_fn(args.name, args.fargs, { sync = false })
		end,
		{
			nargs = '+',
			complete = 'shellcmdline',
		})

	local pipe_buf_cmd_prelude = function (args)
		local buf_id = vim.api.nvim_get_current_buf()
		if #args.fargs == 1 then
			buf_id = tonumber(args.fargs[1], 10)
			if not buf_id then
				vim.notify(
					string.format("'%s' error: '%s' not a valid buffer", args.name, args.fargs[1]),
					vim.log.levels.ERROR
				)
				print(string.format("Error: %s not a valid buffer", args.fargs[1]))
				return nil
			end
		end

		return split_at_whitespaces(read_buffer(buf_id))
	end

	vim.api.nvim_create_user_command(
		'PipeBuf',
		function(args)
			local cmd_args = pipe_buf_cmd_prelude(args)
			if not cmd_args then return end
			pipe_fn(args.name, cmd_args, { sync = true })
		end,
		{
			nargs = '?',
		})

	vim.api.nvim_create_user_command(
		'PipeBufA',
		function(args)
			local cmd_args = pipe_buf_cmd_prelude(args)
			if not cmd_args then return end
			pipe_fn(args.name, cmd_args, { sync = false })
		end,
		{
			nargs = '?',
		})

end

return M
