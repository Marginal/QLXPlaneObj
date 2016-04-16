//
//  revlib.m
//  QLXPlaneObj
//
//  Created by Jonathan Harris on 12/04/2016.
//
//

#import <Foundation/Foundation.h>

#include <string.h>
#import "revlib.h"


static char *trim(char *c)
{
    if (!c)
        return NULL;
    while (*c && (*c == ' ' || *c == '\t'))
        c++;

    char *r = c;
    while (*r)
        if (*r == ' ' || *r == '\t')
            *r = '\0';
        else
            r++;
    return c;
}


@interface XPReverseLibrary ()
- (void) scanForLibrary:(NSString *)path;
- (void) readLibrary:(NSData *)data base:(NSString *)path;
@end


@implementation XPReverseLibrary
- (id) init
{
    if (!(self = [super init]) ||
        !(contents   = [[NSMutableDictionary alloc] init]) ||
        !(seen       = [[NSMutableSet alloc] init]) ||
        !(stringsort = @[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]))
        return nil;

    return self;
}

// Find virtual names for a physical file
- (NSArray *)lookup:(NSString *)path
{
    NSString *key = [path lowercaseString];
    NSSet *names = contents[key];
    if (names)
        return [names sortedArrayUsingDescriptors:stringsort];

    [self scanForLibrary:path];

    // Try again
    return [contents[key] sortedArrayUsingDescriptors:stringsort];
}

// find a parent library
- (void) scanForLibrary:(NSString *)path;
{
    NSString *dir = [[path lastPathComponent] lowercaseString];
    if ([dir isEqualToString:@"/"] || [dir isEqualToString:@"custom scenery"] || [dir isEqualToString:@"default scenery"])
        return; // stop at top of X-Plane's custom and default scenery directories

    NSString *base = [path stringByDeletingLastPathComponent];
    NSString *libname = [base stringByAppendingPathComponent:@"library.txt"];
    if (!libname || [seen containsObject:libname])
        return; // already processed this library this worker process

    NSData *library = [NSData dataWithContentsOfFile:libname];
    if (library)
    {
        [seen addObject:libname];
        [self readLibrary:library base:base];
    }
    else
        [self scanForLibrary:base];
}

- (void) readLibrary:(NSData *)data base:(NSString *)dir
{
    static const char *CRLF = "\r\n";
    static const char *WHSP = " \t";

    NSString *base = [dir lowercaseString];
    char *line, *brkline;

    line = trim(strtok_r((char *)[data bytes], CRLF, &brkline));
    if (!line || (strcmp(line, "I") && strcmp(line, "A")))
        return;
    line = trim(strtok_r(NULL, CRLF, &brkline));
    if (!line || strcmp(line, "800"))
        return;
    line = trim(strtok_r(NULL, CRLF, &brkline));
    if (!line || strcmp(line, "LIBRARY"))
        return;

    while ((line = strtok_r(NULL, CRLF, &brkline)))
    {
        char *token, *brktoken, *name, *file;

        if (((token = strtok_r(line, WHSP, &brktoken))) &&
            (
             ((!strcmp(token, "EXPORT") || !strcmp(token, "EXPORT_EXTEND")) &&
              ((name = strtok_r(NULL, WHSP, &brktoken))) &&
              ((file = strtok_r(NULL, WHSP, &brktoken))))
             ||
             (!strcmp(token, "EXPORT_RATIO") &&
              ((name = strtok_r(NULL, WHSP, &brktoken))) &&    // ratio
              ((name = strtok_r(NULL, WHSP, &brktoken))) &&
              ((file = strtok_r(NULL, WHSP, &brktoken))))
             ))
        {
            for (char *c=file; *c; c++)
                if (*c=='\\' || *c==':')
                    *c = '/';
            NSString *key = [base stringByAppendingPathComponent:[[NSString stringWithUTF8String:file] lowercaseString]];
            NSMutableSet *entry = contents[key];
            if (!entry)
                entry = [[NSMutableSet alloc] init];
                [contents setValue:entry forKey:key];   // required ?
            [entry addObject:[NSString stringWithUTF8String:name]];
        }
    }
}

@end
