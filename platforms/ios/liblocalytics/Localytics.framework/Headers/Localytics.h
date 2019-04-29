//
//  Localytics.h
//  Copyright (C) 2017 Char Software Inc., DBA Localytics
//
//  This code is provided under the Localytics Modified BSD License.
//  A copy of this license has been distributed in a file called LICENSE
//  with this source code.
//
// Please visit www.localytics.com for more information.
//

#import <JavaScriptCore/JavaScriptCore.h>
#import <CoreLocation/CoreLocation.h>
#import <Localytics/LLCustomer.h>
#import <Localytics/LocalyticsTypes.h>
/*
 Analytics Delegate
*/
@protocol LLAnalyticsDelegate;

#if !TARGET_OS_TV

#import <Localytics/LLCampaignBase.h>
#import <Localytics/LLWebViewCampaign.h>
#import <Localytics/LLInboxCampaign.h>
#import <Localytics/LLPlacesCampaign.h>
#import <Localytics/LLInAppCampaign.h>
#import <Localytics/LLRegion.h>
#import <Localytics/LLGeofence.h>
#import <Localytics/LLInboxViewController.h>
#import <Localytics/LLInboxDetailViewController.h>
#import <Localytics/LLInAppConfiguration.h>

@protocol LLMessagingDelegate;
@protocol LLCallToActionDelegate;
@protocol LLLocationDelegate;

@class UNMutableNotificationContent;
#define LOCALYTICS_LIBRARY_VERSION      @"5.2.0" //iOS version

#else

#define LOCALYTICS_LIBRARY_VERSION      @"1.0.2" //tvOS version

#endif

@protocol Localytics <JSExport>

#pragma mark - SDK Integration
/** ---------------------------------------------------------------------------------------
 * @name Localytics SDK Integration
 *  ---------------------------------------------------------------------------------------
 */

/** Auto-integrates the Localytic SDK into the application.
 
 Use this method to automatically integrate the Localytics SDK in a single line of code. Automatic
 integration is accomplished by proxying the AppDelegate and "inserting" a Localytics AppDelegate
 behind the applications AppDelegate. The proxy will first call the applications AppDelegate and
 then call the Localytics AppDelegate.
 
 @param appKey The unique key for each application generated at www.localytics.com
 @param localyticsOptions A dictionary containing intervals for uploading data based on connection type.
 If set to nil, defaults will be used.
 @param launchOptions The launchOptions provided by application:DidFinishLaunchingWithOptions:
 
 @see LOCALYTICS_WIFI_UPLOAD_INTERVAL_SECONDS
 @see LOCALYTICS_GREAT_NETWORK_UPLOAD_INTERVAL_SECONDS
 @see LOCALYTICS_DECENT_NETWORK_UPLOAD_INTERVAL_SECONDS
 @see LOCALYTICS_BAD_NETWORK_UPLOAD_INTERVAL_SECONDS

 @Version SDK5.0
 */
+ (void)autoIntegrate:(nonnull NSString *)appKey withLocalyticsOptions:(nullable NSDictionary *)localyticsOptions launchOptions:(nullable NSDictionary *)launchOptions;

/** Manually integrate the Localytic SDK into the application.
 
 Use this method to manually integrate the Localytics SDK. The developer still has to make sure to
 open and close the Localytics session as well as call upload to ensure data is uploaded to
 Localytics
 
 @param appKey The unique key for each application generated at www.localytics.com
 @param localyticsOptions A dictionary containing intervals for uploading data based on connection type.
 If set to nil, defaults will be used.
 @see openSession
 @see closeSession
 @see upload
 @see LOCALYTICS_WIFI_UPLOAD_INTERVAL_SECONDS
 @see LOCALYTICS_GREAT_NETWORK_UPLOAD_INTERVAL_SECONDS
 @see LOCALYTICS_DECENT_NETWORK_UPLOAD_INTERVAL_SECONDS
 @see LOCALYTICS_BAD_NETWORK_UPLOAD_INTERVAL_SECONDS

 @Version SDK5.0
 */
+ (void)integrate:(nonnull NSString *)appKey withLocalyticsOptions:(nullable NSDictionary *)localyticsOptions;

/** Opens the Localytics session.
 The session time as presented on the website is the time between <code>open</code> and the
 final <code>close</code> so it is recommended to open the session as early as possible, and close
 it at the last moment. It is recommended that this call be placed in <code>applicationDidBecomeActive</code>.
 <br>
 If for any reason this is called more than once every subsequent open call will be ignored.
 
 Resumes the Localytics session.  When the App enters the background, the session is
 closed and the time of closing is recorded.  When the app returns to the foreground, the session
 is resumed.  If the time since closing is greater than BACKGROUND_SESSION_TIMEOUT, (15 seconds
 by default) a new session is created, and uploading is triggered.  Otherwise, the previous session
 is reopened.

 * @Version SDK3.0
 */
+ (void)openSession;

/** Closes the Localytics session.  This should be called in
 <code>applicationWillResignActive</code>.
 <br>
 If close is not called, the session will still be uploaded but no
 events will be processed and the session time will not appear. This is
 because the session is not yet closed so it should not be used in
 comparison with sessions which are closed.

 @Version SDK3.0
 */
+ (void)closeSession;

/** Creates a low priority thread which uploads any Localytics data already stored
 on the device.  This should be done early in the process life in order to
 guarantee as much time as possible for slow connections to complete.  It is also reasonable
 to upload again when the application is exiting because if the upload is cancelled the data
 will just get uploaded the next time the app comes up.

 @Version SDK3.0
 */
+ (void)upload;

/**
 Halt the uploading of Analytics and Profiles data to the Localytics servers.
 Re-enabling the upload of data will cause an immediate upload.
 
 @Version SDK5.1
 @param pause if set to true, all data uploading will be halted.  If false, data uploading will resume as normal.
 */

+ (void)pauseDataUploading:(BOOL)pause;

#pragma mark - Event Tagging
/** ---------------------------------------------------------------------------------------
 * @name Event Tagging
 *  ---------------------------------------------------------------------------------------
 */

/** Tag an event
 @param eventName The name of the event which occurred.
 @see tagEvent:attributes:customerValueIncrease:

 @Version SDK3.0
 */
+ (void)tagEvent:(nonnull NSString *)eventName;

/** Tag an event with attributes
 @param eventName The name of the event which occurred.
 @param attributes An object/hash/dictionary of key-value pairs, contains
 contextual data specific to the event.
 @see tagEvent:attributes:customerValueIncrease:

 @Version SDK3.0
 */
+ (void)tagEvent:(nonnull NSString *)eventName attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes;

/** Allows a session to tag a particular event as having occurred.  For
 example, if a view has three buttons, it might make sense to tag
 each button click with the name of the button which was clicked.
 For another example, in a game with many levels it might be valuable
 to create a new tag every time the user gets to a new level in order
 to determine how far the average user is progressing in the game.
 <br>
 <strong>Tagging Best Practices</strong>
 <ul>
 <li>DO NOT use tags to record personally identifiable information.</li>
 <li>The best way to use tags is to create all the tag strings as predefined
 constants and only use those.  This is more efficient and removes the risk of
 collecting personal information.</li>
 <li>Do not set tags inside loops or any other place which gets called
 frequently.  This can cause a lot of data to be stored and uploaded.</li>
 </ul>
 <br>
 See the tagging guide at: http://docs.localytics.com/dev/ios.html#events-ios
 @param eventName The name of the event which occurred.
 @param attributes (Optional) An object/hash/dictionary of key-value pairs, contains
 contextual data specific to the event.
 @param customerValueIncrease (Optional) Numeric value, added to customer lifetime value.
 Integer expected. Try to use lowest possible unit, such as cents for US currency.

 @Version SDK3.0
 */
