/*
 Copyright 2013-2016 appPlant GmbH

 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "APPPrinter.h"
#import <Cordova/CDVAvailability.h>

@interface APPPrinter ()

@property (retain) NSString* callbackId;
@property (retain) NSMutableDictionary* settings;

@end


@implementation APPPrinter

#pragma mark -
#pragma mark Interface

/*
 * Checks if the printing service is available.
 *
 * @param {Function} callback
 *      A callback function to be called with the result
 */
- (void) check:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult;
        BOOL isAvailable   = [self isPrintingAvailable];
        NSArray *multipart = @[[NSNumber numberWithBool:isAvailable],
                               [NSNumber numberWithInt:-1]];

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                      messageAsMultipart:multipart];

        [self.commandDelegate sendPluginResult:pluginResult
                                    callbackId:command.callbackId];
    }];
}

/**
 * Sends the printing content to the printer controller and opens them.
 *
 * @param {NSString} content
 *      The (HTML encoded) content
 */
- (void) print:(CDVInvokedUrlCommand*)command
{
    if (!self.isPrintingAvailable) {
        return;
    }

    _callbackId = command.callbackId;

    NSArray* arguments            = [command arguments];
    NSString* content             = [arguments objectAtIndex:0];
    self.settings                 = [arguments objectAtIndex:1];

    UIPrintInteractionController* controller = [self printController];

    [self adjustPrintController:controller withSettings:self.settings];
    [self loadContent:content intoPrintController:controller];

}

/**
 * Displays system interface for selecting a printer
 *
 * @param command
 *      Contains the callback function and picker options if applicable
 */
- (void) pick:(CDVInvokedUrlCommand*)command
{
    if (!self.isPrintingAvailable) {
        return;
    }
    _callbackId = command.callbackId;

    NSArray*  arguments           = [command arguments];
    NSMutableDictionary* settings = [arguments objectAtIndex:0];

    NSArray* bounds = [settings objectForKey:@"bounds"];
    CGRect rect     = [self convertIntoRect:bounds];

    [self presentPrinterPicker:rect];
}

#pragma mark -
#pragma mark UIWebViewDelegate

/**
 * Sent after a web view finishes loading a frame.
 *
 * @param webView
 *      The web view has finished loading.
 */
- (void) webViewDidFinishLoad:(UIWebView *)webView
{
    UIPrintInteractionController* controller = [self printController];
    NSString* printerId = [self.settings objectForKey:@"printerId"];

    if (( ![printerId isEqual:[NSNull null]] ) && ( [printerId length] > 0 )) {
        [self sendToPrinter:controller printer:printerId];
        return;
    }

    NSArray* bounds = [self.settings objectForKey:@"bounds"];
    CGRect rect     = [self convertIntoRect:bounds];

    [self presentPrintController:controller fromRect:rect];
}

#pragma mark -
#pragma mark Core

/**
 * Checks either the printing service is avaible or not.
 *
 * @return {BOOL}
 */
- (BOOL) isPrintingAvailable
{
    Class controllerCls = NSClassFromString(@"UIPrintInteractionController");

    if (!controllerCls) {
        return NO;
    }

    return [self printController] && [UIPrintInteractionController
                                      isPrintingAvailable];
}

/**
 * Opens the print controller so that the user can choose between
 * available iPrinters.
 *
 * @param {UIPrintInteractionController} controller
 *      The prepared print controller with a content
 */
- (void) presentPrintController:(UIPrintInteractionController*)controller
                       fromRect:(CGRect)rect
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [controller presentFromRect:rect inView:self.webView animated:YES completionHandler:
         ^(UIPrintInteractionController *ctrl, BOOL ok, NSError *e) {
             CDVPluginResult* pluginResult =
             [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                 messageAsBool:ok];

             [self.commandDelegate sendPluginResult:pluginResult
                                         callbackId:_callbackId];
         }];
    }
    else {
        [controller presentAnimated:YES completionHandler:
         ^(UIPrintInteractionController *ctrl, BOOL ok, NSError *e) {
             CDVPluginResult* pluginResult =
             [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                 messageAsBool:ok];

             [self.commandDelegate sendPluginResult:pluginResult
                                         callbackId:_callbackId];
         }];
    }
}

/**
 * Sends the content directly to the specified printer.
 *
 * @param controller
 *      The prepared print controller with the content
 * @param printer
 *      The printer specified by its URL
 */
- (void) sendToPrinter:(UIPrintInteractionController*)controller
               printer:(NSString*)printerId
{
    NSURL* url         = [NSURL URLWithString:printerId];
    
    // check to see if we have previously created this printer to reduce printing/"contacting" time
    if(self.previousPrinter == nil || ![[[self.previousPrinter URL] absoluteString] isEqualToString: printerId]) {
        self.previousPrinter = [UIPrinter printerWithURL:url];
    }
    
    UIPrinter* printer = self.previousPrinter;
    
    
    [controller printToPrinter:printer completionHandler:
     ^(UIPrintInteractionController *ctrl, BOOL ok, NSError *e) {
         CDVPluginResult* pluginResult =
         [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                             messageAsBool:ok];

         [self.commandDelegate sendPluginResult:pluginResult
                                     callbackId:_callbackId];
     }];
}

/**
 * Displays system interface for selecting a printer
 *
 * @param rect
 *      Rect object of where to display the interface
 */
