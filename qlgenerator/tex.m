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


GLuint LoadTex(CFURLRef objname, const char *texname, CFDataRef *data)
{
    *data = NULL;
    if (! *texname)
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

#if APL
    // DDS loader - assumes little-endian machine so we can cast memory to struct
    DDS_header *ddsheader;
    NSData *ddsfile = [NSData dataWithContentsOfURL:[basename URLByAppendingPathExtension:@"dds"]];
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

        GLuint texno;
        glGenTextures(1, &texno);
        glBindTexture(GL_TEXTURE_2D, texno);
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
        *data = CFBridgingRetain(ddsfile);  // keep a copy of the data
        return texno;
    }

#else
    DDS *dds = [DDS ddsWithURL: [basename URLByAppendingPathExtension:@"dds"]];
    if (dds)
    {
        GLsizei width = dds.mainSurfaceWidth;
        GLsizei height = dds.mainSurfaceHeight;
        GLsizei mipmaps = dds.mipmapCount;

        UInt8 *uncompressed;
        if (!(uncompressed = malloc(width * height * 4)))
            return 0;
        [dds DecodeSurface:0 atLevel:0 To:(UInt32*)uncompressed withStride:width];  // Ignore any mipmaps

        GLuint texno;
        glGenTextures(1, &texno);
        glBindTexture(GL_TEXTURE_2D, texno);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, uncompressed);

        // Wrap in a CFData for later freeing
        *data = CFDataCreateWithBytesNoCopy(NULL, uncompressed, width * height * 4, kCFAllocatorMalloc);
        return texno;
    }
#endif

    // PNG loader
    // https://developer.apple.com/library/mac/documentation/GraphicsImaging/Conceptual/OpenGL-MacProgGuide/opengl_texturedata/opengl_texturedata.html

    CGImageSourceRef imagesource = CGImageSourceCreateWithURL((__bridge CFURLRef) [basename URLByAppendingPathExtension:@"png"], NULL);
    if (!imagesource)
        return 0;

    CGImageRef image = CGImageSourceCreateImageAtIndex(imagesource, 0, NULL);
    CFRelease(imagesource);
    if (!image)
        return 0;

    *data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    CGImageRelease(image);
    if (!*data)
    {
        return 0;
    }

#if DEBUG
    CGImageAlphaInfo alphainfo = CGImageGetAlphaInfo(image);
    CGBitmapInfo bitmapinfo = CGImageGetBitmapInfo(image);
    size_t bpp = CGImageGetBitsPerPixel(image);
    const UInt8 *pixdata = CFDataGetBytePtr(*data);
#endif

    GLuint texno;
    glGenTextures(1, &texno);
    glBindTexture(GL_TEXTURE_2D, texno);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, CGImageGetWidth(image), CGImageGetHeight(image), 0, GL_RGBA, GL_UNSIGNED_INT_8_8_8_8_REV, CFDataGetBytePtr(*data));
    ASSERT_GL;

    return texno;
}
