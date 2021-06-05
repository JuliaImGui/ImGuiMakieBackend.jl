function ImGui_ImplOpenGL3_CreateFontsTexture(ctx::Context)
    # build texture atlas
    fonts = unsafe_load(igGetIO().Fonts)
    pixels = Ptr{Cuchar}(C_NULL)
    width, height = Cint(0), Cint(0)
    @c ImFontAtlas_GetTexDataAsRGBA32(fonts, &pixels, &width, &height, C_NULL)

    # upload texture to graphics system
    last_texture = GLint(0)
    @c glGetIntegerv(GL_TEXTURE_BINDING_2D, &last_texture)
    ctx.FontTexture = GLuint(0)
    @c glGenTextures(1, &ctx.FontTexture)
    glBindTexture(GL_TEXTURE_2D, ctx.FontTexture)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0)
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels)

    # store our identifier
    ImFontAtlas_SetTexID(fonts, ImTextureID(Int(ctx.FontTexture)))

    # restore state
    glBindTexture(GL_TEXTURE_2D, last_texture)

    return true
end

function ImGui_ImplOpenGL3_DestroyFontsTexture(ctx::Context)
    io::Ptr{ImGuiIO} = igGetIO()
    @c glDeleteTextures(1, &ctx.FontTexture)
    ImFontAtlas_SetTexID(unsafe_load(io.Fonts), ImTextureID(0))
    ctx.FontTexture = 0
    return true
end
