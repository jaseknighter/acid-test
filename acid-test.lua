-- acid test
if not string.find(package.cpath, "/home/we/dust/code/acid-test/lib/") then
    package.cpath = package.cpath .. ";/home/we/dust/code/acid-test/lib/?.so"
end
json = require("cjson")
lattice_ = require("lattice")
s = require("sequins")
mm = include("acid-test/lib/mm")
design = include("acid-test/lib/design")
musicutil = require("musicutil")

note_last = nil

function init()
    designs = {}
    for i = 1, 2 do
        table.insert(designs, design:new())
        designs[i]:sequence(16)
    end
    designs[2]:randomize(0.1)
    for i = 1, 2 do
        designs[i]:sequence(16)
    end
    design_current = 1
    design_compare = {1, 2}

    -- setup midi
    midis = {}
    midi_devices = {"none"}
    for i, dev in pairs(midi.devices) do
        local name = string.lower(dev.name)
        name = name:gsub("-", "")
        print("connected to " .. name)
        table.insert(midi_devices, name)
        table.insert(midis, {
            last_note = nil,
            name = name,
            conn = midi.connect(dev.port)
        })
        for j = 1, 127 do
            if midis[#midis].conn ~= nil then
                midis[#midis].conn:note_off(j)
            end
        end
    end

    -- initialize lattice
    lattice = lattice_:new()

    lattice_pattern = lattice:new_pattern{
        action = function()
            local v = designs[design_compare[design_current]].seq()
            if next(v) == nil then
                do
                    return
                end
            end
            play(v)
        end,
        division = 1 / 16

    }
    lattice:new_pattern{
        action = function()
            designs[1]:sequence(16, math.random(0,2))
        end,
        division = 2
    }

    clock.run(function()
        while true do
            clock.sleep(1 / 10)
            redraw()
        end
    end)

    redraw()
    lattice:start()

end

function cleanup()
    for _, m in pairs(midis) do
        for j = 1, 127 do
            if m.conn ~= nil then
                m.conn:note_off(j)
            end
        end
    end
end

function key(k, z)
    if k > 1 then
        designs[k - 1]:randomize(0)
        designs[k - 1]:sequence(16, 3)
    end
end

function play(v)
    local m = midis[2]
    if m == nil then
        do
            return
        end
    end
    local do_note_off = v.legato == 0 -- rest
    do_note_off = do_note_off or (v.legato == 1) -- new note
    if note_last ~= nil then
        do_note_off = do_note_off or (v.legato == 2 and note_last ~= v.note) -- changing note, but hold
    end
    if do_note_off then
        do_note_off = note_last
    else
        do_note_off = nil
    end

    local velocity = math.random(60 - 5, 60 + 5) -- TODO: make the +5 optional
    if v.accent then
        velocity = velocity + math.random(30 - 5, 30 + 5)
    end
    if v.slide then
        m.conn:cc(5, 20)
    else
        m.conn:cc(5, 0)
    end

    if v.legato == 1 or (v.legato == 2 and note_last ~= v.note) then
        -- new note 
        --print("note on: " .. v.note)
        m.conn:note_on(v.note, velocity)
        note_last = v.note
    end

    if do_note_off then
        -- rest / new note
        if note_last ~= nil then
            -- print("note off: "..do_note_off)
            m.conn:note_off(do_note_off)
            note_last = nil
        end
    end

end

function redraw()
    screen.clear()
    for i = 1, 2 do
        designs[design_compare[i]]:draw(10 + (i - 1) * 64, 10, 64 - 10, 64 - 10, i == design_current and 10 or 3)
    end
    screen.update()
end
