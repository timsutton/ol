#!/usr/bin/ol
(import (lib gl))
(gl:set-window-title "1. Creating an OpenGL Window (dynamically change screen size)")
(gl:set-window-size 1280 720)

(import (OpenGL version-1-0))

; init
(glShadeModel GL_SMOOTH)
(glClearColor 0.3 0.3 0.3 1)

; draw loop
(gl:set-renderer (lambda (mouse)
   (glClear GL_COLOR_BUFFER_BIT)))
