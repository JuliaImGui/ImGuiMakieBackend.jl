function ImGui_ImplGlfw_ErrorCallback(code::Cint, description::Ptr{Cchar})::Cvoid
    @error "GLFW ERROR: code $code msg: $(unsafe_string(description))"
    return nothing
end

function ImGui_ImplGlfw_MouseButtonCallback(window::GLFW.Window, button, action, mods)
    io::Ptr{ImGuiIO} = igGetIO()
    ctx = unsafe_pointer_to_objref(unsafe_load(io.UserData))
    if ctx.PrevUserCallbackMousebutton != C_NULL
        ccall(ctx.PrevUserCallbackMousebutton, Cvoid, (Ptr{Cvoid}, Cint, Cint, Cint), window.handle, button, action, mods)
    end

    button = Cint(button)
    if action == GLFW.PRESS && button ≥ 0 && button < length(ctx.MouseJustPressed)
        ctx.MouseJustPressed[button+1] = true
    end

    return nothing
end

function ImGui_ImplGlfw_ScrollCallback(window::GLFW.Window, xoffset, yoffset)
    io::Ptr{ImGuiIO} = igGetIO()
    ctx = unsafe_pointer_to_objref(unsafe_load(io.UserData))
    if ctx.PrevUserCallbackScroll != C_NULL
        ccall(ctx.PrevUserCallbackScroll, Cvoid, (Ptr{Cvoid}, Cdouble, Cdouble), window.handle, xoffset, yoffset)
    end

    io.MouseWheelH = unsafe_load(io.MouseWheelH) + Cfloat(xoffset)
    io.MouseWheel = unsafe_load(io.MouseWheel) + Cfloat(yoffset)

    return nothing
end

function ImGui_ImplGlfw_KeyCallback(window::GLFW.Window, key, scancode, action, mods)
    io::Ptr{ImGuiIO} = igGetIO()
    ctx = unsafe_pointer_to_objref(unsafe_load(io.UserData))
    if ctx.PrevUserCallbackKey != C_NULL
        ccall(ctx.PrevUserCallbackKey, Cvoid, (Ptr{Cvoid}, Cint, Cint, Cint, Cint), window.handle, key, scancode, action, mods)
    end

    key = Cint(key)
    if key ≥ 0 && key < length(unsafe_load(io.KeysDown))
        if action == GLFW.PRESS
            c_set!(io.KeysDown, key, true)
            ctx.KeyOwnerWindows[key+1] = window
        end
        if action == GLFW.RELEASE
            c_set!(io.KeysDown, key, false)
            ctx.KeyOwnerWindows[key+1] = GLFW.Window(C_NULL)
        end
    end

    # modifiers are not reliable across systems
    io.KeyCtrl = c_get(io.KeysDown, GLFW.KEY_LEFT_CONTROL) || c_get(io.KeysDown, GLFW.KEY_RIGHT_CONTROL)
    io.KeyShift = c_get(io.KeysDown, GLFW.KEY_LEFT_SHIFT) || c_get(io.KeysDown, GLFW.KEY_RIGHT_SHIFT)
    io.KeyAlt = c_get(io.KeysDown, GLFW.KEY_LEFT_ALT) || c_get(io.KeysDown, GLFW.KEY_RIGHT_ALT)
    if Sys.iswindows()
        io.KeySuper = false
    else
        io.KeySuper = c_get(io.KeysDown, GLFW.KEY_LEFT_SUPER) || c_get(io.KeysDown, GLFW.KEY_RIGHT_SUPER)
    end

    return nothing
end

function ImGui_ImplGlfw_CharCallback(window::GLFW.Window, x)
    io::Ptr{ImGuiIO} = igGetIO()
    ctx = unsafe_pointer_to_objref(unsafe_load(io.UserData))
    if ctx.PrevUserCallbackChar != C_NULL
        ccall(ctx.PrevUserCallbackChar, Cvoid, (Ptr{Cvoid}, Cuint), window, x)
    end

    0 < Cuint(x) < 0x10000 && ImGuiIO_AddInputCharacter(io, x)

    return nothing
end

function ImGui_ImplGlfw_MonitorCallback(monitor::Ptr{Cvoid}, x::Cint)
    io::Ptr{ImGuiIO} = igGetIO()
    ctx = unsafe_pointer_to_objref(unsafe_load(io.UserData))
    ctx.WantUpdateMonitors = true
    return nothing
end

function ImGui_ImplGlfw_WindowCloseCallback(window::GLFW.Window)
    viewport::Ptr{ImGuiViewport} = igFindViewportByPlatformHandle(window.handle)
    if viewport != C_NULL
        viewport.PlatformRequestClose = true
    end
    return nothing
end

function ImGui_ImplGlfw_WindowPosCallback(window::GLFW.Window, x, y)
    viewport::Ptr{ImGuiViewport} = igFindViewportByPlatformHandle(window.handle)
    if viewport != C_NULL
        data::Ptr{ImGuiViewportDataGlfw} = unsafe_load(viewport.PlatformUserData)
        if data != C_NULL
            ignore_event = igGetFrameCount() ≤ (unsafe_load(data.IgnoreWindowPosEventFrame) + 1)
            ignore_event && return nothing
        end
        viewport.PlatformRequestMove = true
    end
    return nothing
end

function ImGui_ImplGlfw_WindowSizeCallback(window::GLFW.Window, x, y)
    viewport::Ptr{ImGuiViewport} = igFindViewportByPlatformHandle(window.handle)
    if viewport != C_NULL
        data::Ptr{ImGuiViewportDataGlfw} = unsafe_load(viewport.PlatformUserData)
        if data != C_NULL
            ignore_event = igGetFrameCount() ≤ (unsafe_load(data.IgnoreWindowSizeEventFrame) + 1)
            ignore_event && return nothing
        end
        viewport.PlatformRequestResize = true
    end
    return nothing
end
