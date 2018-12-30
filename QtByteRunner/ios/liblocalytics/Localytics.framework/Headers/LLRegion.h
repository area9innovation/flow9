//
//  LLRegion.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

/**
 * A base region class containing information relevant to all region types
 */
@interface LLRegion : NSObject

/**
 * The name of the region
 */
@property (nonatomic, copy, readonly, nullable) NSString *name;

/**
 * The attributes associated with the region
 */
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *,NSString *> *attributes;

/**
 * The Core Location region object associated with this region
 */
@property (nonatomic, copy, readonly, nonnull) CLRegion *region;

@end
