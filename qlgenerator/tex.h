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


typedef enum
{
    kTexPrimaryRole	= 0,
    kTexPanelRole	= 1,
    kTexDrapedRole	= 2,
    kTexRoleCount	= 3,
} TexRole;


GLuint BlankTex();
GLuint LoadTex(TexRole role, CFURLRef objname, const char *texname);

#endif /* tex_h */
