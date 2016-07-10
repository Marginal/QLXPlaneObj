#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#import "obj.h"

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file

   https://developer.apple.com/library/mac/documentation/UserExperience/Conceptual/Quicklook_Programming_Guide/Articles/QLImplementationOverview.html

   ----------------------------------------------------------------------------- */

extern "C" {

// Undocumented options
const CFStringRef kQLPreviewOptionModeKey = CFSTR("QLPreviewMode");

typedef NS_ENUM(NSInteger, QLPreviewMode)
{
    kQLPreviewNoMode		= 0,
    kQLPreviewGetInfoMode	= 1,	// File -> Get Info and Column view in Finder
    kQLPreviewPrefetchMode	= 2,	// Be ready for QuickLook (called for selected file in Finder's Cover Flow view)
    kQLPreviewUnknownMode	= 3,
    kQLPreviewSpotlightMode	= 4,	// Desktop Spotlight search popup bubble
    kQLPreviewQuicklookMode	= 5,	// File -> Quick Look in Finder (also qlmanage -p)
};


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

        CGSize size;
        if ([(NSNumber*)((__bridge NSDictionary*)options)[(__bridge NSString*)kQLPreviewOptionModeKey] intValue] == kQLPreviewQuicklookMode)
            size = CGSizeMake(800, 600);    // Standard QuickLook view - displayed at this size
        else
            size = CGSizeMake(512, 512);    // Some other context - caller will resize

        CGImageRef image = [obj newImageWithSize:render];
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
