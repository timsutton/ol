; OpenGL 3.3 (11 Mar 2010) GLSL 3.30
(define-library (OpenGL version-3-3)
(export

   GL_VERSION_3_3

   (exports (OpenGL version-3-2)))

(import (scheme core)
   (OpenGL version-3-2))

(begin
   (define GL_VERSION_3_3 1)


))