+ (void)tagEvent:(nonnull NSString *)eventName attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes customerValueIncrease:(nullable NSNumber *)customerValueIncrease;

#pragma mark - Standard Event Tagging
/** ---------------------------------------------------------------------------------------
 * @name Standard Event Tagging
 *  ---------------------------------------------------------------------------------------
 */

/**
 * A standard event to tag a single item purchase event (after the action has occurred)
 *
 * @param itemName      The name of the item purchased (optional, can be null)
 * @param itemId        A unique identifier of the item being purchased, such as a SKU (optional, can be null)
 * @param itemType      The type of item (optional, can be null)
 * @param itemPrice     The price of the item (optional, can be null). Will be added to customer lifetime value. Try to use lowest possible unit, such as cents for US currency.
 * @param attributes    Any additional attributes to attach to this event (optional, can be null)

 * @Version SDK4.0
 */
+ (void)tagPurchased:(nullable NSString *)itemName itemId:(nullable NSString *)itemId itemType:(nullable NSString *)itemType itemPrice:(nullable NSNumber *)itemPrice attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes;

/**
 * A standard event to tag the addition of a single item to a cart (after the action has occurred)
 *
 * @param itemName      The name of the item purchased (optional, can be null)
 * @param itemId        A unique identifier of the item being purchased, such as a SKU (optional, can be null)
 * @param itemType      The type of item (optional, can be null)
 * @param itemPrice     The price of the item (optional, can be null). Will NOT be added to customer lifetime value.
 * @param attributes    Any additional attributes to attach to this event (optional, can be null)
 
 * @Version SDK4.0
 */
+ (void)tagAddedToCart:(nullable NSString *)itemName itemId:(nullable NSString *)itemId itemType:(nullable NSString *)itemType itemPrice:(nullable NSNumber *)itemPrice attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes;

/**
 * A standard event to tag the start of the checkout process (after the action has occurred)
 *
 * @param totalPrice    The total price of all the items in the cart (optional, can be null). Will NOT be added to customer lifetime value.
 * @param itemCount     Total count of items in the cart (optional, can be null)
 * @param attributes    Any additional attributes to attach to this event (optional, can be null)

 * @Version SDK4.0
 */
+ (void)tagStartedCheckout:(nullable NSNumber *)totalPrice itemCount:(nullable NSNumber *)itemCount attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes;

/**
 * A standard event to tag the conclusions of the checkout process (after the action has occurred)
 *
 * @param totalPrice    The total price of all the items in the cart (optional, can be null). Will be added to customer lifetime value. Try to use lowest possible unit, such as cents for US currency.
 * @param itemCount     Total count of items in the cart (optional, can be null)
 * @param attributes    Any additional attributes to attach to this event (optional, can be null)

 * @Version SDK4.0
 */
+ (void)tagCompletedCheckout:(nullable NSNumber *)totalPrice itemCount:(nullable NSNumber *)itemCount attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes;

/**
 * A standard event to tag the viewing of content (after the action has occurred)
 *
 * @param contentName   The name of the content being viewed (such as article name) (optional, can be null)
 * @param contentId     A unique identifier of the content being viewed (optional, can be null)
 * @param contentType   The type of content (optional, can be null)
 * @param attributes    Any additional attributes to attach to this event (optional, can be null)

 * @Version SDK4.0
 */
+ (void)tagContentViewed:(nullable NSString *)contentName contentId:(nullable NSString *)contentId contentType:(nullable NSString *)contentType attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes;

/**
 * A standard event to tag a search event (after the action has occurred)
 *
 * @param queryText     The query user for the search (optional, can be null)
 * @param contentType   The type of content (optional, can be null)
 * @param resultCount   The number of results returned by the query (optional, can be null)
 * @param attributes    Any additional attributes to attach to this event (optional, can be null)

 * @Version SDK4.0
 */
+ (void)tagSearched:(nullable NSString *)queryText contentType:(nullable NSString *)contentType resultCount:(nullable NSNumber *)resultCount attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes;

/**
 * A standard event to tag a share event (after the action has occurred)
 *
 * @param contentName   The name of the content being viewed (such as article name) (optional, can be null)
 * @param contentId     A unique identifier of the content being viewed (optional, can be null)
 * @param contentType   The type of content (optional, can be null)
 * @param methodName    The method by which the content was shared such as Twitter, Facebook, Native (optional, can be null)
 * @param attributes    Any additional attributes to attach to this event (optional, can be null)

 * @Version SDK4.0
 */
+ (void)tagShared:(nullable NSString *)contentName contentId:(nullable NSString *)contentId contentType:(nullable NSString *)contentType methodName:(nullable NSString *)methodName attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes;

/**
 * A standard event to tag the rating of content (after the action has occurred)
 *
 * @param contentName   The name of the content being viewed (such as article name) (optional, can be null)
 * @param contentId     A unique identifier of the content being viewed (optional, can be null)
 * @param contentType   The type of content (optional, can be null)
 * @param rating        A rating of the content (optional, can be null)
 * @param attributes    Any additional attributes to attach to this event (optional, can be null)

 * @Version SDK4.0
 */
+ (void)tagContentRated:(nullable NSString *)contentName contentId:(nullable NSString *)contentId contentType:(nullable NSString *)contentType rating:(nullable NSNumber *)rating attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes;

/**
 * A standard event to tag the registration of a user (after the action has occurred)
 *
 * @param customer      An object providing information about the customer that registered (optional, can be null)
 * @param methodName    The method by which the user was registered such as Twitter, Facebook, Native (optional, can be null)
 * @param attributes    Any additional attributes to attach to this event (optional, can be null)

 * @Version SDK4.0
 */
+ (void)tagCustomerRegistered:(nullable LLCustomer *)customer methodName:(nullable NSString *)methodName attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes;

/**
 * A standard event to tag the logging in of a user (after the action has occurred)
 *
 * @param customer      An object providing information about the customer that logged in (optional, can be null)
 * @param methodName    The method by which the user was logged in such as Twitter, Facebook, Native (optional, can be null)
 * @param attributes    Any additional attributes to attach to this event (optional, can be null)

 * @Version SDK4.0
 */
+ (void)tagCustomerLoggedIn:(nullable LLCustomer *)customer methodName:(nullable NSString *)methodName attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes;

/**
 * A standard event to tag the logging out of a user (after the action has occurred)
 *
 * @param attributes    Any additional attributes to attach to this event (optional, can be null)

 * @Version SDK4.0
 */
+ (void)tagCustomerLoggedOut:(nullable NSDictionary<NSString *, NSString *> *)attributes;

/**
 * A standard event to tag the invitation of a user (after the action has occured)
 *
 * @param methodName    The method by which the user was invited such as Twitter, Facebook, Native (optional, can be null)
 * @param attributes    Any additional attributes to attach to this event (optional, can be null)

 * @Version SDK4.0
 */
+ (void)tagInvited:(nullable NSString *)methodName attributes:(nullable NSDictionary<NSString *, NSString *> *)attributes;

#pragma mark - Tag Screen Method

