#----------------------------------------
# OpenGL    GLSL      GLSL
# version   version   string
#----------------------------------------
#  2.0       110       "#version 110"
#  2.1       120
#  3.0       130
#  3.1       140
#  3.2       150       "#version 150"
#  3.3       330
#  4.0       400
#  4.1       410       "#version 410 core"
#  4.2       420
#  4.3       430
#  ES 2.0    100       "#version 100"
#  ES 3.0    300       "#version 300 es"
#----------------------------------------

const IMGUI_BACKEND_RENDERER_NAME = "imgui_impl_opengl3"
const GLFW_BACKEND_PLATFORM_NAME = "julia_imgui_glfw"

"""
    init(ctx::Context)
Initialize GLFW backend. Do initialize a IMGUI context before calling this function.
"""
function init(ctx::Context)
    ctx.Time = 0.0

    # setup back-end capabilities flags
    io::Ptr{ImGuiIO} = igGetIO()
    io.BackendFlags = unsafe_load(io.BackendFlags) | ImGuiBackendFlags_HasMouseCursors
    io.BackendFlags = unsafe_load(io.BackendFlags) | ImGuiBackendFlags_HasSetMousePos
    io.BackendFlags = unsafe_load(io.BackendFlags) | ImGuiBackendFlags_PlatformHasViewports
    # TODO: pending glfw 3.4
    # io.BackendFlags = unsafe_load(io.BackendFlags) | ImGuiBackendFlags_HasMouseHoveredViewport
    io.BackendPlatformName = pointer(GLFW_BACKEND_PLATFORM_NAME)

    io.BackendRendererName = pointer(IMGUI_BACKEND_RENDERER_NAME)
    io.BackendFlags = unsafe_load(io.BackendFlags) | ImGuiBackendFlags_RendererHasVtxOffset  # version ≥ 320
    io.BackendFlags = unsafe_load(io.BackendFlags) | ImGuiBackendFlags_RendererHasViewports

    # store the contextual object reference to IMGUI
    io.UserData = pointer_from_objref(ctx)

    # keyboard mapping
    c_set!(io.KeyMap, ImGuiKey_Tab, GLFW.KEY_TAB)
    c_set!(io.KeyMap, ImGuiKey_LeftArrow, GLFW.KEY_LEFT)
    c_set!(io.KeyMap, ImGuiKey_RightArrow, GLFW.KEY_RIGHT)
    c_set!(io.KeyMap, ImGuiKey_UpArrow, GLFW.KEY_UP)
    c_set!(io.KeyMap, ImGuiKey_DownArrow, GLFW.KEY_DOWN)
    c_set!(io.KeyMap, ImGuiKey_PageUp, GLFW.KEY_PAGE_UP)
    c_set!(io.KeyMap, ImGuiKey_PageDown, GLFW.KEY_PAGE_DOWN)
    c_set!(io.KeyMap, ImGuiKey_Home, GLFW.KEY_HOME)
    c_set!(io.KeyMap, ImGuiKey_End, GLFW.KEY_END)
    c_set!(io.KeyMap, ImGuiKey_Insert, GLFW.KEY_INSERT)
    c_set!(io.KeyMap, ImGuiKey_Delete, GLFW.KEY_DELETE)
    c_set!(io.KeyMap, ImGuiKey_Backspace, GLFW.KEY_BACKSPACE)
    c_set!(io.KeyMap, ImGuiKey_Space, GLFW.KEY_SPACE)
    c_set!(io.KeyMap, ImGuiKey_Enter, GLFW.KEY_ENTER)
    c_set!(io.KeyMap, ImGuiKey_Escape, GLFW.KEY_ESCAPE)
    c_set!(io.KeyMap, ImGuiKey_KeyPadEnter, GLFW.KEY_KP_ENTER)
    c_set!(io.KeyMap, ImGuiKey_A, GLFW.KEY_A)
    c_set!(io.KeyMap, ImGuiKey_C, GLFW.KEY_C)
    c_set!(io.KeyMap, ImGuiKey_V, GLFW.KEY_V)
    c_set!(io.KeyMap, ImGuiKey_X, GLFW.KEY_X)
    c_set!(io.KeyMap, ImGuiKey_Y, GLFW.KEY_Y)
    c_set!(io.KeyMap, ImGuiKey_Z, GLFW.KEY_Z)

    # set clipboard
    io.GetClipboardTextFn = GLFW_GET_CLIPBOARD_TEXT_FUNCPTR[]
    io.SetClipboardTextFn = GLFW_SET_CLIPBOARD_TEXT_FUNCPTR[]
    io.ClipboardUserData = Ptr{Cvoid}(ctx.Window.handle)

    # create mouse cursors
    ctx.MouseCursors[ImGuiMouseCursor_Arrow+1] = GLFW.CreateStandardCursor(GLFW.ARROW_CURSOR)
    ctx.MouseCursors[ImGuiMouseCursor_TextInput+1] = GLFW.CreateStandardCursor(GLFW.IBEAM_CURSOR)
    ctx.MouseCursors[ImGuiMouseCursor_ResizeNS+1] = GLFW.CreateStandardCursor(GLFW.VRESIZE_CURSOR)
    ctx.MouseCursors[ImGuiMouseCursor_ResizeEW+1] = GLFW.CreateStandardCursor(GLFW.HRESIZE_CURSOR)
    ctx.MouseCursors[ImGuiMouseCursor_Hand+1] = GLFW.CreateStandardCursor(GLFW.HAND_CURSOR)

    # prepare for GLFW 3.4+
    # ctx.MouseCursors[ImGuiMouseCursor_ResizeAll+1] = glfwCreateStandardCursor(GLFW_RESIZE_ALL_CURSOR)
    # ctx.MouseCursors[ImGuiMouseCursor_ResizeNESW+1] = glfwCreateStandardCursor(GLFW_RESIZE_NESW_CURSOR)
    # ctx.MouseCursors[ImGuiMouseCursor_ResizeNWSE+1] = glfwCreateStandardCursor(GLFW_RESIZE_NWSE_CURSOR)
    # ctx.MouseCursors[ImGuiMouseCursor_NotAllowed+1] = glfwCreateStandardCursor(GLFW_NOT_ALLOWED_CURSOR)
    ctx.MouseCursors[ImGuiMouseCursor_ResizeAll+1] = GLFW.CreateStandardCursor(GLFW.ARROW_CURSOR)
    ctx.MouseCursors[ImGuiMouseCursor_ResizeNESW+1] = GLFW.CreateStandardCursor(GLFW.ARROW_CURSOR)
    ctx.MouseCursors[ImGuiMouseCursor_ResizeNWSE+1] = GLFW.CreateStandardCursor(GLFW.ARROW_CURSOR)
    ctx.MouseCursors[ImGuiMouseCursor_NotAllowed+1] = GLFW.CreateStandardCursor(GLFW.ARROW_CURSOR)

    # chain GLFW callbacks
    ctx.PrevUserCallbackMousebutton = C_NULL
    ctx.PrevUserCallbackScroll = C_NULL
    ctx.PrevUserCallbackKey = C_NULL
    ctx.PrevUserCallbackChar = C_NULL
    ctx.PrevUserCallbackMonitor = C_NULL
    if ctx.InstalledCallbacks
        ctx.PrevUserCallbackMousebutton = glfwSetMouseButtonCallback(ctx.Window, @cfunction(ImGui_ImplGlfw_MouseButtonCallback, Cvoid, (GLFW.Window, GLFW.MouseButton, GLFW.Action, Cint)))
        ctx.PrevUserCallbackScroll = glfwSetScrollCallback(ctx.Window, @cfunction(ImGui_ImplGlfw_ScrollCallback, Cvoid, (GLFW.Window, Cdouble, Cdouble)))
        ctx.PrevUserCallbackKey = glfwSetKeyCallback(ctx.Window, @cfunction(ImGui_ImplGlfw_KeyCallback, Cvoid, (GLFW.Window, GLFW.Key, Cint, GLFW.Action, Cint)))
        ctx.PrevUserCallbackChar = glfwSetCharCallback(ctx.Window, @cfunction(ImGui_ImplGlfw_CharCallback, Cvoid, (GLFW.Window, Cuint)))
        ctx.PrevUserCallbackMonitor = glfwSetMonitorCallback(@cfunction(ImGui_ImplGlfw_MonitorCallback, Cvoid, (Ptr{Cvoid}, Cint)))
    end

    # update monitors the first time
    ImGui_ImplGlfw_UpdateMonitors(ctx)
    glfwSetMonitorCallback(@cfunction(ImGui_ImplGlfw_MonitorCallback, Cvoid, (Ptr{Cvoid}, Cint)))

    # the mouse update function expect PlatformHandle to be filled for the main viewport
    main_viewport::Ptr{ImGuiViewport} = igGetMainViewport()
    main_viewport.PlatformHandle = Ptr{Cvoid}(ctx.Window.handle)
    if Sys.iswindows()
        main_viewport.PlatformHandleRaw = ccall((:glfwGetWin32Window, GLFW.libglfw), Ptr{Cvoid}, (GLFW.Window,), ctx.Window)
    end

    if unsafe_load(io.ConfigFlags) & ImGuiConfigFlags_ViewportsEnable == ImGuiConfigFlags_ViewportsEnable
        ImGui_ImplGlfw_InitPlatformInterface(ctx)
        ImGui_ImplOpenGL3_InitPlatformInterface()
    end

    return true
