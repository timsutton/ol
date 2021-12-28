#!/usr/bin/env ol

;; initialize OpenGL
(import (lib gl))
(gl:set-window-title "5.glsl.lisp")
(import (OpenGL version-2-1))

(import (scene))

; load (and create if no one) a models cache
(define models (prepare-models "cache.bin"))

;; load a scene
(import (file json))
(define scene (read-json-file "scene1.json"))

;; init
(glShadeModel GL_SMOOTH)
(glEnable GL_DEPTH_TEST)

(glEnable GL_CULL_FACE)
(glCullFace GL_BACK)

; create glsl shader program
(define greeny (gl:CreateProgram
"#version 120 // OpenGL 2.1
   #define gl_WorldMatrix gl_TextureMatrix[7]
   void main() {
      gl_Position = gl_ModelViewProjectionMatrix * gl_WorldMatrix * gl_Vertex;
   }"
"#version 120 // OpenGL 2.1
   void main() {
      gl_FragColor = vec4(0, 1, 0, 1);
   }"))

; draw
(gl:set-renderer (lambda (mouse)
   (glClearColor 0.1 0.1 0.1 1)
   (glClear (vm:ior GL_COLOR_BUFFER_BIT GL_DEPTH_BUFFER_BIT))

   (glUseProgram greeny)

   ; Camera setup
   (begin
      (define camera (ref (scene 'Cameras) 1))

      (define angle (camera 'angle))
      (define location (camera 'location))
      (define target (camera 'target))

      (glMatrixMode GL_PROJECTION)
      (glLoadIdentity)
      (gluPerspective angle (/ (gl:get-window-width) (gl:get-window-height)) 0.1 100) ; (camera 'clip_start) (camera 'clip_end)

      (glMatrixMode GL_MODELVIEW)
      (glLoadIdentity)
      (gluLookAt
         (ref location 1) (ref location 2) (ref location 3)
         (ref target 1) (ref target 2) (ref target 3)
         0 0 1))

   ; draw a geometry
   (draw-geometry scene models)
))