/** Allows tagging the flow of screens encountered during the session.
 @param screenName The name of the screen

 @Version SDK3.0
 */
+ (void)tagScreen:(nonnull NSString *)screenName;

#pragma mark - Custom Dimensions
/** ---------------------------------------------------------------------------------------
 * @name Custom Dimensions
 *  ---------------------------------------------------------------------------------------
 */

/** Sets the value of a custom dimension. Custom dimensions are dimensions
 which contain user defined data unlike the predefined dimensions such as carrier, model, and country.
 Once a value for a custom dimension is set, the device it was set on will continue to upload that value
 until the value is changed. To clear a value pass nil as the value.
 The proper use of custom dimensions involves defining a dimension with less than ten distinct possible
 values and assigning it to one of the four available custom dimensions. Once assigned this definition should
 never be changed without changing the App Key otherwise old installs of the application will pollute new data.
 @param value The value to set the custom dimension to
 @param dimension The dimension to set the value of
 @see valueForCustomDimension:

 @Version SDK3.0
 */
+ (void)setValue:(nullable NSString *)value forCustomDimension:(NSUInteger)dimension;

/** Gets the custom value for a given dimension. Avoid calling this on the main thread, as it
 may take some time for all pending database execution.
 @param dimension The custom dimension to return a value for
 @return The current value for the given custom dimension
 @see setValue:forCustomDimension:

 @Version SDK3.0
 */
+ (nullable NSString *)valueForCustomDimension:(NSUInteger)dimension;

#pragma mark - Identifiers
/** ---------------------------------------------------------------------------------------
 * @name Identifiers
 *  ---------------------------------------------------------------------------------------
 */

/** Sets the value of a custom identifier. Identifiers are a form of key/value storage
 which contain custom user data. Identifiers might include things like email addresses,
 customer IDs, twitter handles, and facebook IDs. Once a value is set, the device it was set
 on will continue to upload that value until the value is changed.
 To delete a property, pass in nil as the value.
 @param value The value to set the identifier to. To delete a propert set the value to nil
 @param identifier The name of the identifier to have it's value set
 @see valueForIdentifier:

 @Version SDK3.0
 */
+ (void)setValue:(nullable NSString *)value forIdentifier:(nonnull NSString *)identifier;

/** Gets the identifier value for a given identifier. Avoid calling this on the main thread, as it
 may take some time for all pending database execution.
 @param identifier The identifier to return a value for
 @return The current value for the given identifier
 @see setValue:forCustomDimension:

 @Version SDK3.0
 */
+ (nullable NSString *)valueForIdentifier:(nonnull NSString *)identifier;

/** Set the identifier for the customer. This value is used when setting profile attributes,
 targeting users for push and mapping data exported from Localytics to a user.
 @param customerId The value to set the customer identifier to

 @Version SDK3.0
 */
+ (void)setCustomerId:(nullable NSString *)customerId;

/** Set the identifier for the customer. This value is used when setting profile attributes,
 targeting users for push and mapping data exported from Localytics to a user.
 Additionally this will set the appropriate data collection state for the the user.
 @param customerId The value to set the customer identifier to
 @param optedOut If the user has consented to data collection
 @see setCustomerId:
 @see setPrivacyOptedOut:
 
 @Version SDK5.1
 */
+ (void)setCustomerId:(nullable NSString *)customerId privacyOptedOut:(BOOL)optedOut;

/** Gets the customer id. Avoid calling this on the main thread, as it
 may take some time for all pending database execution.
 @return The current value for customer id

 @Version SDK3.1.0
 */
+ (nullable NSString *)customerId;


#pragma mark - Profile
/** ---------------------------------------------------------------------------------------
 * @name Profile
 *  ---------------------------------------------------------------------------------------
 */

/** Sets the value of a profile attribute.
 @param value The value to set the profile attribute to. value can be one of the following: NSString,
 NSNumber(long & int), NSDate, NSArray of Strings, NSArray of NSNumbers(long & int), NSArray of Date,
 nil. Passing in a 'nil' value will result in that attribute being deleted from the profile
 @param attribute The name of the profile attribute to be set
 @param scope The scope of the attribute governs the visability of the profile attribute (application
 only or organization wide)

 @Version SDK3.0
 */
+ (void)setValue:(nonnull id)value forProfileAttribute:(nonnull NSString *)attribute withScope:(LLProfileScope)scope;

/** Sets the value of a profile attribute (scope: Application).
 @param value The value to set the profile attribute to. value can be one of the following: NSString,
 NSNumber(long & int), NSDate, NSArray of Strings, NSArray of NSNumbers(long & int), NSArray of Date,
 nil. Passing in a 'nil' value will result in that attribute being deleted from the profile
 @param attribute The name of the profile attribute to be set

 @Version SDK3.0
 */
+ (void)setValue:(nonnull id)value forProfileAttribute:(nonnull NSString *)attribute;

/** Adds values to a profile attribute that is a set
 @param values The value to be added to the profile attributes set.
 @param attribute The name of the profile attribute to have it's set modified
 @param scope The scope of the attribute governs the visability of the profile attribute (application
 only or organization wide)

 @Version SDK3.0
 */
+ (void)addValues:(nonnull NSArray *)values toSetForProfileAttribute:(nonnull NSString *)attribute withScope:(LLProfileScope)scope;

/** Adds values to a profile attribute that is a set (scope: Application).
 @param values The value to be added to the profile attributes set
 @param attribute The name of the profile attribute to have it's set modified

 @Version SDK3.0
 */
+ (void)addValues:(nonnull NSArray *)values toSetForProfileAttribute:(nonnull NSString *)attribute;

/** Removes values from a profile attribute that is a set
 @param values The value to be removed from the profile attributes set
 @param attribute The name of the profile attribute to have it's set modified
 @param scope The scope of the attribute governs the visability of the profile attribute (application
 only or organization wide)

 @Version SDK3.0
 */
+ (void)removeValues:(nonnull NSArray *)values fromSetForProfileAttribute:(nonnull NSString *)attribute withScope:(LLProfileScope)scope;

/** Removes values from a profile attribute that is a set (scope: Application).
 @param values The value to be removed from the profile attributes set
 @param attribute The name of the profile attribute to have it's set modified

 @Version SDK3.0
 */
+ (void)removeValues:(nonnull NSArray *)values fromSetForProfileAttribute:(nonnull NSString *)attribute;

/** Increment the value of a profile attribute.
 @param value An NSInteger to be added to an existing profile attribute value.
 @param attribute The name of the profile attribute to have it's value incremented
 @param scope The scope of the attribute governs the visability of the profile attribute (application
 only or organization wide)

 @Version SDK3.0
 */
+ (void)incrementValueBy:(NSInteger)value forProfileAttribute:(nonnull NSString *)attribute withScope:(LLProfileScope)scope;

/** Increment the value of a profile attribute (scope: Application).
 @param value An NSInteger to be added to an existing profile attribute value.
 @param attribute The name of the profile attribute to have it's value incremented

 @Version SDK3.0
 */
+ (void)incrementValueBy:(NSInteger)value forProfileAttribute:(nonnull NSString *)attribute;

/** Decrement the value of a profile attribute.
 @param value An NSInteger to be subtracted from an existing profile attribute value.
 @param attribute The name of the profile attribute to have it's value decremented
 @param scope The scope of the attribute governs the visability of the profile attribute (application
 only or organization wide)

 @Version SDK3.0
 */
