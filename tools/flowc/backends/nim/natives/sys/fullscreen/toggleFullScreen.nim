import sdl2

# Requires nimble install sdl2
# TODO: Figure out how to have a global window ptr somewhere

var window: WindowPtr

proc initWindow() =
  if sdl2.init(INIT_VIDEO) != 0:
    raise newException(Exception, "Unable to initialize SDL2")

  window = createWindow("Flow", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 800, 600, SDL_WINDOW_SHOWN)
  if window == nil:
    raise newException(Exception, "Unable to create SDL2 window")

proc $F_0(toggleFullScreen)*(fs: bool) =
  if fs:
    window.setWindowFullscreen(SDL_WINDOW_FULLSCREEN)
  else:
    window.setWindowFullscreen(0)

# Example usage:
#initWindow()
#toggleFullScreen(true)
#sdl2.delay(5000)
#toggleFullScreen(false)
#sdl2.delay(5000)
#window.destroyWindow()
#sdl2.quit()
