//
//  DCPAmazon.h
//  DCPAmazon
//
//  Created by Marat Strelets on 2015-04-22.
//
//

#import <Cordova/CDVPlugin.h>

@interface DCPAmazon : CDVPlugin

- (void) cordovaUploadFile:(CDVInvokedUrlCommand *)command;

@end
