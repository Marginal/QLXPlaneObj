//
//  context.h
//  QLXPlaneObj
//
//  Created by Jonathan Harris on 08/04/2016.
//
//

#ifndef context_h
#define context_h

#if APL
# include <OpenGL/gl.h>
#else
# include <GL/gl.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifdef DEBUG
# include <stdio.h>
# include <stdlib.h>
# define ASSERT_GL { GLenum e = glGetError(); if (e != GL_NO_ERROR) { fprintf(stderr, "%s:%u: OpenGL error %#x\n", __FILE__, __LINE__, e); exit(e); } }
#else
# define ASSERT_GL ((void)0)
#endif

int context_setup(int have_normals, GLsizei width, GLsizei height, float minCoords[3], float maxCoords[3]);
void context_destroy();
unsigned *context_read_buffer();
void context_free_buffer();

#ifdef __cplusplus
}   // extern "C"
#endif


#endif /* context_h */
