//
//  obj.m
//  QLXPlaneObj
//
//  Created by Jonathan Harris on 07/04/2016.
//
//


#ifdef APL
# include <OpenGL/gl.h>
#else
# include <GL/gl.h>
#endif

#import "obj.h"
#include "context.h"

#include "XObjDefs.h"
#include "XObjReadWrite.h"
#include "ObjDraw.h"
#include "ObjUtils.h"



extern "C"
{
#include "tex.h"
}


static void	SetupPoly(void * ref)
{
    DrawInfo_t *i = (DrawInfo_t *) ref;
    glBindTexture(GL_TEXTURE_2D, i->tex);
}

static void SetupLineLight(void * ref)
{
    DrawInfo_t *i = (DrawInfo_t *) ref;
    glBindTexture(GL_TEXTURE_2D, i->blank);
}

static void	SetupPanel(void * ref)
{
    DrawInfo_t *i = (DrawInfo_t *) ref;
    glBindTexture(GL_TEXTURE_2D, i->pan);
}

static void	TexCoord(const float * st, void * ref)
{
    glTexCoord2fv(st);
}

static void	TexCoordPointer(int size, unsigned long type, long stride, const void * pointer, void * ref)
{
    glTexCoordPointer(size, type, stride, pointer);
}

static float GetAnimParam(const char * string, float v1, float v2, void * ref)
{
    return 0.f;
}

static void	SetupDraped(void * ref)
{
    DrawInfo_t *i = (DrawInfo_t *) ref;
    glBindTexture(GL_TEXTURE_2D, i->drp);
}

static	ObjDrawFuncs10_t sCallbacks =
{
    SetupPoly, SetupLineLight, SetupLineLight, SetupPoly, SetupPanel,
    TexCoord, TexCoordPointer, GetAnimParam,
    SetupDraped, SetupPoly
};


// https://developer.apple.com/library/mac/documentation/GraphicsImaging/Conceptual/OpenGL-MacProgGuide/opengl_offscreen/opengl_offscreen.html


@implementation XPlaneOBJ

- (instancetype) initWithURL:(CFURLRef)url
{
    if (!(self = [super init]))
        return nil;

    objfile = url;
    CFRetain(objfile);

    CFIndex filenamesize = CFStringGetMaximumSizeOfFileSystemRepresentation(CFURLGetString(objfile));
    char *filename = (char *) malloc(filenamesize);
    if (!filename)
        return nil;
    if (CFURLGetFileSystemRepresentation(objfile, true, (UInt8*)filename, filenamesize))
    {
        if (XObj8Read(filename, mObj8))
        {
            mIsObj8 = true;
            free(filename);
            return self;
        }
        else if (XObjRead(filename, mObj))
        {
            mIsObj8 = false;
            free(filename);
            return self;
        }
    }
#ifdef DEBUG
    NSLog(@"Can't open %@", url);
#endif

    free(filename);
    return nil;
}


- (CGImageRef) CreateImageWithSize:(CGSize)size;
{
    DrawInfo_t info = {};
    float	mins[3];
    float	maxs[3];
    if (mIsObj8)
    {
        GetObjDimensions8(mObj8, mins, maxs);
        if (int err = context_setup(-1, size.width, size.height, mins, maxs))
        {
#ifdef DEBUG
            NSLog(@"XPlaneOBJ Can't set up context, err = %#x", err);
#endif
            return NULL;
        }
        info.blank = BlankTex();
        info.tex = LoadTex(kTexPrimaryRole, objfile, mObj8.texture.c_str());
        info.drp = LoadTex(kTexDrapedRole, objfile, mObj8.texture_draped.c_str());
        info.pan = LoadTex(kTexPanelRole, objfile, "cockpit_3d/-PANELS-/Panel_Preview.png");
        ObjDraw8(mObj8, 0.f, &sCallbacks, &info);
    }
    else
    {
        GetObjDimensions(mObj, mins, maxs);
        if (int err = context_setup(0, size.width, size.height, mins, maxs))
        {
#ifdef DEBUG
            NSLog(@"XPlaneOBJ Can't set up context, err = %#x", err);
#endif
            return NULL;
        }
        info.blank = BlankTex();
        info.tex = LoadTex(kTexPrimaryRole, objfile, mObj.texture.c_str());
        info.pan = LoadTex(kTexPanelRole, objfile, "cockpit_3d/-PANELS-/Panel_Preview.png");
        ObjDraw(mObj, 0.f, &sCallbacks, &info);
    }
    glFlush();
    ASSERT_GL;

#if APL
    UInt32 *img_data;
    if (!(img_data = (UInt32 *) malloc(size.width * size.height * 4)))
        return NULL;

    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glReadPixels(0, 0, size.width, size.height, GL_BGRA, GL_UNSIGNED_BYTE, img_data);
    // flip
    UInt32 *y0, *y1, stride = size.width;
    for (UInt32 *y0 = img_data, *y1 = img_data + (((UInt32) size.height - 1) * stride); y0 < y1; y0 += stride, y1 -= stride)
    {
        UInt32 *x0, *x1, tmp;
        for (x0 = y0, x1 = y1; x0 < y0 + stride; x0++, x1++)
        {
            tmp = *x0;
            *x0 = *x1;
            *x1 = tmp;
        }
    }
#else
    GLint *img_data = context_buffer();
#endif

    // Wangle into a CGImage via a CGBitmapContext
    // OSX wants premultiplied alpha. See "Supported Pixel Formats" at
    // https://developer.apple.com/Library/mac/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html

    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(img_data, size.width, size.height, 8, size.width * 4, rgb, kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(rgb);
    CGImageRef image = NULL;
    if (context)
    {
        image = CGBitmapContextCreateImage(context);	// copy or copy-on-write img_data
        CGContextRelease(context);
    }

#if APL
    free(img_data);
#endif
    return image;
}

+ (id) objWithURL:(CFURLRef)url
{
    XPlaneOBJ* obj = [[[self class] alloc] initWithURL:url];
    return obj;
}

- (void) dealloc
{
    CFRelease(objfile);
}


@end

