#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#import "obj.h"

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file

   https://developer.apple.com/library/mac/documentation/UserExperience/Conceptual/Quicklook_Programming_Guide/Articles/QLImplementationOverview.html

   ----------------------------------------------------------------------------- */

extern "C"
{

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    @autoreleasepool {
#ifdef DEBUG
        NSLog(@"XPlaneOBJ UTI=%@ options=%@ %@", contentTypeUTI, options, url);
#endif

        XPlaneOBJ *obj = [XPlaneOBJ objWithURL:url];
        if (!obj)
        {
            // Not an object that we recognise - pass on to other generators
            QLPreviewRequestSetURLRepresentation(preview, url, contentTypeUTI, NULL);
            return kQLReturnNoError;
        }

        if (QLPreviewRequestIsCancelled(preview))
        {
            return kQLReturnNoError;
        }

        CGSize size = CGSizeMake(800, 600);
        CGImageRef image = [obj CreateImageWithSize:size];
        if (!image || QLPreviewRequestIsCancelled(preview))
        {
            if (image)
                CGImageRelease(image);
            return kQLReturnNoError;
        }

        CGContextRef context = QLPreviewRequestCreateContext(preview, CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image)), true, NULL);
        CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
        QLPreviewRequestFlushContext(preview, context);
        CGContextRelease(context);

        CGImageRelease(image);

        return kQLReturnNoError;
    }
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}

} // extern "C"
