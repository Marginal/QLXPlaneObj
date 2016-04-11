//
//  tex.h
//  QLXPlaneObj
//
//  Created by Jonathan Harris on 07/04/2016.
//
//

#ifndef tex_h
#define tex_h

#import <Foundation/Foundation.h>

#include "dds.h"

GLuint LoadTex(CFURLRef objname, const char *texname, CFDataRef *data);

#endif /* tex_h */
