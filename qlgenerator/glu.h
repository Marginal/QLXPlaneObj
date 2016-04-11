//
//  glu.h
//  QLXPlaneObj
//
//  Created by Jonathan Harris on 09/04/2016.
//
//

#ifndef glu_h
#define glu_h

#if !APL
# include <GL/gl.h>

void gluLookAt(GLdouble eyeX, GLdouble eyeY, GLdouble eyeZ, GLdouble centerX, GLdouble centerY, GLdouble centerZ, GLdouble upX, GLdouble upY, GLdouble upZ);
void gluPerspective(GLdouble fovy, GLdouble aspect, GLdouble zNear, GLdouble zFar);

# endif // APL

#endif /* glu_h */
