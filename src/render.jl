function ImGui_ImplOpenGL3_SetupRenderState(ctx::Context, draw_data, fb_width::Cint, fb_height::Cint, vertex_array_object::GLuint)
    # setup render state:
    # - alpha-blending enabled
    # - no face culling
    # - no depth testing
    # - scissor enabled
    # - polygon fill
    glEnable(GL_BLEND)
    glBlendEquation(GL_FUNC_ADD)
    glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
    glDisable(GL_CULL_FACE)
    glDisable(GL_DEPTH_TEST)
    glDisable(GL_STENCIL_TEST)
    glEnable(GL_SCISSOR_TEST)

    ctx.GlslVersion > 310 && glDisable(GL_PRIMITIVE_RESTART)

    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)

    # FIXME: support for glClipControl

    # setup viewport, orthographic projection matrix
    glViewport(0, 0, GLsizei(fb_width), GLsizei(fb_height))
    disp_pos = unsafe_load(draw_data.DisplayPos)
    disp_size = unsafe_load(draw_data.DisplaySize)
    L = disp_pos.x
    R = disp_pos.x + disp_size.x
    T = disp_pos.y
    B = disp_pos.y + disp_size.y
    ortho_projection = GLfloat[2.0/(R-L), 0.0, 0.0, 0.0,
                               0.0, 2.0/(T-B), 0.0, 0.0,
                               0.0, 0.0, -1.0, 0.0,
                               (R+L)/(L-R), (T+B)/(B-T), 0.0, 1.0]

    glUseProgram(ctx.ShaderHandle)
    glUniform1i(ctx.AttribLocationTex, 0)
    glUniformMatrix4fv(ctx.AttribLocationProjMtx, 1, GL_FALSE, ortho_projection)
    ctx.GlslVersion > 330 && glBindSampler(0, 0)

    glBindVertexArray(vertex_array_object)
    glBindBuffer(GL_ARRAY_BUFFER, ctx.VboHandle)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ctx.ElementsHandle)
    glEnableVertexAttribArray(ctx.AttribLocationVtxPos)
    glEnableVertexAttribArray(ctx.AttribLocationVtxUV)
    glEnableVertexAttribArray(ctx.AttribLocationVtxColor)
    pos_offset = fieldoffset(ImDrawVert, 1)
    uv_offset = fieldoffset(ImDrawVert, 2)
    col_offset = fieldoffset(ImDrawVert, 3)
    glVertexAttribPointer(ctx.AttribLocationVtxPos[],   2, GL_FLOAT,         GL_FALSE, sizeof(ImDrawVert), Ptr{GLCvoid}(pos_offset))
    glVertexAttribPointer(ctx.AttribLocationVtxUV[],    2, GL_FLOAT,         GL_FALSE, sizeof(ImDrawVert), Ptr{GLCvoid}(uv_offset))
    glVertexAttribPointer(ctx.AttribLocationVtxColor[], 4, GL_UNSIGNED_BYTE, GL_TRUE,  sizeof(ImDrawVert), Ptr{GLCvoid}(col_offset))

    return nothing
end

