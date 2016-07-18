#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#include "obj.h"

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

extern "C"
{

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
    @autoreleasepool {
#ifdef DEBUG
        NSLog(@"XPlaneOBJ UTI=%@ options=%@ size=%dx%d %@", contentTypeUTI, options, (int) maxSize.width, (int) maxSize.height, url);
#endif

        XPlaneOBJ *obj = [XPlaneOBJ objWithURL:url];
        if (!obj)
        {
            // Not an object that we recognise - try to pass on to other generators
            QLThumbnailRequestSetThumbnailWithURLRepresentation(thumbnail, url, contentTypeUTI, NULL, NULL);
            return kQLReturnNoError;
        }

        if (QLThumbnailRequestIsCancelled(thumbnail))
        {
            return kQLReturnNoError;
        }

        NSNumber *scaleFactor = ((__bridge NSDictionary *) options)[(NSString *) kQLThumbnailOptionScaleFactorKey];	// can be >1 on Retina displays

        // Render at double size so QuickLook will effectively antialias by resizing
        CGSize size = (scaleFactor.floatValue ?
                       CGSizeMake(maxSize.width * scaleFactor.floatValue * 2, maxSize.height * scaleFactor.floatValue * 2) :
                       CGSizeMake(maxSize.width * 2, maxSize.height * 2));

        CGImageRef image = [obj newImageWithSize:size];
        if (!image || QLThumbnailRequestIsCancelled(thumbnail))
        {
            if (image)
                CGImageRelease(image);
            return kQLReturnNoError;
        }

        /* Add an "OBJ" stamp if the thumbnail is not too small */
        NSDictionary *properties = (maxSize.height > 16 ?
                                    @{ (__bridge NSString *)kQLThumbnailPropertyExtensionKey: @"OBJ" } :
                                    NULL);
        QLThumbnailRequestSetImage(thumbnail, image, (__bridge CFDictionaryRef) properties);

        CGImageRelease(image);

        return kQLReturnNoError;
    }
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}

} // extern "C"
