//
//  tex.c
//  QLXPlaneObj
//
//  Created by Jonathan Harris on 07/04/2016.
//
//


#if APL
# include <OpenGL/gl.h>

static const unsigned int DDS_MAGIC   = 0x20534444;	// "DDS "
static const unsigned int FOURCC_DXT1 = 0x31545844;
static const unsigned int FOURCC_DXT3 = 0x33545844;
static const unsigned int FOURCC_DXT5 = 0x35545844;

#else
# include <GL/gl.h>
#endif

#include "tex.h"
#include "context.h"


// Cache
GLenum targets[kTexRoleCount];
NSURL *filenames[kTexRoleCount];
#if APL
CFDataRef *data[kTexRoleCount];   // We're using GL_UNPACK_CLIENT_STORAGE_APPLE so need to retain the source bitmap data
#endif


GLuint LoadTex(TexRole role, CFURLRef objname, const char *texname)
{
    if (! *texname || role >= kTexRoleCount)
        return 0;

    char *fixedname;
    if (!(fixedname = malloc(strlen(texname)+1)))
        return 0;

    // POSIXify texture name
    const char *s;
    char *d;
    for (s = texname, d = fixedname; *s; s++, d++)
    {
        if (*s == '\\' || *s == ':')
            *d = '/';
        else
            *d = *s;
    }
    *d = 0;

    NSURL *basename = [[[(__bridge NSURL*) objname URLByDeletingLastPathComponent] URLByAppendingPathComponent:[NSString stringWithUTF8String:fixedname]] URLByDeletingPathExtension];
    free(fixedname);

    // cached?
    NSURL *ddsfilename = [basename URLByAppendingPathExtension:@"dds"];
    NSURL *pngfilename = [basename URLByAppendingPathExtension:@"png"];
    if (role < kTexRoleCount &&
        targets[role] &&
        ([filenames[role] isEqual:ddsfilename] || [filenames[role] isEqual:pngfilename]))
        return targets[role];

#if APL
    // DDS loader - assumes little-endian machine so we can cast memory to struct
    DDS_header *ddsheader;
    NSData *ddsfile = [NSData dataWithContentsOfURL:ddsfilename];
    if (ddsfile &&
        ddsfile.length > sizeof(DDS_header) &&
        (ddsheader = (DDS_header *) ddsfile.bytes) &&
        ddsheader->dwMagic == DDS_MAGIC &&
        ddsheader->dwSize + sizeof(ddsheader->dwMagic) == sizeof(DDS_header) &&
        (ddsheader->sPixelFormat.dwFlags & DDPF_FOURCC) &&
        (ddsheader->sPixelFormat.dwFourCC == FOURCC_DXT1 ||
         ddsheader->sPixelFormat.dwFourCC == FOURCC_DXT3 ||
         ddsheader->sPixelFormat.dwFourCC == FOURCC_DXT5))
    {
        GLenum iformat;
        unsigned int blocksize;

        switch (ddsheader->sPixelFormat.dwFourCC)
        {
            case FOURCC_DXT1:
                iformat = GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
                blocksize = 8;
                break;

            case FOURCC_DXT3:
                iformat = GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
                blocksize = 16;
                break;

            case FOURCC_DXT5:
                iformat = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
                blocksize = 16;
                break;
        }

        GLsizei width = ddsheader->dwWidth;
        GLsizei height = ddsheader->dwHeight;
        GLsizei mipmaps = MAX(1, ddsheader->dwMipMapCount);   // according to http://msdn.microsoft.com/en-us/library/bb943982 we ignore DDSD_MIPMAPCOUNT in dwFlags
        const char *ddsdata = (char *) ddsfile.bytes + sizeof(DDS_header);

        if (targets[role])
        {
            filenames[role] = ddsfilename;
            CFRelease(data[role]);
        }
        else
            glGenTextures(1, &targets[role]);

        glBindTexture(GL_TEXTURE_2D, targets[role]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        if (mipmaps > 1)
        {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, mipmaps - 1);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        }
        else
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        ASSERT_GL;

        for (unsigned int level = 0; level < mipmaps; level++)
        {
            GLsizei size = ((width+3)/4) * ((height+3)/4) * blocksize;
            glCompressedTexImage2D(GL_TEXTURE_2D, level, iformat, width, height, 0, size, ddsdata);
            ddsdata += size;
            if (! (width /= 2))  width  = 1;
            if (! (height /= 2)) height = 1;
        }
        data[role] = CFBridgingRetain(ddsfile);  // keep a copy of the data
        return targets[role];
    }

#else
    DDS *dds = [DDS ddsWithURL:ddsfilename];
    if (dds)
    {
        GLsizei width = dds.mainSurfaceWidth;
        GLsizei height = dds.mainSurfaceHeight;
        GLsizei mipmaps = dds.mipmapCount;

        UInt8 *uncompressed;
        if (!(uncompressed = malloc(width * height * 4)))
            return 0;

        if (targets[role])
            filenames[role] = ddsfilename;
        else
            glGenTextures(1, &targets[role]);

        glBindTexture(GL_TEXTURE_2D, targets[role]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        if (mipmaps > 1)
        {
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, mipmaps - 1);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
        }
        else
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        for (unsigned int level = 0; level < mipmaps; level++)
        {
            [dds DecodeSurface:0 atLevel:level To:(UInt32*)uncompressed withStride:width];
            glTexImage2D(GL_TEXTURE_2D, level, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, uncompressed);
            if (! (width /= 2))  width  = 1;
            if (! (height /= 2)) height = 1;
        }
        free(uncompressed);
        return targets[role];
    }
#endif

    // PNG loader
    // https://developer.apple.com/library/mac/documentation/GraphicsImaging/Conceptual/OpenGL-MacProgGuide/opengl_texturedata/opengl_texturedata.html

    CGImageSourceRef imagesource = CGImageSourceCreateWithURL((__bridge CFURLRef) pngfilename, NULL);
    if (!imagesource)
        return 0;

    CGImageRef image = CGImageSourceCreateImageAtIndex(imagesource, 0, NULL);
    CFRelease(imagesource);
    if (!image)
        return 0;

    CFDataRef pngdata = CGDataProviderCopyData(CGImageGetDataProvider(image));
    CGImageRelease(image);
    if (!pngdata)
        return 0;

#if DEBUG
    CGImageAlphaInfo alphainfo = CGImageGetAlphaInfo(image);
    CGBitmapInfo bitmapinfo = CGImageGetBitmapInfo(image);
    size_t bpp = CGImageGetBitsPerPixel(image);
    const UInt8 *pixdata = CFDataGetBytePtr(pngdata);
#endif

    if (targets[role])
    {
        filenames[role] = ddsfilename;
#if APL
        CFRelease(data[role]);
#endif
    }
    else
        glGenTextures(1, &targets[role]);

    glBindTexture(GL_TEXTURE_2D, targets[role]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, CGImageGetWidth(image), CGImageGetHeight(image), 0, GL_RGBA, GL_UNSIGNED_INT_8_8_8_8_REV, CFDataGetBytePtr(pngdata));
    ASSERT_GL;

#if APL
    data[role] = CFBridgingRetain(pngdata);  // keep a copy of the data
#endif
    return targets[role];
}


void ClearCache()
{
    for (int i=0; i<kTexRoleCount; i++)
        if (targets[i])
        {
            glDeleteTextures(1, &targets[i]);
#if APL
            CFRelease(data[i]);
#endif
        }
}
