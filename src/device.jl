function ImGui_ImplOpenGL3_CreateDeviceObjects(ctx::Context)
    vertex_shader_glsl_130 = """
        #version $(ctx.GlslVersion[])
        uniform mat4 ProjMtx;
        in vec2 Position;
        in vec2 UV;
        in vec4 Color;
        out vec2 Frag_UV;
        out vec4 Frag_Color;
        void main()
        {
            Frag_UV = UV;
            Frag_Color = Color;
            gl_Position = ProjMtx * vec4(Position.xy,0,1);
        }"""

    vertex_shader_glsl_410_core = """
        #version $(ctx.GlslVersion[])
        layout (location = 0) in vec2 Position;
        layout (location = 1) in vec2 UV;
        layout (location = 2) in vec4 Color;
        uniform mat4 ProjMtx;
        out vec2 Frag_UV;
        out vec4 Frag_Color;
        void main()
        {
            Frag_UV = UV;
            Frag_Color = Color;
            gl_Position = ProjMtx * vec4(Position.xy,0,1);
        }"""

    fragment_shader_glsl_130 = """
        #version $(ctx.GlslVersion[])
        uniform sampler2D Texture;
        in vec2 Frag_UV;
        in vec4 Frag_Color;
        out vec4 Out_Color;
        void main()
        {
            Out_Color = Frag_Color * texture(Texture, Frag_UV.st);
        }"""

    fragment_shader_glsl_410_core = """
        #version $(ctx.GlslVersion[])
        in vec2 Frag_UV;
        in vec4 Frag_Color;
        uniform sampler2D Texture;
        layout (location = 0) out vec4 Out_Color;
        void main()
        {
            Out_Color = Frag_Color * texture(Texture, Frag_UV.st);
        }"""

    if ctx.GlslVersion == 410
        vertex_shader = vertex_shader_glsl_410_core
        fragment_shader = fragment_shader_glsl_410_core
    else
        vertex_shader = vertex_shader_glsl_130
        fragment_shader = fragment_shader_glsl_130
    end

    # backup GL state
    last_texture, last_array_buffer, last_vertex_array_object = GLint(0), GLint(0), GLint(0)
    @c glGetIntegerv(GL_TEXTURE_BINDING_2D, &last_texture)
    @c glGetIntegerv(GL_ARRAY_BUFFER_BINDING, &last_array_buffer)
    @c glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &last_vertex_array_object)

    ctx.VertHandle = glCreateShader(GL_VERTEX_SHADER)
    glShaderSource(ctx.VertHandle, 1, Ptr{GLchar}[pointer(vertex_shader)], C_NULL)
    glCompileShader(ctx.VertHandle)
    status = GLint(-1)
    @c glGetShaderiv(ctx.VertHandle, GL_COMPILE_STATUS, &status)
    if status != GL_TRUE
        max_length = GLsizei(0)
        @c glGetShaderiv(ctx.VertHandle, GL_INFO_LOG_LENGTH, &max_length)
        actual_length = GLsizei(0)
        log = Vector{GLchar}(undef, max_length)
        @c glGetShaderInfoLog(ctx.VertHandle, max_length, &actual_length, log)
        @error "[GL]: failed to compile vertex shader: $(ctx.VertHandle): $(String(log))"
    end

    ctx.FragHandle = glCreateShader(GL_FRAGMENT_SHADER)
    glShaderSource(ctx.FragHandle, 1, Ptr{GLchar}[pointer(fragment_shader)], C_NULL)
    glCompileShader(ctx.FragHandle)
    status = GLint(-1)
    @c glGetShaderiv(ctx.FragHandle, GL_COMPILE_STATUS, &status)
    if status != GL_TRUE
        max_length = GLsizei(0)
        @c glGetShaderiv(ctx.FragHandle, GL_INFO_LOG_LENGTH, &max_length)
        actual_length = GLsizei(0)
        log = Vector{GLchar}(undef, max_length)
        @c glGetShaderInfoLog(ctx.FragHandle, max_length, &actual_length, log)
        @error "[GL]: failed to compile fragment shader: $(ctx.FragHandle): $(String(log))"
    end

    ctx.ShaderHandle = glCreateProgram()
    glAttachShader(ctx.ShaderHandle, ctx.VertHandle)
    glAttachShader(ctx.ShaderHandle, ctx.FragHandle)
    glLinkProgram(ctx.ShaderHandle)
    status = GLint(-1)
    @c glGetProgramiv(ctx.ShaderHandle, GL_LINK_STATUS, &status)
    @assert status == GL_TRUE

    ctx.AttribLocationTex = glGetUniformLocation(ctx.ShaderHandle, "Texture")
    ctx.AttribLocationProjMtx = glGetUniformLocation(ctx.ShaderHandle, "ProjMtx")
    ctx.AttribLocationVtxPos = glGetAttribLocation(ctx.ShaderHandle, "Position")
    ctx.AttribLocationVtxUV = glGetAttribLocation(ctx.ShaderHandle, "UV")
    ctx.AttribLocationVtxColor = glGetAttribLocation(ctx.ShaderHandle, "Color")

    # create buffers
    @c glGenBuffers(1, &ctx.VboHandle)
    @c glGenBuffers(1, &ctx.ElementsHandle)

    ImGui_ImplOpenGL3_CreateFontsTexture(ctx)

    # restore modified GL state
    glBindTexture(GL_TEXTURE_2D, last_texture)
    glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer)
    glBindVertexArray(last_vertex_array_object)

    return true;
end

function ImGui_ImplOpenGL3_DestroyDeviceObjects(ctx::Context)
    if ctx.VboHandle != 0
        @c glDeleteBuffers(1, &ctx.VboHandle)
        ctx.VboHandle = 0
    end

    if ctx.ElementsHandle != 0
        @c glDeleteBuffers(1, &ctx.ElementsHandle)
        ctx.ElementsHandle = 0
    end

    if ctx.ShaderHandle != 0 && ctx.VertHandle != 0
        glDetachShader(ctx.ShaderHandle, ctx.VertHandle)
    end

    if ctx.ShaderHandle != 0 && ctx.FragHandle != 0
        glDetachShader(ctx.ShaderHandle, ctx.FragHandle)
    end

    if ctx.VertHandle[] != 0
        glDeleteShader(ctx.VertHandle)
        ctx.VertHandle = 0
    end

    if ctx.FragHandle[] != 0
        glDeleteShader(ctx.FragHandle)
        ctx.FragHandle = 0
    end

    if ctx.ShaderHandle != 0
        glDeleteProgram(ctx.ShaderHandle)
        ctx.ShaderHandle = 0
    end

    ImGui_ImplOpenGL3_DestroyFontsTexture(ctx)

    return true
end