end

"""
    shutdown((ctx::Context)
Clean up resources.
"""
function shutdown(ctx::Context)
    ImGui_ImplOpenGL3_ShutdownPlatformInterface()
    ImGui_ImplOpenGL3_DestroyDeviceObjects(ctx)

    ImGui_ImplGlfw_ShutdownPlatformInterface(ctx)

    if ctx.InstalledCallbacks
        ccall((:glfwSetMouseButtonCallback, libglfw), Ptr{Cvoid}, (GLFW.Window, Ptr{Cvoid}), ctx.Window, ctx.PrevUserCallbackMousebutton)
        ccall((:glfwSetScrollCallback, libglfw), Ptr{Cvoid}, (GLFW.Window, Ptr{Cvoid}), ctx.Window, ctx.PrevUserCallbackScroll)
        ccall((:glfwSetKeyCallback, libglfw), Ptr{Cvoid}, (GLFW.Window, Ptr{Cvoid}), ctx.Window, ctx.PrevUserCallbackKey)
        ccall((:glfwSetCharCallback, libglfw), Ptr{Cvoid}, (GLFW.Window, Ptr{Cvoid}), ctx.Window, ctx.PrevUserCallbackChar)
        ctx.InstalledCallbacks = false
    end

    for i = 1:length(ctx.MouseCursors)
        GLFW.DestroyCursor(ctx.MouseCursors[i])
        ctx.MouseCursors[i] = C_NULL
    end

    return true
