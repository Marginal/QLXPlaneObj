//
//  obj.h
//  QLXPlaneObj
//
//  Created by Jonathan Harris on 07/04/2016.
//
//

#ifndef obj_h
#define obj_h

#import <Foundation/Foundation.h>

#if APL
# include <OpenGL/gl.h>
#else
# include <GL/gl.h>
#endif

#include <stdio.h>
#include <string.h>

#include "XObjDefs.h"


struct DrawInfo_t
{
    GLboolean lighting;
    GLuint tex, drp, pan;
    CFDataRef texdata, drpdata, pandata;
};


@interface XPlaneOBJ : NSObject
{
    CFURLRef objfile;
    bool mIsObj8;
    XObj mObj;
    XObj8 mObj8;
}

- (instancetype) initWithURL : (CFURLRef)url;
+ (instancetype) objWithURL : (CFURLRef)url;

- (CGImageRef) CreateImageWithSize:(CGSize)size;
@end


#endif /* obj_h */
