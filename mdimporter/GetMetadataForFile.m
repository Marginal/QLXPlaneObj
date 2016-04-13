#import <Cocoa/Cocoa.h>

#import <CoreFoundation/CoreFoundation.h>
#import <CoreServices/CoreServices.h>
#import <ApplicationServices/ApplicationServices.h>

#import "revlib.h"

// https://developer.apple.com/library/mac/documentation/Carbon/Conceptual/MDImporters/Concepts/WritingAnImp.html


static NSString* kMDItemAlternateNames;
static XPReverseLibrary *revlib;

// Initialize the importer in GetMetadataForFile.c
void InitImporter(void)
{
    kMDItemAlternateNames = @"kMDItemAlternateNames";
    revlib = [[XPReverseLibrary alloc] init];
}

Boolean GetMetadataForFile(void* thisInterface,
                           CFMutableDictionaryRef attributes,
			   CFStringRef contentTypeUTI,
			   CFStringRef pathToFile)
{
    @autoreleasepool
    {
#ifdef DEBUG
        NSLog(@"XPlaneOBJ UTI=%@ %@", contentTypeUTI, pathToFile);
#endif
        NSArray *names = [revlib lookup:(__bridge NSString *)pathToFile];
        if (names)
        {
            NSMutableDictionary *attrs = (__bridge NSMutableDictionary *)attributes;   // Prefer to use Objective-C
            [attrs setValue:names forKey:(NSString *)kMDItemKeywords];
        }
    }
    return TRUE;
}
