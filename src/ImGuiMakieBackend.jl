module ImGuiMakieBackend

using GLMakie
using GLMakie.GLFW
using GLMakie.ModernGL
using LibCImGui
using Libdl

Base.convert(::Type{Cint}, x::GLFW.Key) = Cint(x)

const GLFW_GET_CLIPBOARD_TEXT_FUNCPTR = Ref{Ptr{Cvoid}}(C_NULL)
const GLFW_SET_CLIPBOARD_TEXT_FUNCPTR = Ref{Ptr{Cvoid}}(C_NULL)

include("utils.jl")

function c_get(x::Ptr{NTuple{N,T}}, i) where {N,T}
    unsafe_load(Ptr{T}(x), Integer(i)+1)
end

function c_set!(x::Ptr{NTuple{N,T}}, i, v) where {N,T}
    unsafe_store!(Ptr{T}(x), v, Integer(i)+1)
end

include("context.jl")
include("callbacks.jl")
include("font.jl")
include("device.jl")
include("platform.jl")
include("render.jl")
include("interface.jl")

const IMGUI_MAKIE_CONTEXT = Ref{Context}()

function __init__()
    GLFW_GET_CLIPBOARD_TEXT_FUNCPTR[] = dlsym(dlopen(GLFW.libglfw), :glfwGetClipboardString)
    GLFW_SET_CLIPBOARD_TEXT_FUNCPTR[] = dlsym(dlopen(GLFW.libglfw), :glfwSetClipboardString)

    if !isassigned(IMGUI_MAKIE_CONTEXT)
        IMGUI_MAKIE_CONTEXT[] = create_context()
    end
end

get_context() = IMGUI_MAKIE_CONTEXT[]

function vsynced_renderloop(screen)
    while GLMakie.isopen(screen) && !GLMakie.WINDOW_CONFIG.exit_renderloop[]
        GLMakie.pollevents(screen) # GLFW poll

        # create new cimgui frame
        new_frame(get_context())
        igNewFrame()

        screen.render_tick[] = nothing
        if GLMakie.WINDOW_CONFIG.pause_rendering[]
            sleep(0.1)
        else
            # UI
            get_context().ui_func()
            igShowDemoWindow(Ref(true))
            igShowMetricsWindow(Ref(true))
            @show "vsync"
            # render frame
            GLMakie.make_context_current(screen)
            GLMakie.render_frame(screen)

            # render UI frame
            igRender()
            GLMakie.make_context_current(screen)
            render(get_context())
            if unsafe_load(igGetIO().ConfigFlags) & ImGuiConfigFlags_ViewportsEnable == ImGuiConfigFlags_ViewportsEnable
                backup_current_context = GLFW.GetCurrentContext()
                igUpdatePlatformWindows()
                igRenderPlatformWindowsDefault(C_NULL, pointer_from_objref(ctx))
                GLFW.MakeContextCurrent(backup_current_context)
            end

            # swap buffer
            GLFW.SwapBuffers(GLMakie.to_native(screen))
            yield()
        end
    end
end

function fps_renderloop(screen::GLMakie.Screen, framerate=GLMakie.WINDOW_CONFIG.framerate[])
    time_per_frame = 1.0 / framerate
    while GLMakie.isopen(screen) && !WINDOW_CONFIG.exit_renderloop[]
        t = time_ns()
        GLMakie.pollevents(screen) # GLFW poll

        # create new cimgui frame
        new_frame(get_context())
        igNewFrame()

        screen.render_tick[] = nothing
        if WINDOW_CONFIG.pause_rendering[]
            sleep(0.1)
        else
            # UI
            get_context().ui_func()
            igShowDemoWindow(Ref(true))
            igShowMetricsWindow(Ref(true))
            @show "fps"
            # render frame
            GLMakie.make_context_current(screen)
            GLMakie.render_frame(screen)

            # render UI frame
            igRender()
            GLMakie.make_context_current(screen)
            render(get_context())
            if unsafe_load(igGetIO().ConfigFlags) & ImGuiConfigFlags_ViewportsEnable == ImGuiConfigFlags_ViewportsEnable
                backup_current_context = GLFW.GetCurrentContext()
                igUpdatePlatformWindows()
                igRenderPlatformWindowsDefault(C_NULL, pointer_from_objref(ctx))
                GLFW.MakeContextCurrent(backup_current_context)
            end

            # swap buffer
            GLFW.SwapBuffers(GLMakie.to_native(screen))
            t_elapsed = (time_ns() - t) / 1e9
            diff = time_per_frame - t_elapsed
            if diff > 0.001 # can't sleep less than 0.001
                sleep(diff)
            else # if we don't sleep, we still need to yield explicitely to other tasks
                yield()
            end
        end
    end
end

function renderloop(screen; framerate=WINDOW_CONFIG.framerate[])
    isopen(screen) || error("Screen most be open to run renderloop!")
    try
        if GLMakie.WINDOW_CONFIG.vsync[]
            GLFW.SwapInterval(1)
            vsynced_renderloop(screen)
        else
            GLFW.SwapInterval(0)
            fps_renderloop(screen, framerate)
        end
    catch e
        showerror(stderr, e, catch_backtrace())
        println(stderr)
        rethrow(e)
    finally
        shutdown(get_context())
        destroy!(screen)
    end
end

set_makie_renderloop() = GLMakie.set_window_config!(renderloop=renderloop)
export set_makie_renderloop

end
