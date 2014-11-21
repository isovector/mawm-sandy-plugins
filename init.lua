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