function ImGui_ImplOpenGL3_RenderDrawData(ctx::Context, draw_data)
    # avoid rendering when minimized, scale coordinates for retina displays
    fb_width = trunc(Cint, unsafe_load(draw_data.DisplaySize.x) * unsafe_load(draw_data.FramebufferScale.x))
    fb_height = trunc(Cint, unsafe_load(draw_data.DisplaySize.y) * unsafe_load(draw_data.FramebufferScale.y))
    (fb_width ≤ 0 || fb_height ≤ 0) && return nothing

    # backup GL state
    last_active_texture = GLint(0); @c glGetIntegerv(GL_ACTIVE_TEXTURE, &last_active_texture)
    glActiveTexture(GL_TEXTURE0)
    last_program = GLint(0); @c glGetIntegerv(GL_CURRENT_PROGRAM, &last_program)
    last_texture = GLint(0); @c glGetIntegerv(GL_TEXTURE_BINDING_2D, &last_texture)
    last_sampler = GLint(0); @c glGetIntegerv(GL_SAMPLER_BINDING, &last_sampler)
    last_array_buffer = GLint(0)
    ctx.GlslVersion ≥ 330 && @c glGetIntegerv(GL_ARRAY_BUFFER_BINDING, &last_array_buffer)
    last_vertex_array_object = GLint(0); @c glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &last_vertex_array_object)
    last_polygon_mode = GLint[0,0]; glGetIntegerv(GL_POLYGON_MODE, last_polygon_mode)
    last_viewport = GLint[0,0,0,0]; glGetIntegerv(GL_VIEWPORT, last_viewport)
    last_scissor_box = GLint[0,0,0,0]; glGetIntegerv(GL_SCISSOR_BOX, last_scissor_box)
    last_blend_src_rgb = GLint(0); @c glGetIntegerv(GL_BLEND_SRC_RGB, &last_blend_src_rgb)
    last_blend_dst_rgb = GLint(0); @c glGetIntegerv(GL_BLEND_DST_RGB, &last_blend_dst_rgb)
    last_blend_src_alpha = GLint(0); @c glGetIntegerv(GL_BLEND_SRC_ALPHA, &last_blend_src_alpha)
    last_blend_dst_alpha = GLint(0); @c glGetIntegerv(GL_BLEND_DST_ALPHA, &last_blend_dst_alpha)
    last_blend_equation_rgb = GLint(0); @c glGetIntegerv(GL_BLEND_EQUATION_RGB, &last_blend_equation_rgb)
    last_blend_equation_alpha = GLint(0); @c glGetIntegerv(GL_BLEND_EQUATION_ALPHA, &last_blend_equation_alpha)
    last_enable_blend = glIsEnabled(GL_BLEND)
    last_enable_cull_face = glIsEnabled(GL_CULL_FACE)
    last_enable_depth_test = glIsEnabled(GL_DEPTH_TEST)
    last_enable_stencil_test = glIsEnabled(GL_STENCIL_TEST)
    last_enable_scissor_test = glIsEnabled(GL_SCISSOR_TEST)
    last_enable_primitive_restart = ctx.GlslVersion ≥ 310 ? glIsEnabled(GL_PRIMITIVE_RESTART) : GL_FALSE

    vertex_array_object = GLuint(0)
    @c glGenVertexArrays(1, &vertex_array_object)
    ImGui_ImplOpenGL3_SetupRenderState(ctx, draw_data, fb_width, fb_height, vertex_array_object)

    # will project scissor/clipping rectangles into framebuffer space
    clip_off = unsafe_load(draw_data.DisplayPos)         # (0,0) unless using multi-viewports
    clip_scale = unsafe_load(draw_data.FramebufferScale) # (1,1) unless using retina display which are often (2,2)

    # render command lists
    data = unsafe_load(draw_data)
    cmd_lists = unsafe_wrap(Vector{Ptr{ImDrawList}}, data.CmdLists, data.CmdListsCount)
    for cmd_list in cmd_lists
        vtx_buffer = cmd_list.VtxBuffer |> unsafe_load
        idx_buffer = cmd_list.IdxBuffer |> unsafe_load
        # glBindBuffer(GL_ARRAY_BUFFER, g_VboHandle[])
        glBufferData(GL_ARRAY_BUFFER, vtx_buffer.Size * sizeof(ImDrawVert), Ptr{GLCvoid}(vtx_buffer.Data), GL_STREAM_DRAW)

        # glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_ElementsHandle[])
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, idx_buffer.Size * sizeof(ImDrawIdx), Ptr{GLCvoid}(idx_buffer.Data), GL_STREAM_DRAW)

        cmd_buffer = cmd_list.CmdBuffer |> unsafe_load
        for cmd_i = 0:cmd_buffer.Size-1
            pcmd = cmd_buffer.Data + cmd_i * sizeof(ImDrawCmd)
            elem_count = unsafe_load(pcmd.ElemCount)
            cb_funcptr = unsafe_load(pcmd.UserCallback)
            if cb_funcptr != C_NULL
                # user callback (registered via ImDrawList_AddCallback)
                # ImDrawCallback_ResetRenderState is a special callback value used by the user to request the renderer to reset render state.
                if cb_funcptr == ctx.ImDrawCallback_ResetRenderState
                    ImGui_ImplOpenGL3_SetupRenderState(ctx, draw_data, fb_width, fb_height, vertex_array_object);
                else
                    ccall(cb_funcptr, Cvoid, (Ptr{ImDrawList}, Ptr{ImDrawCmd}), cmd_list, pcmd)
                end
            else
                # project scissor/clipping rectangles into framebuffer space
                rect = unsafe_load(pcmd.ClipRect)
                clip_rect_x = (rect.x - clip_off.x) * clip_scale.x
                clip_rect_y = (rect.y - clip_off.y) * clip_scale.y
                clip_rect_z = (rect.z - clip_off.x) * clip_scale.x
                clip_rect_w = (rect.w - clip_off.y) * clip_scale.y
                if clip_rect_x < fb_width && clip_rect_y < fb_height && clip_rect_z ≥ 0 && clip_rect_w ≥ 0
                    # apply scissor/clipping rectangle
                    ix = trunc(Cint, clip_rect_x)
                    iy = trunc(Cint, fb_height - clip_rect_w)
                    iz = trunc(Cint, clip_rect_z - clip_rect_x)
                    iw = trunc(Cint, clip_rect_w - clip_rect_y)
                    glScissor(ix, iy, iz, iw)
                    # bind texture, draw
                    glBindTexture(GL_TEXTURE_2D, UInt(unsafe_load(pcmd.TextureId)))
                    format = sizeof(ImDrawIdx) == 2 ? GL_UNSIGNED_SHORT : GL_UNSIGNED_INT
                    glDrawElementsBaseVertex(GL_TRIANGLES, GLsizei(elem_count), format, Ptr{Cvoid}(unsafe_load(pcmd.IdxOffset) * sizeof(ImDrawIdx)), GLint(unsafe_load(pcmd.VtxOffset)))
                end
            end
        end
    end
    @c glDeleteVertexArrays(1, &vertex_array_object)

    # restore modified GL state
    glUseProgram(last_program)
    glBindTexture(GL_TEXTURE_2D, last_texture)
    ctx.GlslVersion > 330 && glBindSampler(0, last_sampler)
    glActiveTexture(last_active_texture)
    glBindVertexArray(last_vertex_array_object)
    glBindBuffer(GL_ARRAY_BUFFER, last_array_buffer)
    glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha)
    glBlendFuncSeparate(last_blend_src_rgb, last_blend_dst_rgb, last_blend_src_alpha, last_blend_dst_alpha)
    last_enable_blend ? glEnable(GL_BLEND) : glDisable(GL_BLEND)
    last_enable_cull_face ? glEnable(GL_CULL_FACE) : glDisable(GL_CULL_FACE)
    last_enable_depth_test ? glEnable(GL_DEPTH_TEST) : glDisable(GL_DEPTH_TEST)
    last_enable_stencil_test ? glEnable(GL_STENCIL_TEST) : glDisable(GL_STENCIL_TEST)
    last_enable_scissor_test ? glEnable(GL_SCISSOR_TEST) : glDisable(GL_SCISSOR_TEST)
    if ctx.GlslVersion ≥ 310
        last_enable_primitive_restart ? glEnable(GL_PRIMITIVE_RESTART) : glDisable(GL_PRIMITIVE_RESTART)
    end

    glPolygonMode(GL_FRONT_AND_BACK, GLenum(last_polygon_mode[1]))
    glViewport(last_viewport[1], last_viewport[2], GLsizei(last_viewport[3]), GLsizei(last_viewport[4]))
    glScissor(last_scissor_box[1], last_scissor_box[2], GLsizei(last_scissor_box[3]), GLsizei(last_scissor_box[4]))

    return nothing
end
