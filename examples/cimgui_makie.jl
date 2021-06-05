using CImGui
using ImGuiMakieBackend
using GLMakie

x = rand(10)
y = rand(10)
colors = rand(10)
scene = scatter(x, y, color = colors)

set_makie_renderloop()
