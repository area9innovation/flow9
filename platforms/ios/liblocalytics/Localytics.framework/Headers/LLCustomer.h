//
//  LLCustomer.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

#import <Foundation/Foundation.h>

/**
 * A customer object builder used to set a customer's:
 * - id
 * - first name
 * - last name
 * - full name
 * - email address
 */
@interface LLCustomerBuilder : NSObject

/**
 * Builder setter for customer's id
 */
@property (nonatomic, strong, nullable) NSString* customerId;

/**
 * Builder setter for customer's first name
 */

@property (nonatomic, strong, nullable) NSString* firstName;
/**
 * Builder setter for customer's last name
 */

@property (nonatomic, strong, nullable) NSString* lastName;
/**
 * Builder setter for customer's full name
 */
@property (nonatomic, strong, nullable) NSString* fullName;

/**
 * Builder setter for customer's email address
 */
@property (nonatomic, strong, nullable) NSString* emailAddress;

@end


/**
 * A customer object. A customer can have:
 * - id
 * - first name
 * - last name
 * - full name
 * - email address
 */
@interface LLCustomer : NSObject

/**
 * Customer's id
 */
@property (nonatomic, strong, readonly, nullable) NSString* customerId;

/**
 * Customer's first name
 */
@property (nonatomic, strong, readonly, nullable) NSString* firstName;

/**
 * Customer's last name
 */
@property (nonatomic, strong, readonly, nullable) NSString* lastName;

/**
 * Customer's full name
 */
@property (nonatomic, strong, readonly, nullable) NSString* fullName;

/**
 * Customer's email address
 */
@property (nonatomic, strong, readonly, nullable) NSString* emailAddress;

/**
 * Constructor for a customer object using a customer builder
 */
+ (nullable instancetype)customerWithBlock:(nonnull void (^)(LLCustomerBuilder * __nonnull builder))block;

@end