- (void) presentPrinterPicker:(CGRect)rect
{
    UIPrinterPickerController* controller =
    [UIPrinterPickerController printerPickerControllerWithInitiallySelectedPrinter:nil];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [controller presentFromRect:rect inView:self.webView animated:YES completionHandler:
         ^(UIPrinterPickerController *ctrl, BOOL userDidSelect, NSError *e) {
             [self returnPrinterPickerResult:ctrl
                           withUserDidSelect:&userDidSelect];
         }];
    }
    else {
        [controller presentAnimated:YES completionHandler:
         ^(UIPrinterPickerController *ctrl, BOOL userDidSelect, NSError *e) {
             [self returnPrinterPickerResult:ctrl
                           withUserDidSelect:&userDidSelect];
         }];
    }
}

/**
 * Calls the callback funtion with the result of the selected printer
 *
 * @param ctrl
 *      The UIPrinterPickerController used to display the printer selector interface
 * @param userDidSelect
 *      True if the user selected a printer
 */
- (void) returnPrinterPickerResult:(UIPrinterPickerController*)ctrl
                 withUserDidSelect:(BOOL*)userDidSelect
{
    CDVPluginResult* pluginResult =
    [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];

    if (userDidSelect) {
        UIPrinter* printer = ctrl.selectedPrinter;

        [UIPrinterPickerController
         printerPickerControllerWithInitiallySelectedPrinter:printer];

        pluginResult = [CDVPluginResult
                        resultWithStatus:CDVCommandStatus_OK
                        messageAsString:printer.URL.absoluteString];
    }

    [self.commandDelegate sendPluginResult:pluginResult
                                callbackId:_callbackId];
}

#pragma mark -
#pragma mark Helper

/**
 * Retrieves an instance of shared print controller.
 *
 * @return {UIPrintInteractionController*}
 */
- (UIPrintInteractionController*) printController
{
    return [UIPrintInteractionController sharedPrintController];
}

/**
 * Adjusts the settings for the print controller.
 *
 * @param {UIPrintInteractionController} controller
 *      The print controller instance
 *
 * @return {UIPrintInteractionController} controller
 *      The modified print controller instance
 */
- (UIPrintInteractionController*) adjustPrintController:(UIPrintInteractionController*)controller
                                           withSettings:(NSMutableDictionary*)settings
{
    UIPrintInfo* printInfo             = [UIPrintInfo printInfo];
    UIPrintInfoOrientation orientation = UIPrintInfoOrientationPortrait;
    UIPrintInfoOutputType outputType   = UIPrintInfoOutputGeneral;
    UIPrintInfoDuplex duplexMode       = UIPrintInfoDuplexNone;

    if ([[settings objectForKey:@"landscape"] boolValue]) {
        orientation = UIPrintInfoOrientationLandscape;
    }

    if ([[settings objectForKey:@"graystyle"] boolValue]) {
        outputType = UIPrintInfoOutputGrayscale;
    }

    outputType += [[settings objectForKey:@"border"] boolValue] ? 0 : 1;

    if ([[settings objectForKey:@"duplex"] isEqualToString:@"long"]) {
        duplexMode = UIPrintInfoDuplexLongEdge;
    } else
    if ([[settings objectForKey:@"duplex"] isEqualToString:@"short"]) {
        duplexMode = UIPrintInfoDuplexShortEdge;
    }

    printInfo.outputType  = outputType;
    printInfo.orientation = orientation;
    printInfo.duplex      = duplexMode;
    printInfo.jobName     = [settings objectForKey:@"name"];

    controller.printInfo  = printInfo;

    controller.showsPageRange = ![[settings objectForKey:@"hidePageRange"] boolValue];
    controller.showsNumberOfCopies = ![[settings objectForKey:@"hideNumberOfCopies"] boolValue];
    controller.showsPaperSelectionForLoadedPapers = ![[settings objectForKey:@"hidePaperFormat"] boolValue];

    return controller;
}

/**
 * Loads the content into the print controller.
 *
 * @param {NSString} content
 *      The (HTML encoded) content
 * @param {UIPrintInteractionController} controller
 *      The print controller instance
 */
- (void) loadContent:(NSString*)content intoPrintController:(UIPrintInteractionController*)controller
{
    UIWebView* page                 = [[UIWebView alloc] init];
    UIPrintPageRenderer* renderer   = [[UIPrintPageRenderer alloc] init];
    UIViewPrintFormatter* formatter = [page viewPrintFormatter];

    [renderer addPrintFormatter:formatter startingAtPageAtIndex:0];

    page.delegate = self;

    if ([NSURL URLWithString:content]) {
        NSURL *url = [NSURL URLWithString:content];

        [page loadRequest:[NSURLRequest requestWithURL:url]];
    }
    else {
        NSString* wwwFilePath = [[NSBundle mainBundle] pathForResource:@"www"
                                                                ofType:nil];
        NSURL* baseURL        = [NSURL fileURLWithPath:wwwFilePath];


        [page loadHTMLString:content baseURL:baseURL];
    }

    controller.printPageRenderer = renderer;
}

/**
 * Convert Array into Rect object.
 *
 * @param bounds
 *      The bounds
 *
 * @return
 *      A converted Rect object
 */
- (CGRect) convertIntoRect:(NSArray*)bounds
{
    return CGRectMake([[bounds objectAtIndex:0] floatValue],
                      [[bounds objectAtIndex:1] floatValue],
                      [[bounds objectAtIndex:2] floatValue],
                      [[bounds objectAtIndex:3] floatValue]);
}

@end
