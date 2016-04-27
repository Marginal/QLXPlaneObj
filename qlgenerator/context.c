//
//  context.c
//  QLXPlaneObj
//
//  Created by Jonathan Harris on 08/04/2016.
//
//

#include <stddef.h>
#include <stdlib.h>
#include <math.h>
#include <sys/syslog.h>

#if APL
# include <OpenGL/gl.h>
# include <OpenGL/OpenGL.h>
# include <OpenGL/CGLTypes.h>
# include <OpenGL/glu.h>
#else
# include <GL/gl.h>
# include <GL/osmesa.h>
# include <glu.h>
#endif

#include "context.h"

static const float	vFOV = 30.f;
static const GLsizei kMaxWidth = 1024;
static const GLsizei kMaxHeight = 1024;

#if APL
static CGLContextObj ctx;
static GLuint framebuffer, texture, depth;
#else
static OSMesaContext ctx;
#endif

static int failed;
static GLsizei fbo_width, fbo_height;
static GLsizei img_width, img_height;
static unsigned *img_data;


// Setup OpenGL context. Returns non-zero on error.
int context_setup(int have_normals, GLsizei width, GLsizei height, float minCoords[3], float maxCoords[3])
{
    // If setup fails, don't keep trying
    if (failed)
        return failed;
    failed = -1;

    // Set limits so we don't use too much of QuickLookSatellite's memory allocation (currently 120MB)
    img_width  = width  > kMaxWidth  ? kMaxWidth  : width;
    img_height = height > kMaxHeight ? kMaxHeight : height;

    if (!ctx)
    {
        fbo_width  = img_width;
        fbo_height = img_height;
#if APL
        if (!(img_data = malloc(img_width * img_height * 4)))
            return failed;

        // http://renderingpipeline.com/2012/05/windowless-opengl-on-macos-x/

        CGLPixelFormatAttribute attributes[] =
        {
            kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute) kCGLOGLPVersion_Legacy,   // Need legacy profile for immediate mode
            kCGLPFARemotePBuffer,	// Need a context that allows us to draw in the absence of a connection to the Window Server (otherwise kCGLBadConnection)
            kCGLPFAAllowOfflineRenderers,   // Allow headless
            kCGLPFASingleRenderer,  // Don't need to switch between displays
            kCGLPFAColorSize, 32,
            kCGLPFAAlphaSize, 8,
            kCGLPFADepthSize, 24,   // must be last for the following code
            0
        };
        CGLError errorCode;
        CGLPixelFormatObj pix;
        GLint npix;

        if ((errorCode = CGLChoosePixelFormat(attributes, &pix, &npix)) || !npix)   // Can get zero available pixel formats but no error
        {
            // try with smaller depth buffer
            attributes[sizeof(attributes)/sizeof(CGLPixelFormatAttribute)-2] = 16;
            errorCode = CGLChoosePixelFormat(attributes, &pix, &npix);
        }

        if (errorCode || !npix ||
            (errorCode = CGLCreateContext(pix, NULL, &ctx)) ||
            (errorCode = CGLSetCurrentContext(ctx)))
        {
            syslog(LOG_WARNING, !npix ? "XPlaneObj: Can't get a pixel format: %s (%d)" : "XPlaneObj: Can't create context: %s (%d)", CGLErrorString(errorCode), errorCode);

            // https://developer.apple.com/library/mac/qa/qa1168/_index.html
            GLint nrend = 0;
            CGLRendererInfoObj rend;
            CGLQueryRendererInfo(-1, &rend, &nrend);
            for(GLint i = 0; i < nrend; i++)
            {
                GLint re, on, dp, ac, os, cm, dm, vm, tm;
                CGLDescribeRenderer(rend, i, kCGLRPRendererID, &re);
                CGLDescribeRenderer(rend, i, kCGLRPOnline, &on);
                CGLDescribeRenderer(rend, i, kCGLRPDisplayMask, &dp);
                CGLDescribeRenderer(rend, i, kCGLRPAccelerated, &ac);
                CGLDescribeRenderer(rend, i, kCGLRPOffScreen, &os);
                CGLDescribeRenderer(rend, i, kCGLRPColorModes, &cm);
                CGLDescribeRenderer(rend, i, kCGLRPDepthModes, &dm);
                CGLDescribeRenderer(rend, i, kCGLRPVideoMemory, &vm);
                CGLDescribeRenderer(rend, i, kCGLRPTextureMemory, &tm);
                syslog(LOG_NOTICE, "XPlaneObj: Renderer:%d, ID:0x%x, online:%d, displays:0x%x, accelerated:%d, off-screen:%d, colormodes:0x%08x, depthmodes:0x%08x, vmem:%d, tmem:%d", i, re & kCGLRendererIDMatchingMask, on, dp, ac, os, cm, dm, vm, tm);
            }
            CGLDestroyRendererInfo(rend);

            if (npix)
            {
                GLint re, ac, os, c, a, d;
                CGLDescribePixelFormat(pix, 0, kCGLPFARendererID, &re);
                CGLDescribePixelFormat(pix, 0, kCGLPFAAccelerated, &ac);
                CGLDescribePixelFormat(pix, 0, kCGLPFAOffScreen, &os);
                CGLDescribePixelFormat(pix, 0, kCGLPFAColorSize, &c);
                CGLDescribePixelFormat(pix, 0, kCGLPFAAlphaSize, &a);
                CGLDescribePixelFormat(pix, 0, kCGLPFADepthSize, &d);
                syslog(LOG_NOTICE, "XPlaneObj: #Formats:%d, ID:0x%x, accelerated:%d, off-screen:0x%x, colors:%d, alpha:%d, depth:%d", npix, re & kCGLRendererIDMatchingMask, ac, os, c, a, d);
                CGLDestroyPixelFormat(pix);
                if (ctx)
                    CGLReleaseContext(ctx);
            }

            return failed;
        }

        CGLDestroyPixelFormat(pix);

        // Set up FBO for rendering into texture unit 0
        glGenFramebuffers(1, &framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        ASSERT_GL;

        glGenTextures(1, &texture);
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, fbo_width, fbo_height, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
        ASSERT_GL;

        glGenRenderbuffers(1, &depth);
        glBindRenderbuffer(GL_RENDERBUFFER, depth);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, fbo_width, fbo_height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depth);
        ASSERT_GL;

        GLenum status;
        status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (status != GL_FRAMEBUFFER_COMPLETE)
            return status;

        glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE); // means we will need to retain texture data

