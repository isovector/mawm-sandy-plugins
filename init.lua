do  -- recording
    local monitor
    local updater
    local recFormat
    local currentShot = 0
    local currentlyRecording = false

    commands.recording = {
        toggle = function()
            currentlyRecording = not currentlyRecording
            if currentlyRecording then
                if not lfs.attributes(string.format(recFormat, 0)) then
                    currentShot = 0
                end

                updater:start()
                monitor:set_markup(html("#eca4c4", "REC •"))
            else
                updater:stop()
                monitor:set_markup("")
            end
        end
    }

    function widgets.recording(path, timeout)
        recFormat = path .. "/%09d.jpg"
        monitor = wibox.widget.textbox("")

        timeout = timeout or 10

        updater = timer({ timeout = timeout })
        updater:connect_signal("timeout", function()
                local filename = string.format(recFormat, currentShot)

                if lfs.attributes(filename) then
                    currentShot = currentShot + 1
                    filename = string.format(recFormat, currentShot)
                end
                system("stitch " .. filename .. " &")
        end)

        return function(context)
            return monitor
        end
    end
end

do  -- journal
    local context = ""
    local context_widget

    ----------------------------------------------------

    local notification = { }
    local color = "#eca4c4"

    ----------------------------------------------------

    local function update_context(new)
        if not new then
            system("sleep 0.1")
            local f = io.popen("journal context")
            for line in f:lines() do
                context = line
                break
            end
            f:close()
        else
            context = new
        end

        print("new context: " .. context)
        context_widget:set_markup(html(color, context))
    end

    ----------------------------------------------------

    function propagate(timeout)
        return function()
            show_results("read 20", timeout, "Journal")
            show_results("ideas", timeout, "Ideas")
        end
    end

    function completion(text, curpos, ncomp)
        local result = { }

        local f = io.popen("journal contexts --nocolor")
        for line in f:lines() do
            table.insert(result, line)
        end
        f:close()

        return awful.completion.generic(text, curpos, ncomp, result)
    end

    function show_results(cmd, timeout, title, position)
        if notification[cmd] ~= nil then
            naughty.destroy(notification[cmd])
            notification[cmd] = nil
        end

        if type(timeout) == "number" then
            local lines = ""
            local f = io.popen("journal " .. cmd .. " --html")
            local notFirst = false
            for line in f:lines() do
                if notFirst then
                    line = "\n" .. line
                end
                notFirst = true
                lines = lines .. line
            end
            f:close()

            if lines == "\n" or lines == "" then
                return
            end

            notification[cmd] = naughty.notify({
                    text = lines,
                    title = title .. ": " .. context,
                    timeout = timeout,
                    position = position
            })
        end
    end

    function execute(cmd)
        return function(arg, not_string)
            if not not_string then
                arg = "'" .. arg:gsub("\\", "\\\\"):gsub("'", "'\"'\"'") .. "'"
            end

            awful.util.spawn_with_shell("journal " .. cmd .. " " .. arg)
            update_context()
        end
    end

    commands.journal = {
        write = function ()
            awful.prompt.run({ prompt = html("#7493d2", " Write: ") },
                prompt.widget,
                function (msg)
                    execute("write")(msg)
                    propagate(2)()
            end, nil, nil)
        end,

        idea = function ()
            awful.prompt.run({ prompt = html("#7493d2", " Idea: ") },
                prompt.widget,
            execute("open"), nil, nil)
        end,

        close = function ()
            show_results("ideas", 6, "Close", "top_left")
            awful.prompt.run({ prompt = html("#7493d2", " Close: ") },
                prompt.widget,
            execute("close"), nil, nil)
        end,

        context = function ()
            show_results("contexts", 6, "Context", "top_left")
            awful.prompt.run({ prompt = html("#7493d2", " Context: ") },
                prompt.widget,
                function(context)
                    --commitElapsedTime()
                    execute("context")(context)
                    propagate(8)()
            end, completion)
        end,

        show = propagate(8)
    }

    function widgets.journal()
        context_widget = wibox.widget.textbox()
        context_widget:set_markup("")

        context_widget:connect_signal("mouse::enter", propagate(0))
        context_widget:connect_signal("mouse::leave", propagate(false))

        update_context()
        return context_widget
    end
end

do
    local pcfb_widget
    local pcfb_timer

    local notification = nil
    local color = nil

    local function update_pcfb()
        local perc = 0

        local f = io.popen("pcfb rel")
        for line in f:lines() do
            perc = line
        end
        f:close()

        pcfb_widget:set_markup(html(color, perc .. "%"))
    end

    function alert(timeout)
        if notification ~= nil then
            naughty.destroy(notification)
            notification = nil
        end

        if type(timeout) == "number" then
            os.execute("pcfb show")

            notification = naughty.notify({
                    icon = "/tmp/pcfb.png",
                    timeout = timeout,
                    bg = "#ffffff"
            })
        end
    end

    function enable(value)
        if value then
            launch("pcfb start")
            color = "#87af5f"
        else
            launch("pcfb stop")
            color = "#e54c62"
        end

        update_pcfb()
    end


    function widgets.pcfb()
        pcfb_widget = wibox.widget.textbox()
        pcfb_timer = timer({ timeout = 60 })

        pcfb_timer:connect_signal("timeout", update_pcfb)
        pcfb_timer:start()

        pcfb_widget:connect_signal("mouse::enter", function () alert(0) end)
        pcfb_widget:connect_signal("mouse::leave", function () alert(false) end)

        enable(false)

        return pcfb_widget
    end

    commands.pcfb = {
        enable  = function() enable(true) end,
        disable = function() enable(false) end,
        show    = function() alert(4) end
    }
end

