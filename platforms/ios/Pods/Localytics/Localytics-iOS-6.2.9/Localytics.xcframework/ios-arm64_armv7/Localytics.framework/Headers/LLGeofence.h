//
//  LLGeofence.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

#import <Localytics/LLRegion.h>

/**
 * A class representing a circular region
 */
@interface LLGeofence : LLRegion

/**
 * The Core Location circular region object associated with this region
 */
@property (nonatomic, copy, readonly, nonnull) CLCircularRegion *region;

@end
