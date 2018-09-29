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
static GLuint targets[kTexRoleCount];
static NSURL *filenames[kTexRoleCount];
#if APL
static CFDataRef data[kTexRoleCount];   // We're using GL_UNPACK_CLIENT_STORAGE_APPLE so need to retain the source bitmap data
#endif


GLuint BlankTex()
{
    static GLuint target;

    if (!target)
    {
        static const UInt8 color[4] = { 0xdf, 0xdf, 0xdf, 0xff };
        glGenTextures(1, &target);
        glBindTexture(GL_TEXTURE_2D, target);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, &color);
        ASSERT_GL;
    }
    return target;
}


GLuint LoadTex(TexRole role, CFURLRef objname, const char *texname)
{
    char *fixedname;
    if (role >= kTexRoleCount ||
        ! *texname ||
        !(fixedname = malloc(strlen(texname)+1)))
        return BlankTex();

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
    if (targets[role] &&
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

        if (!targets[role])
            glGenTextures(1, &targets[role]);
        else
            CFRelease(data[role]);
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
            GLsizei size = ((width+3)/4) * ((height+3)/4) * blocksize;
            glCompressedTexImage2D(GL_TEXTURE_2D, level, iformat, width, height, 0, size, ddsdata);
            ddsdata += size;
            if (! (width /= 2))  width  = 1;
            if (! (height /= 2)) height = 1;
        }
        ASSERT_GL;

        filenames[role] = ddsfilename;
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
            return BlankTex();

        if (!targets[role])
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
        ASSERT_GL;

        filenames[role] = ddsfilename;
        free(uncompressed);
        return targets[role];
    }
#endif

    // PNG loader
    // https://developer.apple.com/library/mac/documentation/GraphicsImaging/Conceptual/OpenGL-MacProgGuide/opengl_texturedata/opengl_texturedata.html
    // https://developer.apple.com/library/ios/samplecode/GLImageProcessing/Listings/Texture_m.html

    CGImageSourceRef imagesource = CGImageSourceCreateWithURL((__bridge CFURLRef) pngfilename, NULL);
    if (!imagesource)
        return BlankTex();

    CGImageRef image = CGImageSourceCreateImageAtIndex(imagesource, 0, NULL);
    CFRelease(imagesource);
    if (!image)
        return BlankTex();

    CFDataRef pngdata;
    GLsizei width = (GLsizei) CGImageGetWidth(image);
    GLsizei height = (GLsizei) CGImageGetHeight(image);
    CGColorSpaceRef colorspace = CGImageGetColorSpace(image);
    CGColorSpaceModel colormodel = CGColorSpaceGetModel(colorspace);
    size_t bpp = CGImageGetBitsPerPixel(image);
    if (colormodel == kCGColorSpaceModelIndexed && bpp == 8 && CGColorSpaceGetModel(CGColorSpaceGetBaseColorSpace(colorspace)) == kCGColorSpaceModelRGB)
    {
        // palletized FFS
        unsigned char palette[257 * 3];
        unsigned *unpacked = NULL;
        CFDataRef packed;
        if (!(unpacked = malloc(width * height * 4)) ||
            !(packed = CGDataProviderCopyData(CGImageGetDataProvider(image))))
        {
            free(unpacked);
            CGImageRelease(image);
            return BlankTex();
        }

        // convert to RGBA
        const unsigned char *packeddata = CFDataGetBytePtr(packed);
        CGColorSpaceGetColorTable(colorspace, palette);
        for (int i=0; i < width * height; i++)
            unpacked[i] = (* (unsigned*) (palette + (packeddata[i]*3))) | 0xff000000;

        CFRelease(packed);
        pngdata = CFDataCreateWithBytesNoCopy(NULL, (UInt8*) unpacked, width * height * 4, kCFAllocatorMalloc);
    }
    else if (colormodel != kCGColorSpaceModelRGB ||
             (bpp != 24 && bpp != 32) ||
             !(pngdata = CGDataProviderCopyData(CGImageGetDataProvider(image))))
    {
        NSLog(@"XPlaneObj: model:%d bpp:%zu %@", colormodel, bpp, pngfilename);
        CGImageRelease(image);
        return BlankTex();
    }
    CGImageRelease(image);

    if (!targets[role])
        glGenTextures(1, &targets[role]);
#if APL
    else
        CFRelease(data[role]);
#endif
    glBindTexture(GL_TEXTURE_2D, targets[role]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, bpp == 24 ? GL_RGB : GL_RGBA, GL_UNSIGNED_BYTE, CFDataGetBytePtr(pngdata));
    ASSERT_GL;

    filenames[role] = ddsfilename;
#if APL
    data[role] = pngdata;  // keep a copy of the data
#else
    CFRelease(pngdata);
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
