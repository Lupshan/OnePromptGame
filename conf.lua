function love.conf(t)
  t.identity = "cendre"
  t.version = "11.5"
  t.window.title = "CENDRE"
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.vsync = 1
  t.window.minwidth = 640
  t.window.minheight = 360
  t.modules.physics = false -- we roll our own AABB physics
  t.modules.joystick = true
  t.modules.touch = false
  t.modules.video = false
end