+ (void)decrementValueBy:(NSInteger)value forProfileAttribute:(nonnull NSString *)attribute withScope:(LLProfileScope)scope;

/** Decrement the value of a profile attribute (scope: Application).
 @param value An NSInteger to be subtracted from an existing profile attribute value.
 @param attribute The name of the profile attribute to have it's value decremented

 @Version SDK3.0
 */
+ (void)decrementValueBy:(NSInteger)value forProfileAttribute:(nonnull NSString *)attribute;

/** Delete a profile attribute
 @param attribute The name of the attribute to be deleted
 @param scope The scope of the attribute governs the visability of the profile attribute (application
 only or organization wide)

 @Version SDK3.0
 */
+ (void)deleteProfileAttribute:(nonnull NSString *)attribute withScope:(LLProfileScope)scope;

/** Delete a profile attribute (scope: Application)
 @param attribute The name of the attribute to be deleted

 @Version SDK3.0
 */
+ (void)deleteProfileAttribute:(nonnull NSString *)attribute;

/** Convenience method to set a customer's email as both a profile attribute and
 as a customer identifier (scope: Organization)
 @param email Customer's email

 @Version SDK3.3.0
 */
+ (void)setCustomerEmail:(nullable NSString *)email;

/** Convenience method to set a customer's first name as both a profile attribute and
 as a customer identifier (scope: Organization)
 @param firstName Customer's first name

 @Version SDK3.3.0
 */
+ (void)setCustomerFirstName:(nullable NSString *)firstName;

/** Convenience method to set a customer's last name as both a profile attribute and
 as a customer identifier (scope: Organization)
 @param lastName Customer's last name

 @Version SDK3.3.0
 */
+ (void)setCustomerLastName:(nullable NSString *)lastName;

/** Convenience method to set a customer's full name as both a profile attribute and
 as a customer identifier (scope: Organization)
 @param fullName Customer's full name

 @Version SDK3.3.0
 */
+ (void)setCustomerFullName:(nullable NSString *)fullName;


#pragma mark - Developer Options
/** ---------------------------------------------------------------------------------------
 * @name Developer Options
 *  ---------------------------------------------------------------------------------------
 */

/**
 * Customize the behavior of the SDK by setting custom values for various options.
 * In each entry, the key specifies the option to modify, and the value specifies what value
 * to set the option to. Options can be restored to default by passing in a value of NSNull,
 * or an empty string for values with type NSString.
 * @param options The dictionary of options and values to modify

 * @Version SDK4.0
 */
+ (void)setOptions:(nullable NSDictionary<NSString *, NSObject *> *)options;

/** Returns whether the Localytics SDK is set to emit logging information
 @return YES if logging is enabled, NO otherwise

 @Version SDK3.0
 */
+ (BOOL)isLoggingEnabled;

/** Set whether Localytics SDK should emit logging information. By default the Localytics SDK
 is set to not to emit logging information. It is recommended that you only enable logging
 for debugging purposes.
 @param loggingEnabled Set to YES to enable logging or NO to disable it

 @Version SDK3.0
 */
+ (void)setLoggingEnabled:(BOOL)loggingEnabled;

/** Tell the Localytics SDK to keep a copy of all logs in a file on disk.
 It is recommended that you only enable logging for debugging purposes.

 @Version SDK5.0
 */
+ (void)redirectLoggingToDisk;

/** Returns whether or not the application will collect user data.
 @return YES if the user is opted out, NO otherwise. Default is NO
 @see setOptedOut:

 @Version SDK3.0
 */
+ (BOOL)isOptedOut;

/** Allows the application to control whether or not it will collect user data.
 Even if this call is used, it is necessary to continue calling upload().  No new data will be
 collected, so nothing new will be uploaded but it is necessary to upload an event telling the
 server this user has opted out.
 @param optedOut YES if the user is opted out, NO otherwise.
 @see isOptedOut

 @Version SDK3.0
 */
+ (void)setOptedOut:(BOOL)optedOut;

/** Returns whether or not the application will collect user data.
 @return YES if the user is opted out, NO otherwise. Default is NO
 @see setPrivacyOptedOut:
 
 @Version SDK5.1
 */
+ (BOOL)isPrivacyOptedOut;

/** Sets the Localytics opt-out state for this application. This call is not necessary and is provided for people who wish to
 allow their users the ability to opt out of data collection. It can be called at any time. Passing true causes all further
 data collection to stop, and a profile attribute will be set causing a deletion of data request to be made for Localytics
 in line with the GDPR standard.
 There are very serious implications to the quality of your data when providing an opt out option. For example, users who
 have opted out will appear as never returning, causing your new/returning chart to skew. <br>
 As a side effect of protecting a user's data, the SDK will internally ensure that ADID's are
 no longer appended to the url's of In-App and Inbox call to action links.
 @param optedOut YES if the user is opted out, NO otherwise.
 @see isPrivacyOptedOut
 
 @Version SDK5.1
 */
+ (void)setPrivacyOptedOut:(BOOL)optedOut;

/** Returns the install id
 @return the install id as an NSString

 @Version SDK3.0
 */
+ (nullable NSString *)installId;

/** Returns the version of the Localytics SDK
 @return the version of the Localytics SDK as an NSString

 @Version SDK3.0
 */
+ (nonnull NSString *)libraryVersion;

/** Returns the app key currently set in Localytics
 @return the app key currently set in Localytics as an NSString

 @Version SDK3.0
 */
+ (nullable NSString *)appKey;

/** Returns whether the Localytics SDK is currently in test mode or not. When in test mode
 a small Localytics tab will appear on the left side of the screen which enables a developer
 to see/test all the campaigns currently available to this customer.
 @return YES if test mode is enabled, NO otherwise

 @Version SDK3.0
 */
+ (BOOL)isTestModeEnabled;

/** Set whether Localytics SDK should enter test mode or not. When set to YES the a small
 Localytics tab will appear on the left side of the screen, enabling a developer to see/test
 all campaigns currently available to this customer.
 Setting testModeEnabled to NO will cause Localytics to exit test mode, if it's currently
 in it.
 @param enabled Set to YES to enable test mode, NO to disable test mode

 @Version SDK4.0
 */
+ (void)setTestModeEnabled:(BOOL)enabled;


#pragma mark - Analytics Delegate
/** ---------------------------------------------------------------------------------------
 * @name Analytics Delegate
 *  ---------------------------------------------------------------------------------------
 */

/** Set an Analytics delegate
 @param delegate An object implementing the LLAnalyticsDelegate protocol.
 @see LLAnalyticsDelegate

 @Version SDK3.0
 */
+ (void)setAnalyticsDelegate:(nullable id<LLAnalyticsDelegate>)delegate;

/** Stores the user's location.  This will be used in all event and session calls.
 If your application has already collected the user's location, it may be passed to Localytics
 via this function.  This will cause all events and the session close to include the location
 information.  It is not required that you call this function.
 @param location The user's location.

 @Version SDK3.0
 */
+ (void)setLocation:(CLLocationCoordinate2D)location;

#if !TARGET_OS_TV

#pragma mark - Push
/** ---------------------------------------------------------------------------------------
 * @name Push
 *  ---------------------------------------------------------------------------------------
 */

/** Returns the device's APNS token if one has been set via setPushToken: previously.
 @return The device's APNS token if one has been set otherwise nil
 @see setPushToken:

 @Version SDK3.0
 */
+ (nullable NSString *)pushToken;

