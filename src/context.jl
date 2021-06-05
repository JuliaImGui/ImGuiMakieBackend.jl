"""
    mutable struct Context
A contextual data object.
"""
Base.@kwdef mutable struct Context
    id::Int=new_id()
    Window::GLFW.Window = GLFW.Window(C_NULL)
    Time::Cfloat = Cfloat(0.0f0)
    MouseJustPressed::Vector{Bool} = fill(false, Int(ImGuiMouseButton_COUNT))
    MouseCursors::Vector{GLFW.Cursor} = fill(GLFW.Cursor(C_NULL), Int(ImGuiMouseCursor_COUNT))
    KeyOwnerWindows::Vector{GLFW.Window} = fill(GLFW.Window(C_NULL), 512)
    InstalledCallbacks::Bool = true
    WantUpdateMonitors::Bool = true
    PrevUserCallbackMousebutton::Ptr{Cvoid} = C_NULL
    PrevUserCallbackScroll::Ptr{Cvoid} = C_NULL
    PrevUserCallbackKey::Ptr{Cvoid} = C_NULL
    PrevUserCallbackChar::Ptr{Cvoid} = C_NULL
    PrevUserCallbackMonitor::Ptr{Cvoid} = C_NULL
    GlslVersion = 150
    FontTexture = GLuint(0)
    ShaderHandle = GLuint(0)
    VertHandle = GLuint(0)
    FragHandle = GLuint(0)
    AttribLocationTex = GLint(0)
    AttribLocationProjMtx = GLint(0)
    AttribLocationVtxPos = GLint(0)
    AttribLocationVtxUV = GLint(0)
    AttribLocationVtxColor = GLint(0)
    VboHandle = GLuint(0)
    ElementsHandle = GLuint(0)
    ui_handle = igCreateContext(C_NULL)
    ui_func = ()->nothing
end

Base.show(io::IO, x::Context) = print(io, "Context(id=$(x.id))")

const __IMGUI_CONTEXTS = Dict{Int,Context}()
const __IMGUI_CONTEXT_COUNTER = Threads.Atomic{Int}(0)

reset_counter() = Threads.atomic_sub!(__IMGUI_CONTEXT_COUNTER,  __IMGUI_CONTEXT_COUNTER[])
add_counter() = Threads.atomic_add!(__IMGUI_CONTEXT_COUNTER, 1)
get_counter() = __IMGUI_CONTEXT_COUNTER[]
new_id() = (add_counter(); get_counter();)

"""
    create_context()
Return a GLFW backend contextual data object.
"""
function create_context()
    screen = GLMakie.global_gl_screen()
    window = GLMakie.to_native(screen)

    ctx = Context(; Window=window)

    config_imgui()

    # store the ctx in a global variable to prevent it from being GC-ed
    __IMGUI_CONTEXTS[ctx.id] = ctx

    init(ctx)

    return ctx
end

function config_imgui()
    # enable docking and multi-viewport
    io = igGetIO()
    io.ConfigFlags = unsafe_load(io.ConfigFlags) | ImGuiConfigFlags_DockingEnable
    io.ConfigFlags = unsafe_load(io.ConfigFlags) | ImGuiConfigFlags_ViewportsEnable

    # set style
    igStyleColorsDark(C_NULL)

    # When viewports are enabled we tweak WindowRounding/WindowBg so platform windows can look identical to regular ones.
    style = Ptr{ImGuiStyle}(igGetStyle())
    if unsafe_load(io.ConfigFlags) & ImGuiConfigFlags_ViewportsEnable == ImGuiConfigFlags_ViewportsEnable
        style.WindowRounding = 5.0f0
        col = c_get(style.Colors, ImGuiCol_WindowBg)
        c_set!(style.Colors, ImGuiCol_WindowBg, ImVec4(col.x, col.y, col.z, 1.0f0))
    end
end


"""
    release_context(ctx::Context)
Relese the ctx so it can be GC-ed.
"""
release_context(ctx::Context) = delete!(__IMGUI_CONTEXTS, ctx.id)

get_window(ctx::Context) = ctx.Window