end

function ImGui_ImplGlfw_UpdateMousePosAndButtons(ctx::Context)
    # update buttons
    io::Ptr{ImGuiIO} = igGetIO()
    for n = 0:length(ctx.MouseJustPressed)-1
        # if a mouse press event came, always pass it as "mouse held this frame",
        # so we don't miss click-release events that are shorter than 1 frame.
        is_down = ctx.MouseJustPressed[n+1] || GLFW.GetMouseButton(ctx.Window, n)
        c_set!(io.MouseDown, n, is_down)
        ctx.MouseJustPressed[n+1] = false
    end

    # update mouse position
    mouse_pos_backup = unsafe_load(io.MousePos)
    FLT_MAX = igGET_FLT_MAX()
    io.MousePos = ImVec2(-FLT_MAX, -FLT_MAX)
    io.MouseHoveredViewport = 0
    platform_io::Ptr{ImGuiPlatformIO} = igGetPlatformIO()
    vp = unsafe_load(platform_io.Viewports)
    viewport_ptrs = unsafe_wrap(Vector{Ptr{ImGuiViewport}}, vp.Data, vp.Size)
    for viewport in viewport_ptrs
        window = GLFW.Window(unsafe_load(viewport.PlatformHandle))
        @assert window != C_NULL

        if GLFW.GetWindowAttrib(window, GLFW.FOCUSED) != 0
            if unsafe_load(io.WantSetMousePos)
                x = mouse_pos_backup.x - unsafe_load(viewport.Pos.x)
                y = mouse_pos_backup.y - unsafe_load(viewport.Pos.y)
                GLFW.SetCursorPos(window, Cdouble(x), Cdouble(y))
            else
                mouse_x, mouse_y = GLFW.GetCursorPos(GLFW.Window(window))
                if unsafe_load(io.ConfigFlags) & ImGuiConfigFlags_ViewportsEnable == ImGuiConfigFlags_ViewportsEnable
                    # Multi-viewport mode: mouse position in OS absolute coordinates (io.MousePos is (0,0) when the mouse is on the upper-left of the primary monitor)
                    window_x, window_y = GLFW.GetWindowPos(GLFW.Window(window))
                    io.MousePos = ImVec2(Cfloat(mouse_x + window_x), Cfloat(mouse_y + window_y))
                else
                    # Single viewport mode: mouse position in client window coordinates (io.MousePos is (0,0) when the mouse is on the upper-left corner of the app window)
                    io.MousePos = ImVec2(Cfloat(mouse_x), Cfloat(mouse_y))
                end
            end

        end
        for n = 0:length(ctx.MouseJustPressed)-1
            c_set!(io.MouseDown, n, c_get(io.MouseDown, n) || GLFW.GetMouseButton(window, n))
        end
    end
    # TODO: pending glfw 3.4 GLFW_HAS_MOUSE_PASSTHROUGH
    # TODO: _WIN32