/** Stores the device's APNS token. This will be used in all event and session calls.
 @param pushToken The devices APNS token returned by application:didRegisterForRemoteNotificationsWithDeviceToken:
 @see pushToken

 @Version SDK3.0
 */
+ (void)setPushToken:(nullable NSData *)pushToken;

/** Used to record performance data for notifications
 @param notificationInfo The dictionary from either didFinishLaunchingWithOptions, didReceiveRemoteNotification,
 or didReceiveLocalNotification should be passed on to this method

 @Version SDK4.0
 */
+ (void)handleNotification:(nonnull NSDictionary *)notificationInfo;

/** Used to record performance data for notifications with action identifiers
 @param notificationInfo The dictionary from either didFinishLaunchingWithOptions, didReceiveRemoteNotification,
 or didReceiveLocalNotification should be passed on to this method
 @param identifier The specific notification action associated with the opened push notification.

 @Version SDK4.4.0
 */
+ (void)handleNotification:(nonnull NSDictionary *)notificationInfo withActionIdentifier:(nullable NSString *)identifier;

/** Use to record performance data for notifications when using UNUserNotificationCenterDelegate
 @param userInfo The UNNotificationResponse's userInfo retrieved by calling response.notification.request.content.userInfo

 @Version SDK4.1.0
 */
+ (void)didReceiveNotificationResponseWithUserInfo:(nonnull NSDictionary *)userInfo;

/** Use to record performance data for notifications when using UNUserNotificationCenterDelegate and a specific notification action was selected.
 @param userInfo The UNNotificationResponse's userInfo retrieved by calling response.notification.request.content.userInfo
 @param identifier The UNNotificationResponse's actionIdentifier retrieved by calling response.actionIdentifier

 @Version SDK4.4.0
 */
+ (void)didReceiveNotificationResponseWithUserInfo:(nonnull NSDictionary *)userInfo andActionIdentifier:(nullable NSString *)identifier;

/** Used to notify the Localytics SDK that notification settings have changed

 * @Version SDK5.0
 */
+ (void)didRegisterUserNotificationSettings;

/** Used to notify the Localytics SDK that user notification authorization has changed

 * @Version SDK4.1.0
 */
+ (void)didRequestUserNotificationAuthorizationWithOptions:(NSUInteger)options granted:(BOOL)granted;

#pragma mark - In-App Message
/** ---------------------------------------------------------------------------------------
 * @name In-App Message
 *  ---------------------------------------------------------------------------------------
 */

/**
 @param url The URL to be handled
 @return YES if the URL was successfully handled or NO if the attempt to handle the
 URL failed.

 * @Version SDK3.0
 */
+ (BOOL)handleTestModeURL:(nonnull NSURL *)url;

/** Set the image to be used for dimissing an In-App message
 @param image The image to be used for dismissing an In-App message. By default this is a
 circle with an 'X' in the middle of it

 @Version SDK3.0
 */
+ (void)setInAppMessageDismissButtonImage:(nullable UIImage *)image;

/** Set the image to be used for dimissing an In-App message by providing the name of the
 image to be loaded and used
 @param imageName The name of an image to be loaded and used for dismissing an In-App
 message. By default the image is a circle with an 'X' in the middle of it

 @Version SDK3.0
 */
+ (void)setInAppMessageDismissButtonImageWithName:(nullable NSString *)imageName;

/** Set the location of the dismiss button on an In-App msg
 @param location The location of the button (left or right)
 @see InAppDismissButtonLocation

 @Version SDK3.0
 */
+ (void)setInAppMessageDismissButtonLocation:(LLInAppMessageDismissButtonLocation)location;

/** Returns the location of the dismiss button on an In-App msg
 @return InAppDismissButtonLocation
 @see InAppDismissButtonLocation

 @Version SDK3.0
 */
+ (LLInAppMessageDismissButtonLocation)inAppMessageDismissButtonLocation;

/** Set the dismiss button hidden state on an In-App message
 * @param hidden  The hidden state of the dismiss button

 * @Version SDK4.3.0
 */
+ (void)setInAppMessageDismissButtonHidden:(BOOL)hidden;

/**
 Trigger an In-App message

 @param triggerName The name of the In-App message trigger

 @Version SDK3.0
 */
+ (void)triggerInAppMessage:(nonnull NSString *)triggerName;

/**
 Trigger an In-App message

 @param triggerName The name of the In-App message trigger
 @param attributes  The attributes associated with the In-App triggering event

 @Version SDK3.0
 */
+ (void)triggerInAppMessage:(nonnull NSString *)triggerName withAttributes:(nonnull NSDictionary<NSString *,NSString *> *)attributes;

/**
 Trigger campaigns as if a Session Start event had just occurred.

 This is useful for integrations that want to delay presentation
 of startup campaigns due to some startup state, such as a splash screen.
 In order to delay the triggering, implement
 LLMessagingListener and respond appropriately to
 [LLMessagingListener localyticsShouldDelaySessionStartInAppMessages].
 Finally, once the start up state has cleared, call this method to trigger In-App
 campaigns as if a session had just been started.

 @Version SDK4.3.0
 */
+ (void)triggerInAppMessagesForSessionStart;

/**
 * If an In-App message is currently displayed, dismiss it. Is a no-op otherwise.

 * @Version SDK3.0
 */
+ (void)dismissCurrentInAppMessage;

/**
 * A standard event to tag an In-App impression
 *
 * @param campaign The In-App campaign for which to tag an impression
 * @param impressionType an enum of LLImpressionTypeClick or LLImpressionTypeDismiss

 * @Version SDK4.3.1
 */
+ (void)tagImpressionForInAppCampaign:(nonnull LLInAppCampaign *)campaign
                             withType:(LLImpressionType)impressionType;

/**
 * A standard event to tag an In-App impression.
 * This method should be used when the standard methods are not intended.  If a standard
 * impression is desirable use [Localytics tagInAppImpression:withImpressionType:}
 *
 * Any NSString value passed in that is not equal to 'X' will result in a click on the dashboard.
 * If an empty NSString is passed in, a dismiss impression will be tagged.
 *
 * @param campaign The In-App campaign for which to tag an impression
 * @param customAction an NSString to tag the impression with.

 * @Version SDK4.3.1
 */
+ (void)tagImpressionForInAppCampaign:(nonnull LLInAppCampaign *)campaign
                     withCustomAction:(nonnull NSString *)customAction;


#pragma mark - Inbox

/** Returns an array of all Inbox campaigns that are enabled and can be displayed.
 @return an array of LLInboxCampaign objects

 @Version SDK3.7.0
 */
+ (nonnull NSArray<LLInboxCampaign *> *)inboxCampaigns __attribute__((deprecated("inboxCampaigns has been deprecated, please use displayableInboxCampaigns")));

/** Returns an array of all Inbox campaigns that are enabled and can be displayed.
 @return an array of LLInboxCampaign objects
 
 @Version SDK5.2.0
 */
+ (nonnull NSArray<LLInboxCampaign *> *)displayableInboxCampaigns;

/** Returns an array of all Inbox campaigns that are enabled. The return value will include Inbox
 campaigns with no listing title, and thus no visible UI element as well as deleted Inbox campaigns.
 @return an array of LLInboxCampaign objects

 @Version SDK4.4.0
 */
+ (nonnull NSArray<LLInboxCampaign *> *)allInboxCampaigns;

