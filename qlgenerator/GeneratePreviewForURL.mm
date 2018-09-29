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
    kQLPreviewCoverFlowMode	= 2,	// Be ready for QuickLook (called for selected file in Finder's Cover Flow view)
    kQLPreviewUnknownMode	= 3,
    kQLPreviewSpotlightMode	= 4,	// Desktop Spotlight search popup bubble
    kQLPreviewQuicklookMode	= 5,	// File -> Quick Look in Finder (also qlmanage -p)
    // From 10.13 High Sierra:
    kQLPreviewHSQuicklookMode	= 6,	// File -> Quick Look in Finder (also qlmanage -p)
    kQLPreviewHSSpotlightMode	= 9,	// Desktop Spotlight search context bubble
};


OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    CGImageRef image;
    CGSize size;
    CGSize render;

    @autoreleasepool
    {
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

        QLPreviewMode previewMode = [((__bridge NSDictionary *)options)[(__bridge NSString *) kQLPreviewOptionModeKey] intValue];
        if (previewMode == kQLPreviewQuicklookMode || previewMode == kQLPreviewHSQuicklookMode)
        {
            // Standard QuickLook view
            render = CGSizeMake(1600, 1200);        // render at this size
            size   = CGSizeMake( 800,  600);        // downscale / antalias to this size
        }
        else
        {
            // Some other context
            render = size = CGSizeMake(1024, 1024); // caller will downscale as necessary
        }

        image = [obj newImageWithSize:render];

        if (!image || QLPreviewRequestIsCancelled(preview))
        {
            if (image)
                CGImageRelease(image);
            return kQLReturnNoError;
        }
    }   // Free XPlaneOBJ before handing back to QuickLook

    CGContextRef context = QLPreviewRequestCreateContext(preview, size, true, NULL);
    CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height) , image);
    QLPreviewRequestFlushContext(preview, context);
    CGContextRelease(context);
    CGImageRelease(image);

    return kQLReturnNoError;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}

} // extern "C"