end

function ImGui_ImplGlfw_UpdateMouseCursor(ctx::Context)
    io::Ptr{ImGuiIO} = igGetIO()
    if (unsafe_load(io.ConfigFlags) & ImGuiConfigFlags_NoMouseCursorChange == ImGuiConfigFlags_NoMouseCursorChange) ||
        GLFW.GetInputMode(ctx.Window, GLFW.CURSOR) == GLFW.CURSOR_DISABLED
        return nothing
    end

    imgui_cursor = igGetMouseCursor()
    platform_io::Ptr{ImGuiPlatformIO} = igGetPlatformIO()
    vp = unsafe_load(platform_io.Viewports)
    viewport_ptrs = unsafe_wrap(Vector{Ptr{ImGuiViewport}}, vp.Data, vp.Size)
    for viewport in viewport_ptrs
        window = unsafe_load(viewport.PlatformHandle)
        @assert window != C_NULL
        if imgui_cursor == ImGuiMouseCursor_None || unsafe_load(io.MouseDrawCursor)
            # hide OS mouse cursor if imgui is drawing it or if it wants no cursor
            GLFW.SetInputMode(window, GLFW.CURSOR, GLFW.CURSOR_HIDDEN)
        else
            # show OS mouse cursor
            cursor = ctx.MouseCursors[imgui_cursor+1]
            GLFW.SetCursor(window, cursor != C_NULL ? ctx.MouseCursors[imgui_cursor+1] : ctx.MouseCursors[ImGuiMouseCursor_Arrow+1])
            GLFW.SetInputMode(window, GLFW.CURSOR, GLFW.CURSOR_NORMAL)
        end
    end

    return nothing