/** Refresh inbox campaigns from the Localytics server that are enabled and can be displayed.
 @param completionBlock the block invoked with refresh is complete

 @Version SDK3.7.0
 */
+ (void)refreshInboxCampaigns:(nonnull void (^)(NSArray<LLInboxCampaign *> * _Nullable inboxCampaigns))completionBlock;

/** Refresh inbox campaigns from the Localytics server that are enabled. The return value will
 include Inbox campaigns with no listing title, and thus no visible UI element as well as deleted Inbox campaigns.
 @param completionBlock the block invoked with refresh is complete

 @Version SDK4.4.0
 */
+ (void)refreshAllInboxCampaigns:(nonnull void (^)(NSArray<LLInboxCampaign *> * _Nullable inboxCampaigns))completionBlock;

/** Set an Inbox campaign as read. Read state can be used to display opened but not disabled Inbox
 campaigns differently (e.g. greyed out).
 @param campaign an LLInboxCampaign that should have its read flag changed.
 @param read YES to mark the campaign as read, NO to mark it as unread
 @see [LLInboxCampaign class]

 @Version SDK4.4.0
 */
+ (void)setInboxCampaign:(nonnull LLInboxCampaign *)campaign asRead:(BOOL)read;

/** Set an Inbox campaign as deleted. Deleted Inbox campaigns will not be returned from
 the list of visible inbox campaigns.
 @param campaign an LLInboxCampaign that should be deleted
 @see [LLInboxCampaign class]
 
 @Version SDK5.2.0
 */
+ (void)deleteInboxCampaign:(nonnull LLInboxCampaign *)campaign;

/** Get the count of unread inbox messages
 @return the count of unread inbox messages

 @Version SDK4.0
 */
+ (NSInteger)inboxCampaignsUnreadCount;

/** Returns a inbox campaign detail view controller with the given inbox campaign data.
 @return a LLInboxDetailViewController from a given LLInboxCampaign object

 @Version SDK3.7.0
 */
+ (nonnull LLInboxDetailViewController *)inboxDetailViewControllerForCampaign:(nonnull LLInboxCampaign *)campaign;

/**
 * A standard event to tag an Inbox impression
 *
 * @param campaign The Inbox campaign for which to tag an impression
 * @param impressionType an enum of LLImpressionTypeClick or LLImpressionTypeDismiss

 * @Version SDK4.3.1
 */
+ (void)tagImpressionForInboxCampaign:(nonnull LLInboxCampaign *)campaign
                             withType:(LLImpressionType)impressionType;

/**
 * A standard event to tag an Inbox impression.
 * This method should be used when the standard methods are not intended.  If a standard
 * impression is desirable use [Localytics tagInboxImpression:withImpressionType:}
 *
 * Any NSString value passed in that is not equal to 'X' will result in a click on the dashboard.
 * If an empty NSString is passed in, a dismiss impression will be tagged.
 *
 * @param campaign The Inbox campaign for which to tag an impression
 * @param customAction an NSString to tag the impression with.

 * @Version SDK4.3.1
 */
+ (void)tagImpressionForInboxCampaign:(nonnull LLInboxCampaign *)campaign
                     withCustomAction:(nonnull NSString *)customAction;

/**
 * A standard event to tag a Push to Inbox impression.
 *
 * @param campaign The Inbox campaign for which to tag an impression
 * @param success Whether or not the deep link was successful

 * @Version SDK4.4.0
 */
+ (void)tagImpressionForPushToInboxCampaign:(nonnull LLInboxCampaign *)campaign
                                    success:(BOOL)success;

/**
 * Tell the Localytics SDK that an Inbox campaign was tapped in the list view.
 *
 * @param campaign The Inbox campaign that was tapped in the list view.

 * @Version SDK4.4.0
 */
+ (void)inboxListItemTapped:(nonnull LLInboxCampaign *)campaign;

#pragma mark - Location

/** Enable or disable location monitoring for geofence monitoring. Enabling location monitoring
 will prompt the user for location permissions. The NSLocationAlwaysUsageDescription key must
 also be set in your Info.plist
 @param enabled YES to enable location monitoring, NO to disable monitoring

 * @Version SDK4.0
 */
+ (void)setLocationMonitoringEnabled:(BOOL)enabled;

/** Retrieve the closest 20 geofences to monitor based on the devices current location. This method
 should be used if you would rather manage location updates and region monitoring instead of
 allowing the Localytics SDK to manage location updates and region monitoring automatically when
 using setLocationMonitoringEnabled. This method should be used in conjunction with triggerRegion:withEvent:
 and triggerRegions:withEvent: to notify the Localytics SDK that regions have been entered or exited.
 @param currentCoordinate The devices current location coordinate
 @see triggerRegion:withEvent:
 @see triggerRegions:withEvent:

 * @Version SDK4.0
 */
+ (nonnull NSArray<LLRegion *> *)geofencesToMonitor:(CLLocationCoordinate2D)currentCoordinate;

/** Trigger a region with a certain event. This method should be used in conjunction with geofencesToMonitor:.
 @param region The CLRegion that is triggered
 @param event The triggering event (enter or exit)
 @param location A CLLocation that will update the closest geofences for future triggers
 @see geofencesToMonitor:

 * @Version SDK5.0
 */
+ (void)triggerRegion:(nonnull CLRegion *)region withEvent:(LLRegionEvent)event atLocation:(nullable CLLocation *)location;

/** Trigger regions with a certain event at a certain location. This method should be used in
 conjunction with geofencesToMonitor:.
 @param regions An array of CLRegion object that are triggered
 @param event The triggering event (enter or exit)
 @param location A CLLocation that will update the closest geofences for future triggers
 @see geofencesToMonitor:

 * @Version SDK5.0
 */
+ (void)triggerRegions:(nonnull NSArray<CLRegion *> *)regions withEvent:(LLRegionEvent)event atLocation:(nullable CLLocation *)location;

/**
 * A standard event to tag a Places Push Received.
 *
 * Standard integrations should not require this method.  Rather it should only be used
 * if standard places triggering is suppressed in favor of custom logic.
 *
 * @param campaign The Places campaign for which to tag an event

 * @Version SDK4.3.0
 */
+ (void)tagPlacesPushReceived:(nonnull LLPlacesCampaign *)campaign;

/**
 * A standard event to tag a Places Push Opened.
 *
 * Standard integrations should not require this method.  Rather it should only be used
 * if standard places triggering is suppressed in favor of custom logic.
 *
 * @param campaign The Places campaign for which to tag an event

 * @Version SDK4.3.0
 */
+ (void)tagPlacesPushOpened:(nonnull LLPlacesCampaign *)campaign;

/**
 * An event to tag a Places Push Opened with a custom action.
 *
 * Standard integrations should not require this method.  Rather it should only be used
 * if standard places triggering is suppressed in favor of custom logic.
 *
 * @param campaign The Places campaign for which to tag an event
 * @param identifier The specific notification action associated with the opened push notification.

 * @Version SDK4.4.0
 */
+ (void)tagPlacesPushOpened:(nonnull LLPlacesCampaign *)campaign
       withActionIdentifier:(nonnull NSString *)identifier;

/**
 * Trigger a places notification for the given campaign
 *
 * @param campaign The Places campaign for which to trigger a notification

 * @Version SDK4.3.0
 */

+ (void)triggerPlacesNotificationForCampaign:(nonnull LLPlacesCampaign *)campaign;

