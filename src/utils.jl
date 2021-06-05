macro c(ex)
    Meta.isexpr(ex, :call) || throw(ArgumentError("not a function call expression."))
    prologue = Expr(:block)
    epilogue = Expr(:block)
    func_expr = Expr(:call, first(ex.args))
    for arg in ex.args[2:end]
        if Meta.isexpr(arg, :&)
            refee = arg.args[]
            if Meta.isexpr(refee, :ref) && length(refee.args) == 2
                # &a[n] => pointer(a) + n * Core.sizeof(eltype(a))
                array_name, n = refee.args
                push!(func_expr.args, :(pointer($array_name) + $n * Core.sizeof(eltype($array_name))))
            else
                ref_sym = gensym("cref")
                push!(prologue.args, Expr(:(=), ref_sym, Expr(:call, :Ref, refee)))
                push!(func_expr.args, ref_sym)
                push!(epilogue.args, Expr(:(=), refee, Expr(:ref, ref_sym)))
            end
        else
            push!(func_expr.args, arg)
        end
    end
    func_ret = gensym("cref_ret")
    push!(prologue.args, Expr(:(=), func_ret, func_expr))
    append!(prologue.args, epilogue.args)
    push!(prologue.args, func_ret)
    return esc(prologue)
end

function glfwGetMonitors(count)
    ccall((:glfwGetMonitors, GLFW.libglfw), Ptr{Ptr{Cvoid}}, (Ptr{Cint},), count)
end

function glfwGetMonitorPos(monitor, xpos, ypos)
    ccall((:glfwGetMonitorPos, GLFW.libglfw), Cvoid, (Ptr{Cvoid}, Ptr{Cint}, Ptr{Cint}), monitor, xpos, ypos)
end

struct GLFWvidmode
    width::Cint
    height::Cint
    redBits::Cint
    greenBits::Cint
    blueBits::Cint
    refreshRate::Cint
end

function glfwGetVideoMode(monitor)
    ccall((:glfwGetVideoMode, GLFW.libglfw), Ptr{GLFWvidmode}, (Ptr{Cvoid},), monitor)
end

function glfwGetMonitorWorkarea(monitor, xpos, ypos, width, height)
    ccall((:glfwGetMonitorWorkarea, GLFW.libglfw), Cvoid, (Ptr{Cvoid}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), monitor, xpos, ypos, width, height)
end

function glfwGetMonitorContentScale(monitor, xscale, yscale)
    ccall((:glfwGetMonitorContentScale, GLFW.libglfw), Cvoid, (Ptr{Cvoid}, Ptr{Cfloat}, Ptr{Cfloat}), monitor, xscale, yscale)
end

function glfwGetWindowSize(window, width, height)
    ccall((:glfwGetWindowSize, GLFW.libglfw), Cvoid, (GLFW.Window, Ptr{Cint}, Ptr{Cint}), window, width, height)
end

function glfwGetFramebufferSize(window, width, height)
    ccall((:glfwGetFramebufferSize, GLFW.libglfw), Cvoid, (GLFW.Window, Ptr{Cint}, Ptr{Cint}), window, width, height)
end

function glfwGetTime()
    ccall((:glfwGetTime, GLFW.libglfw), Cdouble, ())
end

function glfwSetWindowTitle(window, title)
    ccall((:glfwSetWindowTitle, GLFW.libglfw), Cvoid, (GLFW.Window, Ptr{Cchar}), window, title)
end

function glfwSetMouseButtonCallback(window, callback)
    ccall((:glfwSetMouseButtonCallback, GLFW.libglfw), Ptr{Cvoid}, (GLFW.Window, Ptr{Cvoid}), window, callback)
end

function glfwSetScrollCallback(window, callback)
    ccall((:glfwSetScrollCallback, GLFW.libglfw), Ptr{Cvoid}, (GLFW.Window, Ptr{Cvoid}), window, callback)
end

function glfwSetKeyCallback(window, callback)
    ccall((:glfwSetKeyCallback, GLFW.libglfw), Ptr{Cvoid}, (GLFW.Window, Ptr{Cvoid}), window, callback)
end

function glfwSetCharCallback(window, callback)
    ccall((:glfwSetCharCallback, GLFW.libglfw), Ptr{Cvoid}, (GLFW.Window, Ptr{Cvoid}), window, callback)
end

function glfwSetMonitorCallback(callback)
    ccall((:glfwSetMonitorCallback, GLFW.libglfw), Ptr{Cvoid}, (Ptr{Cvoid},), callback)
end