end

function ImGui_ImplGlfw_UpdateMonitors(ctx::Context)
    platform_io::Ptr{ImGuiPlatformIO} = igGetPlatformIO()
    monitors_count = Cint(0)
	ptr = @c glfwGetMonitors(&monitors_count)
	glfw_monitors = unsafe_wrap(Array, ptr, monitors_count)
    monitors_ptr::Ptr{ImGuiPlatformMonitor} = Libc.malloc(monitors_count * sizeof(ImGuiPlatformMonitor))
    for i = 1:monitors_count
        glfw_monitor = glfw_monitors[i]
        mptr::Ptr{ImGuiPlatformMonitor} = monitors_ptr + (i-1) * sizeof(ImGuiPlatformMonitor)

        x, y = Cint(0), Cint(0)
        @c glfwGetMonitorPos(glfw_monitor, &x, &y)
        vid_mode = unsafe_load(glfwGetVideoMode(glfw_monitor))
        mptr.MainPos = ImVec2(x, y)
        mptr.MainSize = ImVec2(vid_mode.width, vid_mode.height)
        mptr.WorkPos = ImVec2(x, y)
        mptr.WorkSize = ImVec2(vid_mode.width, vid_mode.height)

        w, h = Cint(0), Cint(0)
        @c glfwGetMonitorWorkarea(glfw_monitors[i], &x, &y, &w, &h)
        if w > 0 && h > 0
            mptr.WorkPos = ImVec2(Cfloat(x), Cfloat(y))
            mptr.WorkSize = ImVec2(Cfloat(w), Cfloat(h))
        end

        x_scale, y_scale = Cfloat(0), Cfloat(0)
        @c glfwGetMonitorContentScale(glfw_monitor, &x_scale, &y_scale)
        mptr.DpiScale = x_scale
    end

    platform_io.Monitors = ImVector_ImGuiPlatformMonitor(monitors_count, monitors_count, monitors_ptr)
    ctx.WantUpdateMonitors = false

    return nothing
end

function new_frame(ctx::Context)
    if ctx.ShaderHandle != C_NULL
        ImGui_ImplOpenGL3_CreateDeviceObjects(ctx)
    end

    io::Ptr{ImGuiIO} = igGetIO()
    @assert ImFontAtlas_IsBuilt(unsafe_load(io.Fonts)) "Font atlas not built! It is generally built by the renderer back-end. Missing call to renderer _NewFrame() function? e.g. ImGui_ImplOpenGL3_NewFrame()."

    # setup display size (every frame to accommodate for window resizing)
    w, h = Cint(0), Cint(0)
    display_w, display_h = Cint(0), Cint(0)
    @c glfwGetWindowSize(ctx.Window, &w, &h)
    @c glfwGetFramebufferSize(ctx.Window, &display_w, &display_h)
    io.DisplaySize = ImVec2(Cfloat(w), Cfloat(h))
    if w > 0 && h > 0
        w_scale = Cfloat(display_w / w)
        h_scale = Cfloat(display_h / h)
        io.DisplayFramebufferScale = ImVec2(w_scale, h_scale)
    end

    ctx.WantUpdateMonitors && ImGui_ImplGlfw_UpdateMonitors(ctx)

    # setup time step
    current_time = glfwGetTime()
    io.DeltaTime = ctx.Time > 0.0 ? Cfloat(current_time - ctx.Time) : Cfloat(1.0/60.0)
    ctx.Time = current_time

    ImGui_ImplGlfw_UpdateMousePosAndButtons(ctx)
    ImGui_ImplGlfw_UpdateMouseCursor(ctx)

    # TODO: Gamepad navigation mapping
    # ImGui_ImplGlfw_UpdateGamepads()
end

render(ctx::Context) = ImGui_ImplOpenGL3_RenderDrawData(ctx, igGetDrawData())
