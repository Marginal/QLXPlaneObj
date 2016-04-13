//
//  revlib.h
//  QLXPlaneObj
//
//  Created by Jonathan Harris on 12/04/2016.
//
//

#ifndef revlib_h
#define revlib_h

@interface XPReverseLibrary : NSObject
{
    NSMutableDictionary *contents;
    NSMutableSet *seen;
    NSArray *stringsort;
}

- (id) init;
- (NSArray *)lookup:(NSString *)file;

@end


#endif /* revlib_h */