#else   // !APL
        if (!(img_data = malloc(fbo_width * fbo_height * 4)) ||
            !(ctx = OSMesaCreateContextExt(OSMESA_BGRA, 32, 0, 0, NULL)) ||
            !OSMesaMakeCurrent(ctx, img_data, GL_UNSIGNED_BYTE, fbo_width, fbo_height))
            return failed;
        OSMesaPixelStore(OSMESA_Y_UP, 0);	// So we don't have to flip the finished image
#endif

        // Set up OpenGL state
        glClearColor(0.f, 0.f, 0.f, 0.f);
        glCullFace(GL_BACK);
        glFrontFace(GL_CW);
        glDepthFunc(GL_LEQUAL);
        glAlphaFunc(GL_GREATER, 0.5f);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);	// assumes not pre-multiplied - but see http://stackoverflow.com/questions/24346585/opengl-render-to-texture-with-partial-transparancy-translucency-and-then-rende

        glEnable(GL_LIGHT0);
        glEnable(GL_LIGHTING);
        glColorMaterial(GL_FRONT, GL_AMBIENT_AND_DIFFUSE);  // ObjDraw sets glColor in response to ATTR_diffuse
        glEnable(GL_COLOR_MATERIAL);

        // OpenGL textures are backwards
        glMatrixMode(GL_TEXTURE);
        glLoadIdentity();
        glTranslatef(0, 1, 0);
        glScalef(1, -1, 1);
        ASSERT_GL;
    }
    else    // Use existing context
#if APL
    {
        if (CGLSetCurrentContext(ctx))
        {
            CGLReleaseContext(ctx);
            return failed;
        }

        if (img_width > fbo_width || img_height > fbo_height)   // Don't bother shrinking FBO - we'll probably need the larger size again soon
        {
            if (!(img_data = reallocf(img_data, img_width * img_height * 4)))
                return failed;

            // Resize FBO attachments
            fbo_width  = img_width;
            fbo_height = img_height;

            glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE); // temporarily disable
            glBindTexture(GL_TEXTURE_2D, texture);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, fbo_width, fbo_height, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);

            glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, fbo_width, fbo_height);

            GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
            if (status != GL_FRAMEBUFFER_COMPLETE)
                return status;

            glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE); // means we will need to retain texture data
            ASSERT_GL;
        }
    }
#else   // !APL
    {
        if (img_width != fbo_width || img_height != fbo_height) // Keep FBO size equal to requested image size
        {
            fbo_width  = img_width;
            fbo_height = img_height;
            if (!(img_data = reallocf(img_data, fbo_width * fbo_height * 4)))
                return failed;
        }
        if (!OSMesaMakeCurrent(ctx, img_data, GL_UNSIGNED_BYTE, fbo_width, fbo_height))
            return failed;
        ASSERT_GL;
    }
