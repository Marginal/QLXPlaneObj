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
            // Not an object that we recognise - pass on to other generators
            QLThumbnailRequestSetImageAtURL(thumbnail, url, NULL);
            return kQLReturnNoError;
        }

        if (QLThumbnailRequestIsCancelled(thumbnail))
        {
            return kQLReturnNoError;
        }

        NSNumber *scaleFactor = ((__bridge NSDictionary *) options)[(NSString *) kQLThumbnailOptionScaleFactorKey];	// can be >1 on Retina displays
        CGSize size = scaleFactor.floatValue ? CGSizeMake(maxSize.width * scaleFactor.floatValue, maxSize.height * scaleFactor.floatValue) : CGSizeMake(maxSize.width, maxSize.height);

        CGImageRef image = [obj CreateImageWithSize:size];
        if (!image || QLThumbnailRequestIsCancelled(thumbnail))
        {
            if (image)
                CGImageRelease(image);
            return kQLReturnNoError;
        }

        /* Add an "OBJ" stamp if the thumbnail is not too small */
        NSDictionary *properties = (maxSize.height > 16 ?
                                    @{ @"OBJ": (__bridge NSString *) kQLThumbnailPropertyExtensionKey} :
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
