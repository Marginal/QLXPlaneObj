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

const float	vFOV = 30.f;

#if APL
static CGLContextObj ctx;
static GLuint framebuffer, texture, depth;
#else
static OSMesaContext ctx;
GLint *framebuffer;
#endif

static int failed;
static GLsizei fbo_width, fbo_height;


// Setup OpenGL context. Returns non-zero on error.
int context_setup(int have_normals, GLsizei width, GLsizei height, float minCoords[3], float maxCoords[3])
{
    // If setup fails, don't keep trying
    if (failed)
        return failed;
    failed = -1;

    if (!ctx)
    {
#if APL
        // http://renderingpipeline.com/2012/05/windowless-opengl-on-macos-x/

        CGLPixelFormatAttribute attributes[] =
        {
            kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute) kCGLOGLPVersion_Legacy,   // Need legacy profile for immediate mode
            kCGLPFAAlphaSize, (CGLPixelFormatAttribute) 8,
            kCGLPFADepthSize, (CGLPixelFormatAttribute) 24,     // In practice get 24
            (CGLPixelFormatAttribute) 0
        };
        CGLError errorCode;
        CGLPixelFormatObj pix;
        GLint npix;
        if ((errorCode = CGLChoosePixelFormat(attributes, &pix, &npix)))
            return errorCode;

        if ((errorCode = CGLCreateContext(pix, NULL, &ctx)))
        {
            CGLDestroyPixelFormat(pix);
            return errorCode;
        }
        CGLDestroyPixelFormat(pix);

        if ((errorCode = CGLSetCurrentContext(ctx)))
            return errorCode;

        // Set up FBO for rendering into texture unit 0
        fbo_width  = width;
        fbo_height = height;

        glGenFramebuffers(1, &framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        ASSERT_GL;

        glGenTextures(1, &texture);
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
        ASSERT_GL;

        glGenRenderbuffers(1, &depth);
        glBindRenderbuffer(GL_RENDERBUFFER, depth);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, width, height);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depth);
        ASSERT_GL;

        GLenum status;
        status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (status != GL_FRAMEBUFFER_COMPLETE)
            return status;

        glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE); // means we will need to retain texture data

#else   // !APL
        fbo_width  = width;
        fbo_height = height;
        if (!(framebuffer = malloc(fbo_width * fbo_height * 4)) ||
            !(ctx = OSMesaCreateContextExt(OSMESA_BGRA, 32, 0, 0, NULL)) ||
            !OSMesaMakeCurrent(ctx, framebuffer, GL_UNSIGNED_BYTE, fbo_width, fbo_height))
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

        glViewport(0, 0, width, height);
        ASSERT_GL;
    }
    else    // Use existing context
#if APL
    {
        CGLError errorCode;
        if ((errorCode = CGLSetCurrentContext(ctx)))
            return errorCode;

        if (width != fbo_width || height != fbo_height)
        {
            fbo_width  = width;
            fbo_height = height;

            glBindTexture(GL_TEXTURE_2D, texture);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_BGRA, GL_UNSIGNED_BYTE, NULL);

            glBindRenderbuffer(GL_RENDERBUFFER, depth);
            glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, width, height);

            glViewport(0, 0, width, height);
            ASSERT_GL;
        }
    }
#else   // !APL
    {
        failed = -2;
        if (width != fbo_width || height != fbo_height)
        {
            fbo_width  = width;
            fbo_height = height;
            if (!(framebuffer = reallocf(framebuffer, fbo_width * fbo_height * 4)))
                return failed;
        }
        if (!OSMesaMakeCurrent(ctx, framebuffer, GL_UNSIGNED_BYTE, fbo_width, fbo_height))
            return failed;
        glViewport(0, 0, width, height);
        ASSERT_GL;
        failed = 0;
    }
#endif

    // Reset OpenGL state
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    double hFOV = 1 / tan((vFOV/2) * (M_PI/180) * (double) width / (double) height);
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

    gluPerspective(vFOV, (GLdouble) width / (GLdouble) height, maxdist / 2, maxdist * 1.5);

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
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteTextures(1, &texture);
    glDeleteRenderbuffers(1, &depth);
    glDeleteFramebuffers(1, &framebuffer);

    CGLSetCurrentContext(NULL);
    CGLDestroyContext(ctx);
#else
    free(framebuffer);
    OSMesaDestroyContext(ctx);
#endif
    ctx = NULL;
    failed = 0;
}


#if !APL
GLint *context_buffer()
{
    return framebuffer;
}
#endif