/**
 * Trigger a places notification for the given campaign id and regionId
 *
 * @param campaignid The Places campaign id for which to trigger a notification
 * @param regionId The Places region id for which to trigger a notification

 * @Version SDK4.3.0
 */

+ (void)triggerPlacesNotificationForCampaignId:(NSInteger)campaignId
                              regionIdentifier:(nonnull NSString *)regionId;


#pragma mark - In-App Message Delegate
/** ---------------------------------------------------------------------------------------
 * @name In-App Message Delegate
 *  ---------------------------------------------------------------------------------------
 */

/** Set a Messaging delegate
 @param delegate An object that implements the LLMessagingDelegate.
 @see LLMessagingDelegate

 @Version SDK4.0
 */
+ (void)setMessagingDelegate:(nullable id<LLMessagingDelegate>)delegate;

/** Set a CallToAction delegate
 @param delegate An object that implements the LLCallToActionDelegate.
 @see LLCallToActionDelegate
 
 @Version SDK4.0
 */
+ (void)setCallToActionDelegate:(nullable id<LLCallToActionDelegate>)delegate;

/** Returns whether the ADID parameter is added to In-App call to action URLs
 This call is not garaunteed to return the correct result as the call to setInAppAdidParameterEnabled
 is run asynchronously, and this returns synchronously.
 SDK v6.0 will contain a fix for this behavior, if this is a major blocker, please contact support.
 @return YES if parameter is added, NO otherwise

 * @Version SDK4.0
 */
+ (BOOL)isInAppAdIdParameterEnabled;

/** Set whether ADID parameter is added to In-App call to action URLs. By default
 the ADID parameter will be added to call to action URLs.
 @param enabled Set to YES to enable the ADID parameter or NO to disable it

 * @Version SDK3.4
 */
+ (void)setInAppAdIdParameterEnabled:(BOOL)enabled;

/** Returns whether the ADID parameter is added to Inbox call to action URLs
 This call is not garaunteed to return the correct result as the call to setInboxAdidParameterEnabled
 is run asynchronously, and this returns synchronously.
 SDK v6.0 will contain a fix for this behavior, if this is a major blocker, please contact support.
 @return YES if parameter is added, NO otherwise

 * @Version SDK5.0
 */
+ (BOOL)isInboxAdIdParameterEnabled;

/** Set whether ADID parameter is added to Inbox call to action URLs. By default
 the ADID parameter will be added to call to action URLs.
 @param enabled Set to YES to enable the ADID parameter or NO to disable it

 * @Version SDK5.0
 */
+ (void)setInboxAdIdParameterEnabled:(BOOL)enabled;


#pragma mark - Location Delegate
/** ---------------------------------------------------------------------------------------
 * @name Location Delegate
 *  ---------------------------------------------------------------------------------------
 */

/** Set a Location delegate
 @param delegate An object implementing the LLLocationDelegate protocol.
 @see LLLocationDelegate

 * @Version SDK4.0
 */
+ (void)setLocationDelegate:(nullable id<LLLocationDelegate>)delegate;

#endif

@end

/**
 @discussion The class which manages creating, collecting, & uploading a Localytics session.
 Please see the following guides for information on how to best use this
 library, sample code, and other useful information:
 <ul>
 <li><a href="http://docs.localytics.com/dev/ios.html">
 Main Developer's Integration Guide</a></li>
 </ul>
 
 <strong>Best Practices</strong>
 <ul>
 <li>Integrate Localytics in <code>applicationDidFinishLaunching</code>.</li>
 <li>Open your session and begin your uploads in <code>applicationDidBecomeActive</code>. This way the
 upload has time to complete and it all happens before your users have a
 chance to begin any data intensive actions of their own.</li>
 <li>Close the session in <code>applicationWillResignActive</code>.</li>
 <li>Do not call any Localytics functions inside a loop.  Instead, calls
 such as <code>tagEvent</code> should follow user actions.  This limits the
 amount of data which is stored and uploaded.</li>
 <li>Do not instantiate a Localtyics object, instead use only the exposed class methods.</li>
 </ul>

 * @Version SDK3.0
 */
@interface Localytics : NSObject <Localytics>
@end

#pragma mark -

/**
 * A protocol used to receive analytics callbacks.

 * @Version SDK3.0
 */
@protocol LLAnalyticsDelegate <NSObject, JSExport>
@optional

/**
 * Callback that a session will be opened. Only called when resuming or opening a new session.
 * Is not called if a session is currently open.
 *
 * @param isFirst   Boolean indicating that the session will be the first session ever opened
 *                  for this installation.
 * @param isUpgrade Boolean indicating that the session will be the first session opened since
 *                  the app was upgraded.
 * @param isResume  Boolean indicating that an old session will be resumed, as opposed to
 *                  a new session being opened.

 * @Version SDK3.0
 */
- (void)localyticsSessionWillOpen:(BOOL)isFirst isUpgrade:(BOOL)isUpgrade isResume:(BOOL)isResume;

/**
 * Callback that a session was either opened or resumed. Is not called if a session was already open.
 *
 * @param isFirst   Boolean indicating that the session is the first session ever opened
 *                  for this installation.
 * @param isUpgrade Boolean indicating that the session is the first session opened since
 *                  the app was upgraded.
 * @param isResume  Boolean indicating that an old session was resumed, as opposed to
 *                  a new session was opened.

 * @Version SDK3.0
 */
- (void)localyticsSessionDidOpen:(BOOL)isFirst isUpgrade:(BOOL)isUpgrade isResume:(BOOL)isResume;

/**
 * Callback that an event was tagged.
 *
 * @param eventName             The name of the event.
 * @param attributes            The event's attributes.
 * @param customerValueIncrease The change in a customer's lifetime value associated with this event.

 * @Version SDK3.0
 */
- (void)localyticsDidTagEvent:(nonnull NSString *)eventName
                   attributes:(nullable NSDictionary<NSString *,NSString *> *)attributes
        customerValueIncrease:(nullable NSNumber *)customerValueIncrease;

/**
 * Callback that a session will be closed. Is called only if a session is currently open. Note that
 * the session might be resumed if [Localytics openSession] is called, so there is no guarantee that
 * the session will actually close after this callback.

 * @Version SDK3.0
 */
- (void)localyticsSessionWillClose;

@end


#if !TARGET_OS_TV

/**
 * A protocol used to receive messaging callbacks.

 * @Version SDK3.0.0
 */
@protocol LLMessagingDelegate <NSObject>
@optional

/**
 * Callback to determine if an In-App campaign should be shown.
 *
 * @param campaign The campaign that will be shown
 * @return The decision to show the In-App campaign.

 * @Version SDK4.3.0
 */
- (BOOL)localyticsShouldShowInAppMessage:(nonnull LLInAppCampaign *)campaign;

/**
 * Callback to determine if In-App campaigns triggered by session
 * start should be shown. This callback is useful for integrations that
 * want to delay presentation of startup campaigns due to the fact that
 * they have some startup state, such as a splash screen.
 *
 * @see [Localytics triggerInAppMessagesForSessionStart]
 *
 * @return The decision to delay In-App campaigns triggered by the "Session Start" event.

 * @Version SDK4.3.0
 */
- (BOOL)localyticsShouldDelaySessionStartInAppMessages;

/**
 * Callback to modify presentation of an In-App Campaign.
 *
 * @param campaign An immutable object representing the campaign that will be shown
 * @param configuration An object representing the mutable visual state of the In-App campaign
 *        @see LLInAppConfiguration
 * @return The modified configuration object containing all preferred display values.

 * @Version SDK3.0
 */