#endif

    // Reset OpenGL state
    glViewport(0, 0, img_width, img_height);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    double hFOV = 1 / tan((vFOV/2) * (M_PI/180) * (double) img_width / (double) img_height);
    float centre[3] = { (maxCoords[0] + minCoords[0]) / 2, minCoords[1] + (maxCoords[1] - minCoords[1]) * 0.4, (maxCoords[2] + minCoords[2]) / 2 };
    float size[3] = { (maxCoords[0] - minCoords[0]), (maxCoords[1] - minCoords[1]), (maxCoords[2] - minCoords[2]) };
    float dist[3] =
    {
        ((size[1] + (size[0] * 0.25)) * 0.65) / tan((vFOV/2) * (M_PI/180)),    // arbitrary height factor
        (size[2] * 0.443 + size[0] * 0.25) * hFOV,      // width at 30deg / 2
        (size[0] * 0.443 + size[2] * 0.25) * hFOV       // depth at 60deg / 2
    };
    float maxdist = dist[0];
    if (maxdist < dist[1]) maxdist = dist[1];
    if (maxdist < dist[2]) maxdist = dist[2];

    gluPerspective(vFOV, (GLdouble) img_width / (GLdouble) img_height, maxdist / 2, maxdist * 1.5);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glEnable(GL_TEXTURE_2D);
    glEnable(GL_CULL_FACE);
    glEnable(GL_DEPTH_TEST);
    glDisable(GL_ALPHA_TEST);	// X-Plane defaults to ATTR_blend
    glEnable(GL_BLEND);
    glDisable(GL_POLYGON_OFFSET_FILL);
    glPolygonOffset(0.0, 0.0);
    glDepthMask(GL_TRUE);
    glShadeModel(GL_SMOOTH);

    glColor3f(1.f, 1.f, 1.f);
    GLfloat zero[4] = { 0, 0, 0, 1.f };
    glMaterialfv(GL_FRONT, GL_SPECULAR, zero);
    glMaterialfv(GL_FRONT, GL_EMISSION, zero);
    glMateriali (GL_FRONT, GL_SHININESS, 0);

    GLfloat lgt_blk[4] = { 0, 0, 0, 1.f };
    glLightModelfv(GL_LIGHT_MODEL_AMBIENT, lgt_blk);
    if (have_normals)
    {
        GLfloat lgt_amb[4] = { 0.5f, 0.5f, 0.5f, 1.f };
        GLfloat lgt_dif[4] = { 0.5f, 0.5f, 0.5f, 1.f };
        glLightfv(GL_LIGHT0,GL_AMBIENT , lgt_amb);
        glLightfv(GL_LIGHT0,GL_DIFFUSE , lgt_dif);
        glLightfv(GL_LIGHT0,GL_SPECULAR, lgt_blk);
    }
    else
    {
        GLfloat lgt_amb[4] = { 0.8f, 0.8f, 0.8f, 1.f };
        GLfloat lgt_dif[4] = { 0, 0, 0, 1.f };
        glLightfv(GL_LIGHT0,GL_AMBIENT , lgt_amb);
        glLightfv(GL_LIGHT0,GL_DIFFUSE , lgt_dif);
        glLightfv(GL_LIGHT0,GL_SPECULAR, lgt_blk);
    }

    GLfloat lgt_dir[4]={ 0, 0.25f, 1.f, 0 };
    glLightfv(GL_LIGHT0,GL_POSITION, lgt_dir);  // note: uses model matrix

    gluLookAt(centre[0] - 0.866 * maxdist, centre[1] + 0.5 * maxdist, centre[2] - 0.5 * maxdist,
              centre[0], centre[1], centre[2],
              0.0, 1.0, 0.0);
    ASSERT_GL;

    failed = 0;
    return failed;
}


void context_destroy()
{
#if APL
    glDeleteFramebuffers(1, &framebuffer);
    glDeleteTextures(1, &texture);
    glDeleteRenderbuffers(1, &depth);

    CGLSetCurrentContext(NULL);
    CGLReleaseContext(ctx);
#else
    OSMesaDestroyContext(ctx);
#endif
    ctx = NULL;
    free(img_data);
    img_data = NULL;
    failed = 0;
}


unsigned *context_read_buffer(size_t *width, size_t *height)
{
    glFlush();
    ASSERT_GL;

#if APL
    // don't bother with a PBO - there's nothing that we can usefully do while waiting for the download
    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glReadPixels(0, 0, img_width, img_height, GL_BGRA, GL_UNSIGNED_BYTE, img_data);
    // flip
    unsigned *y0, *y1, stride = img_width;
    for (unsigned *y0 = img_data, *y1 = img_data + ((img_height - 1) * stride); y0 < y1; y0 += stride, y1 -= stride)
    {
        unsigned *x0, *x1, tmp;
        for (x0 = y0, x1 = y1; x0 < y0 + stride; x0++, x1++)
        {
            tmp = *x0;
            *x0 = *x1;
            *x1 = tmp;
        }
    }
#endif
    *width = img_width;
    *height = img_height;
    return img_data;
}