- (nonnull LLInAppConfiguration *)localyticsWillDisplayInAppMessage:(nonnull LLInAppCampaign *)campaign withConfiguration:(nonnull LLInAppConfiguration *)configuration;

/**
 * Callback that an In-App message was displayed.

 * @Version SDK3.0
 */
- (void)localyticsDidDisplayInAppMessage;

/**
 * Callback that an In-App message will be dismissed.

 * @Version SDK3.0
 */
- (void)localyticsWillDismissInAppMessage;

/**
 * Callback that an In-App message was dismissed.

 * @Version SDK3.0
 */
- (void)localyticsDidDismissInAppMessage;

/**
 * Callback that an Inbox Detail View Controller will be shown. This method is called from the viewWillAppear: method of UIViewController.

 * @Version SDK4.4.0
 */
- (void)localyticsWillDisplayInboxDetailViewController;

/**
 * Callback that an Inbox Detail View Controller was just shown.  This method is called from the viewDidAppear: method of UIViewController.

 * @Version SDK4.4.0
 */
- (void)localyticsDidDisplayInboxDetailViewController;

/**
 * Callback that an Inbox Detail View Controller will be dismissed. This method is called from the viewWillDisappear: method of UIViewController.

 * @Version SDK4.4.0
 */
- (void)localyticsWillDismissInboxDetailViewController;

/**
 * Callback that an Inbox Detail View Controller was just dismissed.  This method is called from the viewDidDisappear: method of UIViewController.

 * @Version SDK4.4.0
 */
- (void)localyticsDidDismissInboxDetailViewController;


/**
 * Callback to determine if the triggering of a Places campaign should show a local notification.
 *
 * @param campaign An object defining a Places Campaign
 * @return The decision to show the local notification.

 * @Version SDK4.0
 */
- (BOOL)localyticsShouldDisplayPlacesCampaign:(nonnull LLPlacesCampaign *)campaign;

/**
 * Callback to modify the appearance of a local notification.
 *
 * @param notification The iOS local notification.
 * @param campaign The campaign that triggered the Places notification
 * @return The iOS notification with all updated preferences

 * @Version SDK4.0
 */
- (nonnull UILocalNotification *)localyticsWillDisplayNotification:(nonnull UILocalNotification *)notification forPlacesCampaign:(nonnull LLPlacesCampaign *)campaign;

/**
 * Callback to modify the appearance of a local notification.
 *
 * @param notification The iOS notification content used to customize a local notification.
 * @param campaign The campaign that triggered the Places notification
 * @return The iOS notification content with all updated preferences

 * @Version SDK4.1.0
 */
- (nonnull UNMutableNotificationContent *)localyticsWillDisplayNotificationContent:(nonnull UNMutableNotificationContent *)notification forPlacesCampaign:(nonnull LLPlacesCampaign *)campaign;

/**
 * Callback to suppress deeplinking from the Localytics SDK.
 *
 * @param url The url that will be opened if deeplinking is permitted.
 * @return A boolean, YES indicates that the Localytics SDK should handle the deeplink and NO indicated it shouldn't.

 * @Version SDK5.0
 */
- (BOOL)localyticsShouldDeeplink:(nonnull NSURL *)url __attribute__((deprecated("localyticsShouldDeeplink in the LLMessagingDelegate has been deprecated, please use localyticsShouldDeeplink in the LLCallToActionDelegate instead")));

@end


/**
 * A protocol used to receive location updates.

 * @Version SDK4.0
 */
@protocol LLLocationDelegate <NSObject>
@optional

/**
 * Callback for when a significant location update occurs.
 *
 * @param location An object representing the updated location.

 * @Version SDK4.0
 */
- (void)localyticsDidUpdateLocation:(nonnull CLLocation *)location;

/**
 * Callback for when Localytics updates the regions that are being monitored.
 *
 * @param addedRegions The list of regions that will be added to monitoring
 * @param removedRegions The list of regions which will no longer be monitored.

 * @Version SDK4.0
 */
- (void)localyticsDidUpdateMonitoredRegions:(nonnull NSArray<LLRegion *> *)addedRegions removeRegions:(nonnull NSArray<LLRegion *> *)removedRegions;

/**
 * Callback for when Localytics recognized the entering or exiting of certain regions
 *
 * @param regions The list of regions that have been triggered
 * @param event An event indicating if the regions were triggered due to entering or exiting.

 * @Version SDK4.0
 */
- (void)localyticsDidTriggerRegions:(nonnull NSArray<LLRegion *> *)regions withEvent:(LLRegionEvent)event;

@end

/**
 * A protocol used to receive information about Call To Actions triggered by Localytics campaigns.
 
 * @Version SDK5.0
 */
@protocol LLCallToActionDelegate <NSObject>
@optional

/**
 * @param url The URL that was triggered inside a Localytics call to action from any
 *            messaging (Push, Places, In-App or Inbox) campaign
 * @param campaign The campaign that triggered this deeplink (in the case of push, this will be nil).
 * @return The decision to allow Localytics to handle the deeplink
 */
- (BOOL)localyticsShouldDeeplink:(nonnull NSURL *)url campaign:(nullable LLCampaignBase *)campaign;
/**
 * Callback to indicate that a user has triggered an privacy opt in or opt out using the Javascript
 * API provided in a Localytics In-App or Inbox message.
 *
 * @param optOut The result of the call to action indicating that the user opted in (false) or out (true).
 * @param campaign The campaign which triggered the opt in/out call.
 */
- (void)localyticsDidOptOut:(BOOL)optedOut campaign:(nonnull LLCampaignBase *)campaign;
/**
 * Callback to indicate that a user has triggered an opt in or opt out using the Javascript
 * API provided in a Localytics In-App or Inbox message.
 *
 * @param optOut The result of the call to action indicating that the user opted in (false) or out (true).
 * @param campaign The campaign which triggered the privacy opt in/out call.
 */
- (void)localyticsDidPrivacyOptOut:(BOOL)privacyOptedOut campaign:(nonnull LLCampaignBase *)campaign;
/**
 * Callback to indicate that a user has triggered a location when in use permission prompt using the Javascript
 * API provided in a Localytics In-App or Inbox message.
 *
 * @param campaign The campaign which triggered the location when in use permission prompt.
 * @return boolean indicating if Localytics should proceed. Returning false will prevent the location prompt.
 */
- (BOOL)localyticsShouldPromptForLocationWhenInUsePermissions:(nonnull LLCampaignBase *)campaign;
/**
 * Callback to indicate that a user has triggered a location always permission prompt using the Javascript
 * API provided in a Localytics In-App or Inbox message.
 *
 * @param campaign The campaign which triggered the location always permission prompt.
 * @return boolean indicating if Localytics should proceed. Returning false will prevent the location prompt.
 */
- (BOOL)localyticsShouldPromptForLocationAlwaysPermissions:(nonnull LLCampaignBase *)campaign;
/**
 * Callback to indicate that a user has triggered a notification permission prompt using the Javascript
 * API provided in a Localytics In-App or Inbox message.
 *
 * @param campaign The campaign which triggered the notification permission prompt.
 * @return boolean indicating if Localytics should proceed. Returning false will prevent the location prompt.
 */
- (BOOL)localyticsShouldPromptForNotificationPermissions:(nonnull LLCampaignBase *)campaign;
@end
#endif
