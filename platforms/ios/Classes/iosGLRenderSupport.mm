#import <CoreServices/CoreServices.h>
#import <CoreServices/UTCoreTypes.h>

#import "iosGLRenderSupport.h"

#include "GLRenderer.h"
#include "GLTextClip.h"
#include "GLVideoClip.h"
#include "GLWebClip.h"
#import <QuartzCore/QuartzCore.h>
#include <sstream>
#import <objc/runtime.h>
#include "core/RunnerMacros.h"
#import "iosAppDelegate.h"
#import "EAGLViewController.h"
#import <CoreText/CoreText.h>
#import "DeviceInfo.h"
#import "iosMediaStreamSupport.h"

@implementation FlowUITextView

- (id)initWithClip:(GLTextClip*)_textClip {
    textClip = _textClip;
    self = [super init];
    self.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.realText = @"";
    self.pendingText = @"";
   
    self.scrollHorizontalView = [[UIScrollView alloc] init];
    self.scrollHorizontalView.bounces = NO;
    self.scrollHorizontalView.scrollEnabled = NO;
    self.scrollHorizontalView.showsHorizontalScrollIndicator = NO;
    self.scrollHorizontalView.showsVerticalScrollIndicator = NO;
    self.scrollHorizontalView.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    
    [self.scrollHorizontalView addSubview:self];
    
    return self;
}

- (CGFloat)getTextViewTextWidth {
    return self.pendingText != nil && ![self.pendingText isEqualToString:@""] && self.pendingFont != nil  ?
        [self.pendingText sizeWithAttributes: @{NSFontAttributeName: self.pendingFont}].width :
        0.0;
}

- (CGFloat)getTextViewCursorPositionForRange: (NSRange)selectedRange {
    NSString* head = [self.pendingText substringToIndex:selectedRange.location];
    CGSize lineRect = [head sizeWithAttributes: @{NSFontAttributeName: self.pendingFont}];
    return lineRect.width;
}

- (void)setFrame:(CGRect)frame {
    self.scrollHorizontalView.frame = frame;
    
    if (!textClip->isMultiline()) {
        CGSize size = CGSizeMake(MAX([self getTextViewTextWidth], frame.size.width),
                                 frame.size.height);
        self.scrollHorizontalView.contentSize = size;
        super.frame = CGRectMake(0.0, 0.0, size.width, size.height);
        
        [self refreshHorizontalScrollForRange:self.selectedRange];
    } else {
        self.scrollHorizontalView.contentSize = frame.size;
        super.frame = CGRectMake(0.0, 0.0, frame.size.width, frame.size.height);
    }
}

- (void)setHidden:(BOOL)hidden {
    self.scrollHorizontalView.hidden = hidden;
    super.hidden = hidden;
}

- (void)setFont:(UIFont*)font {
    self.pendingFont = [font copy];
    [super setFont:font];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!textClip->isMultiline()) {
        self.pendingText = [[attributedText string] copy];
        self.frame = self.scrollHorizontalView.frame;
    }
    
    [super setAttributedText: attributedText];
}

- (void)refreshHorizontalScrollForRange:(NSRange)selectedRange {
    if (self.pendingFont == nil || self.text == nil || self.pendingText.length < selectedRange.location)
        return;
    
    CGFloat cursorPositionX = [self getTextViewCursorPositionForRange: selectedRange];
    CGFloat frameWidth = self.scrollHorizontalView.frame.size.width;
    CGPoint startPoint = CGPointMake(MAX(cursorPositionX - frameWidth, 0.0), 0.0);
    CGPoint endPoint = CGPointMake(MAX(cursorPositionX, frameWidth), 1.0);
    
    [self.scrollHorizontalView scrollRectToVisible:CGRectMake(startPoint.x, startPoint.y, endPoint.x, endPoint.y) animated:NO];
}

- (void)setSelectedRange:(NSRange)selectedRange {
    [self refreshHorizontalScrollForRange:selectedRange];
    [super setSelectedRange:selectedRange];
}

- (void)textInputDidChangeSelection:(id)arg1 {
    [self refreshHorizontalScrollForRange:self.selectedRange];
    [super textInputDidChangeSelection: arg1];
}

- (BOOL)keyboardInput:(UIView*)inputView shouldInsertText:(NSString*)text isMarkedText:(BOOL)marked {
    bool should = [super keyboardInput:inputView shouldInsertText:text isMarkedText:marked];
    
    if (should && !textClip->isMultiline()) {
        self.pendingText = [[self.text stringByAppendingString:text] copy];
        self.frame = self.scrollHorizontalView.frame;
    }
    
    return should;
}

- (void)_performPasteOfAttributedString: (NSAttributedString*)text toRange:(UITextRange *)range animator:(id)arg3 completion:(id)block {
    [super _performPasteOfAttributedString: text toRange: range animator:arg3 completion: block];
    
    if (!textClip->isMultiline()) {
        NSInteger startOffset = [self offsetFromPosition:self.beginningOfDocument toPosition:range.start];
        NSInteger length = [self offsetFromPosition:self.beginningOfDocument toPosition:range.end] - startOffset;
        self.pendingText = [[self.text stringByReplacingCharactersInRange:NSMakeRange(startOffset, length) withString:[text string]] copy];
        self.frame = self.scrollHorizontalView.frame;
    }
}

- (BOOL)textInput:(id)textInput shouldChangeCharactersInRange:(NSRange)range withString:(NSString *)text {
    bool should = [self textInput:textInput shouldChangeCharactersInRange:range withString:text];
    
    if (should && !textClip->isMultiline()) {
        self.pendingText = [[self.text stringByReplacingCharactersInRange:range withString:text] copy];
        self.frame = self.scrollHorizontalView.frame;
    }
    
    return should;
}

@end

/***********************************************
                ObjC helpers 
***********************************************/
@implementation TextFieldDelegate
- (id)initWithOwner: (iosGLRenderSupport *) ownr
{
    self = [super init];
    owner = ownr;

    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (BOOL)textViewShouldBeginEditing:(FlowUITextView *)textView
{
    return YES;
}

- (void)textViewDidBeginEditing:(FlowUITextView *)textView {
    owner->activeTextWidget = textView;
}

- (void)textViewDidEndEditing:(FlowUITextView *)textView {
    owner->activeTextWidget = nil;
}

- (BOOL)textView:(FlowUITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(nonnull NSString *)string {
    if (GLTextClip* clip = flow_native_cast<GLTextClip>(owner->NativeWidgetClips[textView])) {
        if (!clip->isMultiline() && [string isEqualToString:@"\n"]) {
            if (!owner->returnKeyEventFromTextClip(clip)) {
                clip->setFocus(false);
            }
            
            return NO;
        }
        
        if (clip->isNumeric()) {
            NSCharacterSet* cs =
            [[NSCharacterSet characterSetWithCharactersInString:@"0123456789."] invertedSet];
            NSRange range = [string rangeOfCharacterFromSet:cs];
            if (range.location != NSNotFound)
                return NO;
        }
        
        
        // Workaround for proposed email choose. Range behaves wrong from iOS side.
        if ([string isEqualToString:@""] && range.length == 0) {
            NSUInteger location = range.location;
            range.location = range.length;
            range.length = location;
        } else if (textView.realText.length == 0 && textView.text.length > 0) {
            range.location = 0;
        }
        
        NSString* newText =
            [textView.realText stringByReplacingCharactersInRange: range withString: string];
        int maxLength = clip->getMaxChars();
        if (maxLength > 0 && newText.length > maxLength) return NO;
        
        
        unicode_string filteredUText = clip->textFilteredByFlowFilters(NS2UNICODE(newText));
        NSString* filteredText = UNICODE2NS(filteredUText);
        
        bool equals = [newText isEqualToString:filteredText];
        bool doReplaceText = !equals || clip->isPassword();
        
        textView.realText = filteredText;
        if (clip->isPassword()) {
            filteredText = [[NSString string] stringByPaddingToLength:[filteredText length] withString:@"\u2022" startingAtIndex:0];
        }
        
        if (doReplaceText) {
            [textView setText: filteredText];
            owner->textViewChanged(textView, true);
        }
        
        return !doReplaceText;
    }
    
    return NO;
}

- (void)textViewDidChange:(FlowUITextView *)textView
{
    owner->textViewChanged(textView, true);
}

- (void)textViewDidChangeSelection:(FlowUITextView *)textView
{
    owner->textViewChanged(textView, false);
}
@end

@implementation WebViewDelegate
- (id)initWithOwner: (iosGLRenderSupport *) ownr
{
    self = [super init];
    owner = ownr;
    WebViewInnerDomains = [NSMutableDictionary new];
    WebViewWhiteListInnerDomains = [NSMutableDictionary new];
    WebViewExternalDocuments = [NSMutableDictionary new];
    return self;
}

- (void)dealloc {
    [WebViewInnerDomains release];
    [WebViewWhiteListInnerDomains release];
    [WebViewExternalDocuments release];
    [super dealloc];
}

// Inner domain list
// collects all document frames domains
// to open links from them inside the webview
- (void)addInnerDomain: (NSString*) domain forWebView: (UIView*) web_view {
    NSValue * view_key = [NSValue valueWithNonretainedObject: web_view];
    NSMutableSet * domains_set = [WebViewInnerDomains objectForKey: view_key];
    
    if (domains_set == nil) {
        domains_set = [NSMutableSet new];
        [WebViewInnerDomains setObject: domains_set forKey: view_key];
    }
    if (domain != nil)
        [domains_set addObject: domain];
}

- (void)removeInnerDomainsForWebView: (UIView*) web_view {
    NSValue * view_key = [NSValue valueWithNonretainedObject: web_view];
    [WebViewInnerDomains removeObjectForKey: view_key];
    [WebViewWhiteListInnerDomains removeObjectForKey: view_key];
}

- (void)setInnerDomainsWhiteList: (NSArray*) list forWebView: (UIView*) web_view {
    NSValue * view_key = [NSValue valueWithNonretainedObject: web_view];
    [WebViewWhiteListInnerDomains setObject: [NSSet setWithArray: list] forKey: view_key];
}

- (BOOL)isExternalDomain: (NSString*) domain forWebView: (UIView*) web_view {
    NSValue * view_key = [NSValue valueWithNonretainedObject: web_view];
    NSSet * white_list = [WebViewWhiteListInnerDomains objectForKey: view_key];
    NSSet * inner_domains = [WebViewInnerDomains objectForKey: view_key];
    
    return (white_list == nil || ![white_list containsObject: domain]) && (inner_domains == nil || ![inner_domains containsObject: domain]);
}

- (void)setExternalDocuments: (NSArray*) extentions forWebView: (UIView*) web_view {
    NSValue * view_key = [NSValue valueWithNonretainedObject: web_view];
    [WebViewExternalDocuments setObject: [NSSet setWithArray: extentions] forKey: view_key];
}

- (BOOL)isExternalDocument: (NSString*) url forWebView: (UIView*) web_view {
    NSValue * view_key = [NSValue valueWithNonretainedObject: web_view];
    NSSet * external_extentions = [WebViewExternalDocuments objectForKey: view_key];
    return external_extentions != nil && [external_extentions containsObject: url.pathExtension];
}

- (BOOL)isFlowAppURL: (NSURL*) url {
    return (url.host == nil);
}

// WKWebView messages:
//

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    // request.URL.relativeString contains absolute url here too
    NSURL* url = [navigationAction.request URL];
    NSString * absolute_url = [url absoluteString];
    
    if ([absolute_url hasPrefix:@"flow:"]) {
        if ([absolute_url hasPrefix: @"flow:::setInnerDomainsWhiteList"]) {
            // Special case - setting whitelist for user navigation inside the webview
            LogI(@"setInnerDomainsWhiteList: %@", absolute_url);
            NSArray *args = [[absolute_url stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding] componentsSeparatedByString: @":::"];
            [self setInnerDomainsWhiteList: [args subarrayWithRange: NSMakeRange(2, args.count - 2)] forWebView: webView];
        } else if ( [absolute_url hasPrefix: @"flow:::setExternalDocuments"] ) {
            // Special case - setting external extentions for user navigation outside the webview
            LogI(@"setExternalDocuments: %@", absolute_url);
            NSArray *args = [[absolute_url stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding] componentsSeparatedByString: @":::"];
            [self setExternalDocuments: [args subarrayWithRange: NSMakeRange(2, args.count - 2)]  forWebView: webView];
        } else {
            owner->callFlowFromJS(webView, absolute_url);
        }
        decisionHandler(WKNavigationActionPolicyCancel);
    } else if ([absolute_url hasPrefix: @"file://"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
    } else if ([self isFlowAppURL:url]) {
        [ [UIApplication sharedApplication] openURL: url ];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        if ( [absolute_url rangeOfString: @"external_browser="].location != NSNotFound ) {
            if ([absolute_url rangeOfString: @"external_browser=0"].location != NSNotFound) {
                decisionHandler(WKNavigationActionPolicyAllow);
            } else if ([absolute_url rangeOfString: @"external_browser=1"].location != NSNotFound) {
                decisionHandler(WKNavigationActionPolicyCancel);
                [ [UIApplication sharedApplication] openURL: navigationAction.request.URL ];
            } else {
                NSRange r = [absolute_url rangeOfString: @"external_browser=2"];
                if (r.location != NSNotFound) {
                    decisionHandler(WKNavigationActionPolicyAllow);
                    NSString * patched_url = [absolute_url stringByReplacingCharactersInRange: r withString: @""];
                    [[UIApplication sharedApplication] openURL: [NSURL URLWithString: patched_url]];
                }
            }
        } else {
            NSString* domain = url.host;
            bool is_external_domain = [self isExternalDomain: domain forWebView: webView];
            bool is_external_document = [self isExternalDocument: absolute_url forWebView: webView];
            LogI(@"User navigation : %@/external domain: %@/external document: %@",
                absolute_url, is_external_domain? @"yes" : @"no", is_external_document ? @"yes" : @"no");

            if (is_external_document || is_external_domain) {
                [[UIApplication sharedApplication] openURL: url];
                decisionHandler(WKNavigationActionPolicyCancel);
            } else {
                decisionHandler(WKNavigationActionPolicyAllow);
            }
        }
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    LogI(@"%@ loaded to embedded webview", webView.URL.absoluteString);
    
    GLWebClip * web_clip = flow_native_cast<GLWebClip>(owner->NativeWidgetClips[webView]);
    
    [webView evaluateJavaScript:@"document.body.innerHTML" completionHandler: ^void(id o, NSError * e) {
        NSString * html = o;
        if ([html isEqualToString: @"<center><h1>404 Not Found</h1></center>"]) {
            web_clip->notifyError("404 Page Not Found");
        } else {
            web_clip->notifyPageLoaded();
            
            // A workaround for weird WKWebView bug when focused INPUT
            // supress all tap events
            [webView evaluateJavaScript: @"document.addEventListener('click', function() {} )"  completionHandler: nil];
        }
    }];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    LogI(@"%@ failed to load to embedded webview (%@)", webView.URL.absoluteString, error);
    
    GLWebClip * web_clip = flow_native_cast<GLWebClip>(owner->NativeWidgetClips[webView]);
    if (web_clip != NULL) {
        web_clip->notifyError([[error localizedDescription] UTF8String]);
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    LogI(@"%@ failed to load to embedded webview (%@)", webView.URL.absoluteString, error);
    
    GLWebClip * web_clip = flow_native_cast<GLWebClip>(owner->NativeWidgetClips[webView]);
    if (web_clip != NULL) {
        web_clip->notifyError([[error localizedDescription] UTF8String]);
    }
}
@end

@implementation WebScrollViewDelegate
- (id) initWithOwner: (iosGLRenderSupport *) ownr
{
    self = [super init];
    owner = ownr;
    return self;
}

- (void)dealloc {
    [super dealloc];
}

-(UIView *) viewForZoomingInScrollView:(UIScrollView *)scrollViewBis
{
    return nil;
}

-(void)scrollViewWillBeginZooming:(UIScrollView*)scrollView withView: (UIView*) view {
    scrollView.pinchGestureRecognizer.enabled = NO;
}
@end

@interface UIImage (fixOrientation)

- (UIImage *)fixOrientation;

@end

@implementation UIImage (fixOrientation)

- (UIImage *)fixOrientation
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(self.size.width, self.size.height), YES, self.scale);
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end

@implementation ImagePickerControllerDelegate

@synthesize desiredWidth, desiredHeight, compressQuality, desiredFileName, fitMode, duration, size, flowCameraMode;

- (id) initWithOwner: (iosGLRenderSupport *) ownr {
    self = [super init];
    owner = ownr;
    return self;
}

- (void) dealloc {
    [super dealloc];
}

- (void) imagePickerController: (UIImagePickerController *) picker didFinishPickingMediaWithInfo: (NSDictionary *) info {
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    
    // Handle a still image capture
    if ([mediaType isEqualToString: (NSString *)kUTTypeImage]) {
        
        UIImage *originalImage = info[UIImagePickerControllerOriginalImage];
        
        if (!originalImage) {
            owner->notifyCameraEvent(1, "failed to get image from camera", -1, -1);
            [picker.presentingViewController dismissViewControllerAnimated:YES completion: nil];
            [picker release];
        }
        
        // TODO: Images taken with the front camera are flipped. Fix it.
        UIImage * image = [originalImage fixOrientation];
        
        UIImage * resizedImage = [ImagePickerControllerDelegate
                         resizeImage: image
                                  toDesiredWidth: self.desiredWidth andDesiredHeight: self.desiredHeight withFitMode: self.fitMode];
        NSData * imgData = UIImageJPEGRepresentation(resizedImage, self.compressQuality);
        NSArray * URLs = [[NSFileManager defaultManager] URLsForDirectory: NSDocumentDirectory inDomains: NSUserDomainMask];
        NSURL * documentsURL = URLs[0];
        NSString * fileName = [NSString stringWithFormat: @"%@.jpg", self.desiredFileName];
        NSURL * photoURL = [NSURL URLWithString: fileName relativeToURL: documentsURL];
        if ([imgData writeToURL: photoURL atomically: NO] == YES) {
            owner->notifyCameraEvent(0, [[photoURL path] UTF8String], resizedImage.size.width, resizedImage.size.height);
        } else {
            owner->notifyCameraEvent(1, "failed to save image file", -1, -1);
        }
    }
    
    // Handle a movie capture
    if ([mediaType isEqualToString: (NSString *)kUTTypeMovie]) {
        NSURL * videoURL = [info objectForKey: UIImagePickerControllerMediaURL];

        NSData * videoData = [NSData dataWithContentsOfURL: videoURL options: NSDataReadingUncached error: nil];

        NSDictionary * properties = [[NSFileManager defaultManager] attributesOfItemAtPath: videoURL.path error: nil];

        NSNumber * videoFileSize = [properties objectForKey: NSFileSize];
        self.size = [videoFileSize intValue];

        AVURLAsset * videoAsset = [AVURLAsset URLAssetWithURL: videoURL options: nil];
        double sec = CMTimeGetSeconds(videoAsset.duration);
        self.duration = ceil(sec);

        NSArray * videoTracks = [videoAsset tracksWithMediaType: AVMediaTypeVideo];
        if ([videoTracks count] > 0) {
            AVAssetTrack * videoTrack = [videoTracks objectAtIndex:0];
            CGSize videoResolution = [videoTrack naturalSize];
            self.desiredWidth = (int) videoResolution.width;
            self.desiredHeight = (int) videoResolution.height;
        } else {
            self.desiredWidth = 0;
            self.desiredHeight = 0;
        }

        NSArray * URLs = [[NSFileManager defaultManager] URLsForDirectory: NSDocumentDirectory inDomains: NSUserDomainMask];
        NSURL * documentsURL = URLs[0];
        NSString * fileName = [NSString stringWithFormat: @"%@.mp4", self.desiredFileName];
        NSURL * newVideoURL = [NSURL URLWithString: fileName relativeToURL: documentsURL];

        if ([videoData writeToURL: newVideoURL atomically: NO] == YES) {
            owner->notifyCameraEventVideo(0, [[videoURL path] UTF8String], self.desiredWidth, self.desiredHeight, self.duration, self.size);
        } else {
            owner->notifyCameraEventVideo(1, "failed to save video file", -1, -1, -1, -1);
        }
    }
    
    [picker dismissViewControllerAnimated: YES completion: nil];
    [picker release];
}

- (void) imagePickerControllerDidCancel: (UIImagePickerController *) picker {
    if (self.flowCameraMode == FlowCameraPhotoMode) {
        owner->notifyCameraEvent(1, "User canceled photo taking", -1, -1);
    } else {
        owner->notifyCameraEventVideo(1, "User canceled video taking", -1, -1, -1, -1);
    }
    
    [picker dismissViewControllerAnimated: YES completion: nil];
    [picker release];
}

+ (UIImage *) resizeImage: (UIImage *) img toDesiredWidth: (int) reqWidth andDesiredHeight: (int) reqHeight
    withFitMode : (int) imgFitMode {
    CGRect newSize;
    
    if (imgFitMode == FlowCameraFitCover) {
        int newWidth, newHeight;
        if (reqWidth > reqHeight)
        {
            newWidth = reqWidth;
            newHeight = roundf(img.size.height * ((float)reqWidth / img.size.width));
        } else {
            newWidth = roundf(img.size.width * ((float)reqHeight / img.size.height));
            newHeight = reqHeight;
        }
        newSize = CGRectMake(0, 0, newWidth, newHeight);
    } else if (imgFitMode == FlowCameraFitFill) {
        newSize = CGRectMake(0, 0, reqWidth, reqHeight);
    } else { // if (imgFitMode == FlowCameraFitContain)
        // Calculating downsample factor, as by default in android flowrunner
        int inSampleSize = 1;
        
        if (img.size.height > reqHeight || img.size.width > reqWidth) {
            int heightRatio = roundf((float)img.size.height / (float)reqHeight);
            int widthRatio = roundf((float)img.size.width / (float)reqWidth);
            
            inSampleSize = heightRatio < widthRatio ? heightRatio : widthRatio;
            
            float totalPixels = img.size.width * img.size.height;
            float totalReqPixelsCap = reqWidth * reqHeight * 2;
            
            while (totalPixels / (inSampleSize * inSampleSize) > totalReqPixelsCap) {
                inSampleSize++;
            }
        }
        newSize = CGRectMake(0, 0, img.size.width / inSampleSize, img.size.height / inSampleSize);
    }
    
    UIGraphicsBeginImageContext(newSize.size);
    [img drawInRect: newSize];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (imgFitMode == FlowCameraFitCover) { // we should also crop this image to make it fit to desired size
        newSize = CGRectMake((result.size.width - reqWidth) / 2.0, (result.size.height - reqHeight) / 2.0, reqWidth, reqHeight);
        CGImageRef resultImageRef = CGImageCreateWithImageInRect([result CGImage], newSize);
        result = [UIImage imageWithCGImage: resultImageRef];
        CGImageRelease(resultImageRef);
    }
    
    return result;
}
@end

@implementation FlowWKMessageHandler

- (id) initWithOwner: (iosGLRenderSupport*)ownr {
    self = [super init];
    owner = ownr;
    return self;
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    // TODO: Reimplement webview message handling here
}

@end

@implementation AudioRecordControlDelegate

- (id) initWithOwner: (iosGLRenderSupport *) ownr {
    self = [super init];
    owner = ownr;
    self.audioRecordURL = nil;
    self.manuallyStopped = false;
    return self;
}

- (void) dealloc {
    [super dealloc];
}

- (void) audioRecorderDidFinishRecording: (AVAudioRecorder *) recorder successfully: (BOOL) flag {
    if (!self.manuallyStopped) {
        UIAlertView * alert = [[UIAlertView alloc] initWithTitle: @"Audio recording stopped"
            message: @"The maximum length for this audio has been reached."
            delegate: nil
            cancelButtonTitle: @"OK"
            otherButtonTitles: nil];
        [alert show];
        [alert release];
    }
}

- (void) audioRecorderEncodeErrorDidOccur: (AVAudioRecorder *) recorder error: (NSError *) error {
    owner->notifyCameraEventAudio(5, "Failed to record audio", -1, -1);
}
@end

/***********************************************
    iosGLRenderSupport implementation
 ***********************************************/
iosGLRenderSupport::iosGLRenderSupport( ByteCodeRunner *owner, EAGLView *glview, EAGLViewController *glviewcontroller, UIView * widgets_view, std::string res_base, BOOL handle_accessible) : GLRenderSupport(owner), GLView(glview), GLViewController(glviewcontroller),
    WidgetsView(widgets_view),hasFullScreenTarget(false),
    FullScreenTargetCenterX(0.5f), FullScreenTargetCenterY(0.5f), FullScreenTargetScaleFactor(1.0f),
    ScreenScale(1.0), ResourceBase(res_base), handleAccessibleElements(handle_accessible), flowUIOrientation(FlowUIAuto)
{
    initializeGL();
    MouseRadius = 10.0f; // 10 pts
    NoHoverMouse = true;
    commonTextFieldDelegate = [[TextFieldDelegate alloc] initWithOwner: this];
    commonWebViewDelegate = [[WebViewDelegate alloc] initWithOwner: this];
    commonWebScrollViewDelegate = [[WebScrollViewDelegate alloc] initWithOwner: this];
    commonImagePickerControllerDelegate = [[ImagePickerControllerDelegate alloc] initWithOwner: this];
    commonAudioRecordControllerDelegate = [[AudioRecordControlDelegate alloc] initWithOwner: this];
    ScreenScale = GLView.contentScaleFactor;
    activeTextWidget = nil;
    
    LogI(@"DeviceInfo : %@ %f", [DeviceInfo getDeviceName], [DeviceInfo getScreenDiagonalIn]);
    
    float screen_diagonal_in = [DeviceInfo getScreenDiagonalIn];
    
    if (screen_diagonal_in > 0.0f) {
        CGSize screen_bounds = [UIScreen mainScreen].bounds.size;
        screen_bounds.height *= ScreenScale;
        screen_bounds.width *= ScreenScale;
        
        float dpi = sqrtf(screen_bounds.height * screen_bounds.height + screen_bounds.width * screen_bounds.width) / screen_diagonal_in;
        setDPI(dpi);
        LogI(@"DPI from DeviceInfo: %f", dpi);
    } else {
        float dpi = 160.0 * ScreenScale;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) dpi = 132.0 * ScreenScale;
        else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) dpi = 163.0 * ScreenScale;
        setDPI(dpi);
        LogI(@"DPI from interface idiom: %f", dpi);
    }
}

iosGLRenderSupport::~iosGLRenderSupport() {
    [commonTextFieldDelegate release];
    [commonWebViewDelegate release];
    [commonWebScrollViewDelegate release];
    [commonImagePickerControllerDelegate release];
    [commonAudioRecordControllerDelegate release];
    
    destroyAllNativeWidgets();
    
    [context release];
}

void iosGLRenderSupport::LoadFont(std::string code, std::string name)
{
    std::vector<unicode_string> aliases;
    aliases.push_back(parseUtf8(code));
    loadFont(name, aliases);
}

bool iosGLRenderSupport::loadAssetData(StaticBuffer *buffer, std::string name, size_t size)
{
    std::string fname = ResourceBase + name;
    return GLRenderSupport::loadAssetData(buffer, fname, size);
}

void iosGLRenderSupport::destroyAllNativeWidgets() {
    for (std::map<GLClip*,UIView*>::iterator it = NativeWidgets.begin(); it != NativeWidgets.end(); ++it) {
        UIView * widget = it->second;
        
        [widget removeFromSuperview];
        [widget release];
    }
    NativeWidgetClips.clear();
    NativeWidgets.clear();
}

void iosGLRenderSupport::OnRunnerReset(bool inDestructor)
{
    GLRenderSupport::OnRunnerReset(inDestructor);
    destroyAllNativeWidgets();
}

void iosGLRenderSupport::initializeGL()
{
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
    [EAGLContext setCurrentContext: context];
    
    glGenFramebuffers(1, &targetFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, targetFrameBuffer);
    
    glGenRenderbuffers(1, &targetRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, targetRenderbuffer);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, targetRenderbuffer);
    
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)GLView.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &targetRenderbufferWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &targetRenderbufferHeight);
 
    glGenRenderbuffers(1, &targetStencilBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, targetStencilBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, targetRenderbufferWidth, targetRenderbufferHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_STENCIL_ATTACHMENT, GL_RENDERBUFFER, targetStencilBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, targetStencilBuffer);
    
    NSLog(@"Render buffer created : %dx%d", targetRenderbufferWidth, targetRenderbufferHeight);
    
    if (!initGLContext(targetFrameBuffer)) {
        LogE(@"OpenGL Init Failed");
        UIAlertView * alert_view = [[UIAlertView alloc] initWithTitle: @"Error" message:@"Cannot initialize OpenGL" delegate: nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alert_view show];
        [alert_view release];
    }
    
    resizeGLContext(targetRenderbufferWidth, targetRenderbufferHeight);
}

void iosGLRenderSupport::resizeGLSurface() {
    [EAGLContext setCurrentContext: context];
    
    glBindRenderbuffer(GL_RENDERBUFFER, targetRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)GLView.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &targetRenderbufferWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &targetRenderbufferHeight);
    
    glBindRenderbuffer(GL_RENDERBUFFER, targetStencilBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8_OES, targetRenderbufferWidth, targetRenderbufferHeight);
    
    NSLog(@"Render buffer recreated : %dx%d", targetRenderbufferWidth, targetRenderbufferHeight);
    
    resizeGLContext(targetRenderbufferWidth, targetRenderbufferHeight);
}

void iosGLRenderSupport::paintGL() // Linked to display refreshing (60/4 = ~15 hz)
{
    if (needsDrawingGL)
    {
        if ( [EAGLContext currentContext] != context ) {
            [EAGLContext setCurrentContext:context];
        }
        
        needsDrawingGL = NO;
        
        paintGLContext();
    
        // Present renderbuffer from default framebufer on the CA EAGL layer 
        glBindRenderbuffer(GL_RENDERBUFFER, targetRenderbuffer);
        [context presentRenderbuffer: GL_RENDERBUFFER];
        
        if (handleAccessibleElements) updateAccessibleElements();
    }
}

void iosGLRenderSupport::updateAccessibleElements() {
    updateAccessibleClips();
    std::vector<GLClip*> accessible_clips = GLRenderSupport::accessible_clips;
    
    NSMutableArray * elements = GLView.accessibilityElements;
    [elements removeAllObjects];
    
    for (std::vector<GLClip*>::iterator it = accessible_clips.begin(); it != accessible_clips.end(); ++it) {
        GLClip * clip = *it;
        
        if (clip->getGlobalAlpha() == 0.0f) continue;
        
        const std::map<std::string, std::string> & attributes = clip->getAccessibilityAttributes();
        std::map<std::string, std::string>::const_iterator ait = attributes.find( "role" );
        if (ait == attributes.end() || ait->second != "button") continue; // Only for buttons for now
        
#if 0
        // DEBUG
        LogI(@"Acessibility button:");
        for (ait = attributes.begin(); ait != attributes.end(); ++ait) {
            LogI(@"%@ = %@", [NSString stringWithUTF8String: ait->first.c_str()], [NSString stringWithUTF8String: ait->second.c_str()]);
        }
#endif
        
        UIAccessibilityElement *element = [[UIAccessibilityElement alloc] initWithAccessibilityContainer: GLView];
        
        ait = attributes.find("description");
        
        if (ait != attributes.end() && ait->second != "") {
            element.accessibilityLabel = [NSString stringWithUTF8String: ait->second.c_str()];
        } else {
            element.accessibilityLabel = @"Flow Button";
        }
        
        const GLBoundingBox bbox = (*it)->getGlobalBBox();
        element.accessibilityFrame = UIAccessibilityConvertFrameToScreenCoordinates(
            CGRectMake(bbox.min_pt.x / ScreenScale, bbox.min_pt.y / ScreenScale, (bbox.max_pt.x - bbox.min_pt.x) / ScreenScale, (bbox.max_pt.y - bbox.min_pt.y) / ScreenScale),
            GLView
        );
        
        [elements addObject: element];
        [element release];
    }
    
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

void iosGLRenderSupport::doRequestRedraw()
{
    needsDrawingGL = YES;
}

void iosGLRenderSupport::resolvePictureDataAsBitmap(unicode_string url, NSData * data)
{
    UIImage * image = [[UIImage alloc] initWithData: data];
    if (image == nil) {
        resolvePictureError(url, NS2UNICODE(@"Cannot decode"));
        return;
    }
    
    CGImageRef cg_image = image.CGImage;
    GLuint width = CGImageGetWidth(cg_image);
    GLuint height = CGImageGetHeight(cg_image);

    GLTextureBitmap::Ptr bmp(new GLTextureBitmap(ivec2(width, height), GL_RGBA));
    void * imageData = bmp->getDataPtr();
    
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef imgcontext = CGBitmapContextCreate( imageData, width, height, 8, 4 * width, cs, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage( imgcontext, CGRectMake( 0, 0, width, height ), cg_image );
    
    CGColorSpaceRelease(cs);
    CGContextRelease(imgcontext);
    [image release];
    
    resolvePicture(url, bmp);
}

bool iosGLRenderSupport::loadPicture(unicode_string url, HttpRequest::T_SMap& headers, bool cache)
{
    return this->loadPicture(url, cache);
}

bool iosGLRenderSupport::loadPicture(unicode_string url, bool /*cache*/)
{
    NSString * ns_url =  UNICODE2NS(url);
    
    /*if ([[NSBundle mainBundle] pathForResource: ns_url ofType: nil] != nil) {
        resolvePictureDataAsBitmap(url, [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource: ns_url ofType: nil]]);
        return true;
    }*/
    

#define TRY_CACHED_OR_DOWNLAOD(path, on_error_fn) if ([URLLoader isCached: path]) \
        resolvePictureDataAsBitmap(url, [URLLoader cacheDataForURL: path] ); \
    else { \
        URLLoader * loader = [[URLLoader alloc] initWithURL: path onSuccess: on_success onError: on_error_fn onProgress: ^(float) {} onlyCache: false]; \
        [loader start]; \
    }
    
    
    if ([ns_url hasPrefix: @"data:"]) {
        NSURL *dataUrl = [NSURL URLWithString:ns_url];
        NSData *imageData = [NSData dataWithContentsOfURL:dataUrl];
        resolvePictureDataAsBitmap(url, imageData);
        return true;
    }
    
    if ([ns_url hasPrefix: @"file://"]) {
        NSString* imagePath = [ns_url substringWithRange:NSMakeRange(7, [ns_url length]-7)];
        NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
        resolvePictureDataAsBitmap(url, imageData);
        return true;
    }
    
    void (^on_success)(NSData * data) = ^void(NSData * data) {
        resolvePictureDataAsBitmap(url, data);
    };
    void (^on_error)(void)= ^void(void) { resolvePictureError(url, NS2UNICODE(@"Cannot download from the network")); };
    void (^on_error_png)(void) = ^void(void) { TRY_CACHED_OR_DOWNLAOD(ns_url, on_error); };
    
    if ([ns_url hasSuffix: @".swf"]) {
        NSString * png_url = [[ns_url stringByDeletingPathExtension] stringByAppendingPathExtension: @"png"];
        TRY_CACHED_OR_DOWNLAOD(png_url, on_error_png);
    } else {
        TRY_CACHED_OR_DOWNLAOD(ns_url, on_error);
    }
    
    return true;
}

void iosGLRenderSupport::abortPictureLoading(unicode_string url) {
    [URLLoader cancelPendingRequest: UNICODE2NS(url)];
}

void iosGLRenderSupport::OnHostEvent(HostEvent event)
{
    GLRenderSupport::OnHostEvent(event);
    
    if (event == HostEventError) {
        NSString * msg = [NSString stringWithUTF8String: getFlowRunner()->GetLastErrorMsg().c_str()];
        NSString * info = [NSString stringWithUTF8String: getFlowRunner()->GetLastErrorInfo().c_str()];
        NSString * text = [NSString stringWithFormat: @"%@\n-------------------------\n%@", msg, info];
        UIAlertView * alert_view = [[UIAlertView alloc] initWithTitle: @"Flow Error" message: text delegate: nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alert_view show];
        [alert_view release];
    }
}

CGPoint iosGLRenderSupport::fixIphoneXMousePoint(int x, int y) {
    return CGPointMake(x - GLView.frame.origin.x, y - GLView.frame.origin.y);
}

void iosGLRenderSupport::mouseMoveEvent(int x, int y)
{
    CGPoint mousePoint = fixIphoneXMousePoint(x, y);
    dispatchMouseEvent(FlowMouseMove, mousePoint.x * ScreenScale, mousePoint.y * ScreenScale);
}

void iosGLRenderSupport::mousePressEvent(int x, int y)
{
    CGPoint mousePoint = fixIphoneXMousePoint(x, y);
    dispatchMouseEvent(FlowMouseDown, mousePoint.x * ScreenScale, mousePoint.y * ScreenScale);
}

void iosGLRenderSupport::mouseReleaseEvent(int x, int y)
{
    CGPoint mousePoint = fixIphoneXMousePoint(x, y);
    dispatchMouseEvent(FlowMouseUp, mousePoint.x * ScreenScale, mousePoint.y * ScreenScale);
}

// Return key on the screen keyboard for one-line textbox
bool iosGLRenderSupport::returnKeyEventFromTextClip(GLTextClip* clip) {
    FlowKeyEvent keyDown = FlowKeyEvent(FlowKeyDown, NS2UNICODE(@"enter"), false, false, false, false, FlowKey_Enter);
    
//    if (clip->keyEventFilteredByFlowFilters(keyDown)) {
    dispatchFlowKeyEvent(keyDown);
    
    FlowKeyEvent keyUp = keyDown;
    keyUp.event = FlowKeyUp;
        
//        if (clip->keyEventFilteredByFlowFilters(keyUp)) {
    dispatchFlowKeyEvent(keyUp);
    
    return NO;
//        }
//    }
    
//    return NO;
}

void iosGLRenderSupport::doOpenUrl(unicode_string url, unicode_string target)
{
    NSString * ns_url = UNICODE2NS(url);
    if ([ns_url rangeOfString: @"flowrunner.html"].location != NSNotFound) { // Logout
        [[UIApplication sharedApplication].delegate restartRunner];
    } else {
        if ( [ns_url rangeOfString: @":"].location == NSNotFound && [ns_url rangeOfString: @"%3A"].location != NSNotFound ) {
            // A patch for fully encoded URLs
            [[UIApplication sharedApplication] openURL: [NSURL URLWithString: [ns_url stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding]]];
        } else {
            // Do not escape URL string (as in flash target)
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString: [ns_url stringByReplacingOccurrencesOfString: @" " withString: @"%20"]]];
        }
    }
}

bool iosGLRenderSupport::doCreateNativeWidget(GLClip* clip, bool neww)
{
    UIView* &widget = NativeWidgets[clip];
    CGRect rect;
    bool hidden = true, ok = false;
    
    if (widget) {
        NativeWidgetClips.erase(widget);
        
        if (neww) {
            [widget release];
            widget = nil;
        } else {
            rect = widget.frame;
            hidden = widget.hidden;
        }
    }
    
    if (GLTextClip* text_clip = flow_native_cast<GLTextClip>(clip))
        ok = doCreateTextWidget(widget, text_clip);
    else if (GLVideoClip* video_clip = flow_native_cast<GLVideoClip>(clip))
       ok = doCreateVideoWidget(widget, video_clip);
	else if (GLWebClip* web_clip = flow_native_cast<GLWebClip>(clip))
		ok = doCreateWebWidget(widget, web_clip);
    
    if (widget) {
        NativeWidgetClips[widget] = clip;
        
        if (!hidden)
            widget.frame = rect;
        
        widget.hidden = hidden;
    }
    
    return ok;
}

void iosGLRenderSupport::doDestroyNativeWidget(GLClip *clip)
{
    UIView *widget = NativeWidgets[clip];
    
    if (widget) {
        NativeWidgetClips.erase(widget);
        NativeWidgets.erase(clip);
        
        if (flow_native_cast<GLVideoClip>(clip)) {
            [widget removeFromSuperview];
            
            FlowVideoPlayerControllers.erase(widget);
        } else if (flow_native_cast<GLTextClip>(clip)) {
            widget.hidden = YES;
            [widget removeFromSuperview];
            [widget autorelease];
        } else if (flow_native_cast<GLWebClip>(clip)) {
            [commonWebViewDelegate removeInnerDomainsForWebView: widget];
            [widget removeFromSuperview];
            LogI(@"WebView destroyed");
            [widget release];
        } else {
            [widget removeFromSuperview];
            [widget release];
        }
    }
}

void iosGLRenderSupport::doReshapeNativeWidget(GLClip* clip, const GLBoundingBox &bbox, float scale, float alpha)
{
    UIView* widget = NativeWidgets[clip];
    
    if ([FlowAVPlayerView useOpenGLVideo] && [widget isKindOfClass: [FlowVideoPlayerView class]]) return;
   
    if (widget) {
        bool wasVisible = !widget.hidden;
        
        if (bbox.isEmpty || alpha <= 0.0f)
        {
            widget.hidden = true;
            if ([widget isKindOfClass: WKWebView.class]) {
                widget.frame = CGRectMake(0.0, 0.0, 0.0, 0.0);
            }
        }
        else 
        {
            GLBoundingBox box = bbox;
            box.roundOut();
            
            vec2 size = box.size();
            widget.frame = [GLView convertRect: CGRectMake(bbox.min_pt.x / ScreenScale, bbox.min_pt.y / ScreenScale,
                            size.x / ScreenScale, size.y / ScreenScale) toView: WidgetsView];
            
            widget.hidden = false;
            
            // Handle masking
            GLBoundingBox mask_bbox = clip->getGlobalMaskBBox();
            if (!mask_bbox.isEmpty) {
                CAShapeLayer* mask_layer = [[CAShapeLayer alloc] init];
                CGRect global_mask_rect = CGRectMake(mask_bbox.min_pt.x / ScreenScale, mask_bbox.min_pt.y / ScreenScale, mask_bbox.size().x / ScreenScale, mask_bbox.size().y / ScreenScale);
                CGRect mask_rect = [widget convertRect: global_mask_rect fromView: GLView];
                CGPathRef path = CGPathCreateWithRect(mask_rect, NULL);
                mask_layer.path = path;
                CGPathRelease(path);
                widget.layer.mask = mask_layer;
            }
            
            if (GLTextClip* text_clip = flow_native_cast<GLTextClip>(clip)) {
                // Use system font instead.
                // NSString * font_name = [NSString stringWithUTF8String: encodeUtf8(text_clip->getFontName()).c_str()];
                float font_size = scale * text_clip->getFontSize() / ScreenScale;
                //text_clip->getBackgroundColor()
                
                FlowUITextView* text_view = (FlowUITextView*)widget;
                UIFont* f = [UIFont systemFontOfSize: font_size];
                [text_view setFont: f];
                vec4 text_color = text_clip->getFontColor();
                text_view.textColor = [UIColor colorWithRed: text_color.r green: text_color.g blue: text_color.b alpha: text_color.a];
                
                if (!wasVisible) {
                    // setAccessAttributes is done after setFocus. Deffer to set KB type.
                    if (text_clip->inputType() == "email") {
                        [text_view setKeyboardType: UIKeyboardTypeEmailAddress];
                    }
                    if (text_clip->inputType() == "url") {
                         [text_view setKeyboardType: UIKeyboardTypeURL];
                    }
                    if (text_clip->inputType() == "tel") {
                         [text_view setKeyboardType: UIKeyboardTypePhonePad];
                    }
                    if (text_clip->inputType() == "search") {
                         [text_view setKeyboardType: UIKeyboardTypeWebSearch];
                    }
                    if (text_clip->inputType() == "text") {
                         [text_view setKeyboardType: UIKeyboardTypeDefault];
                    }
                    if (text_clip->inputType() == "number") {
                         [text_view setKeyboardType: UIKeyboardTypeNumbersAndPunctuation];
                    }
                    [text_view becomeFirstResponder];
                }
            }
        }
    }
}

void iosGLRenderSupport::onTextClipStateChanged(GLTextClip* textClip)
{
    FlowUITextView* textView = (FlowUITextView*)NativeWidgets[textClip];
    
    NSString* text = UNICODE2NS( textClip->getPlainText() );
    
    // Set alignment
    GLTextClip::Alignment align = textClip->getAlignment();
    switch (align) {
        case GLTextClip::AlignCenter:
            [textView setTextAlignment:NSTextAlignmentCenter];
            break;
        case GLTextClip::AlignLeft:
            [textView setTextAlignment:NSTextAlignmentLeft];
            break;
        case GLTextClip::AlignRight:
            [textView setTextAlignment:NSTextAlignmentRight];
            break;
            
        default:
            break;
    }
    
    textView.realText = text;
    if (textClip->isPassword()) {
        text = [[NSString string] stringByPaddingToLength:[text length] withString:@"\u2022" startingAtIndex:0];
    }
    
    // Set text with respect for interline spacing
    NSMutableParagraphStyle* paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = textClip->getInterlineSpacing();
    NSDictionary* attribute = @{NSParagraphStyleAttributeName: paragraphStyle };
    textView.attributedText =
    [[NSAttributedString alloc] initWithString: text attributes: attribute];
    
    float fontSize = textClip->getGlobalTransform().getScale() * textClip->getFontSize() / ScreenScale;
    UIFont* font = [UIFont systemFontOfSize: fontSize];
    [textView setFont: font];
    
    vec4 textColor = textClip->getFontColor();
    textView.textColor = [UIColor colorWithRed: textColor.r green: textColor.g blue: textColor.b alpha: textColor.a];
    
    // Remove margins from textView
    textView.textContainer.lineFragmentPadding = 0;
    textView.textContainerInset = UIEdgeInsetsZero;
    
    // Set colors
    vec4 clr = textClip->getCursorColor();
    UIColor* cursorColor =
    [UIColor colorWithRed: clr[0] green: clr[1] blue: clr[2] alpha: clr[3]];
    textView.tintColor = cursorColor;
    textView.backgroundColor = [UIColor clearColor];
    
    // Set readonly
    if (textClip->isReadonly())
        textView.editable = NO;
    
    // Supress autocorection
    [textView setAutocorrectionType: UITextAutocorrectionTypeNo];
    [textView setAutocapitalizationType: UITextAutocapitalizationTypeNone];
    
    // Set selection
    int selStart = textClip->getSelectionStart();
    int selEnd = textClip->getSelectionEnd();
    
    if (selStart < 0) return;
    
    UITextPosition* selStartPosition = [textView positionFromPosition:textView.beginningOfDocument offset: selStart];
    UITextPosition* selEndPosition = [textView positionFromPosition:textView.beginningOfDocument offset: selEnd];
    UITextRange* selRange = [textView textRangeFromPosition:selStartPosition toPosition:selEndPosition];
    
    [textView setSelectedTextRange: selRange];
}

bool iosGLRenderSupport::doCreateTextWidget(UIView* &widget, GLTextClip* textClip)
{
    if ( ![ widget isKindOfClass: [FlowUITextView class] ] ) {
        [ widget release ];
        FlowUITextView* textView = widget = [[FlowUITextView alloc] initWithClip: textClip];
        textView.delegate = commonTextFieldDelegate;
        
        [WidgetsView addSubview: textView.scrollHorizontalView];
    }
    
    onTextClipStateChanged(textClip);
    
    return true;
}

void iosGLRenderSupport::textViewChanged(FlowUITextView* textView, bool textChanged)
{
    GLClip* owner = NativeWidgetClips[textView];

    NSRange selRange = textView.selectedRange;
    if (selRange.location == NSNotFound) selRange.location = 0;
    dispatchEditStateUpdate(owner, (int)selRange.location, (int)selRange.location, (int)(selRange.location + selRange.length), textChanged, NS2UNICODE(textView.realText));
}

bool iosGLRenderSupport::doCreateVideoWidget(UIView* &widget, GLVideoClip* video_clip)
{
    NSString * ns_name = UNICODE2NS( video_clip->getName() );
    
    if ( [ns_name hasSuffix: @".flv"] )
    {
        NSRange ext_range = NSMakeRange([ns_name length] - 3, 3);
        ns_name = [ns_name stringByReplacingCharactersInRange: ext_range withString: @"mp4"];
    }
    
    NSURL * videoURL = nil;
    
    // Is there a resource for video
    if ([[NSFileManager defaultManager]  fileExistsAtPath: [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: ns_name] ])
        videoURL = [[NSBundle mainBundle]
                   URLForResource: [ns_name stringByDeletingPathExtension] withExtension: [ns_name pathExtension] ];
    // Check for the file is in the local filesystem (handy for testing with the simulator)
    else if ([[NSFileManager defaultManager] fileExistsAtPath:ns_name])
        videoURL = [NSURL fileURLWithPath:ns_name];
    else if ([URLLoader isCached: ns_name])
        videoURL = [[NSURL fileURLWithPath: [URLLoader cachePathForURL: ns_name ] isDirectory: NO] retain];
    else
        videoURL = [NSURL URLWithString: [ns_name stringByAddingPercentEscapesUsingEncoding: NSASCIIStringEncoding] relativeToURL: [URLLoader getBaseURL]];
    
    LogI(@"Will create player for video %@", [videoURL absoluteString]);
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Generic" bundle: nil];
    FlowVideoPlayerController *vc = (FlowVideoPlayerController*)[storyboard instantiateViewControllerWithIdentifier:@"FlowVideoPlayerController"];
    
    if (video_clip->useMediaStream()) {
    #ifdef FLOW_MEDIASTREAM
        FlowNativeMediaStream *mediaStream = getFlowRunner()->GetNative<FlowNativeMediaStream*>(getFlowRunner()->LookupRoot(video_clip->getMediaStreamId()));
        FlowRTCVideoPreview *view = [[FlowRTCVideoPreview alloc] init];
        __block FlowRTCVideoPreview *bView = view;
        [view loadVideoFromRTCMediaStream:mediaStream onSuccess:^(int width, int height) {
            dispatchVideoSize(video_clip, width, height);
            dispatchVideoDuration(video_clip, 0);
            if ([FlowAVPlayerView useOpenGLVideo]) {
                GLTextureBitmap::Ptr texture_bitmap(new GLTextureBitmap(video_clip->getSize(), GL_RGBA));
                video_clip->setVideoTextureImage(texture_bitmap);
                [bView setTargetVideoTexture: texture_bitmap];
                bView.hidden = YES;
            }
            dispatchVideoPlayStatus(video_clip, GLVideoClip::PlayStart);
        } onDimensionsChanged:^(int width, int height) {
            dispatchVideoSize(video_clip, width, height);
        } onFrameReady:^{
            needsDrawingGL = YES;
        }];
        widget = view;
    #endif
    } else {
        FlowAVPlayerView *view = [[FlowAVPlayerView alloc] init];

        view.looping = video_clip->isLooping();
        
        __block FlowAVPlayerView *bView = view;
        __block FlowVideoPlayerController *bController = vc;
#define CHECK_CLIP_ALIVE(c) if (NativeWidgets.find(c) == NativeWidgets.end()) return;
        [view loadVideo: videoURL
            onResolutionReceived: ^void(float width, float height) {
               CHECK_CLIP_ALIVE(video_clip); // It looks like loadValuesAsynchronouslyForKeys cannot be cancelled so check
               // clip is still actual here
               dispatchVideoSize(video_clip, width, height);
               
               if ([FlowAVPlayerView useOpenGLVideo]) {
                   GLTextureBitmap::Ptr texture_bitmap(new GLTextureBitmap(video_clip->getSize(), GL_RGBA));
                   video_clip->setVideoTextureImage(texture_bitmap);
                   [bView setTargetVideoTexture: texture_bitmap];
                   bView.hidden = YES;
               }
            }
            onSuccess: ^void(float duration) {
              CHECK_CLIP_ALIVE(video_clip); // It looks like loadValuesAsynchronouslyForKeys cannot be cancelled so check
              // clip is still actual here
              dispatchVideoDuration(video_clip, duration * 1000);
              dispatchVideoPlayStatus(video_clip, GLVideoClip::PlayStart);
              
              if (video_clip->isPlaying()) {
                  [bView playVideo];
              } else {
                  [bView pauseVideo];
                  [vc showPlayButton];
              }
              
            }
            onError: ^void() {
                CHECK_CLIP_ALIVE(video_clip);
                video_clip->notifyNotFound();
            }
            onFrameReady: ^void(CMTime time) {
               needsDrawingGL = YES;
               dispatchVideoPosition(video_clip, CMTimeGetSeconds(time) * 1000);
            }
         ];
#undef CHECK_CLIP_ALIVE
        
        view.OnUserResume = ^void() {
            dispatchVideoPlayStatus(video_clip, GLVideoClip::UserResume);
            if (![FlowAVPlayerView useOpenGLVideo]) {
                [bController hidePlayButton];
                [bView playVideo];
            }
        };
        
        view.OnUserPause = ^void() {
            dispatchVideoPlayStatus(video_clip, GLVideoClip::UserPause);
            if (![FlowAVPlayerView useOpenGLVideo]) {
                [bController showPlayButton];
                [bView pauseVideo];
            }
        };
        
        view.OnPlayEnd = ^void() {
            dispatchVideoPlayStatus(video_clip, GLVideoClip::PlayEnd);
            if (![FlowAVPlayerView useOpenGLVideo]) {
                [bController showPlayButton];
                [bView pauseVideo];
            }
            bView.looping = video_clip->isLooping();
        };
        
        widget = view;
    }
    
    FlowVideoPlayerControllers[widget] = vc;
    [vc.view addSubview:widget];
    [WidgetsView addSubview:widget];
    
    return true;
}

void iosGLRenderSupport::doUpdateVideoPlay(GLVideoClip *video_clip)
{
    FlowVideoPlayerView* widget = (FlowVideoPlayerView*)NativeWidgets[video_clip];
    
    if (video_clip->isPlaying())
        [widget playVideo];
    else
        [widget pauseVideo];
}

void iosGLRenderSupport::doUpdateVideoPosition(GLVideoClip *video_clip)
{
    FlowVideoPlayerView* widget = (FlowVideoPlayerView*)NativeWidgets[video_clip];
    [widget seekTo: video_clip->getPosition()];
}

void iosGLRenderSupport::doUpdateVideoVolume(GLVideoClip *video_clip)
{
    FlowVideoPlayerView* widget = (FlowVideoPlayerView*)NativeWidgets[video_clip];
    
    [widget setVolume:video_clip->getVolume()];
}

void iosGLRenderSupport::doUpdateVideoPlaybackRate(GLVideoClip *video_clip)
{
    FlowVideoPlayerView* widget = (FlowVideoPlayerView*)NativeWidgets[video_clip];
    
    [widget setRate:(float)video_clip->getPlaybackRate()];
}

bool iosGLRenderSupport::doCreateWebWidget(UIView *&widget, GLWebClip *web_clip) {
    [widget release];
    
    NSString * ns_url = UNICODE2NS( web_clip->getUrl() );
    
    NSURL* baseResourceUrl = [NSURL fileURLWithPath:applicationLibraryDirectory()];
    NSURL* baseResourceWwwUrl = [baseResourceUrl URLByAppendingPathComponent:@"www"];
    bool isLocalFile = [ns_url hasPrefix:@"./"];
    NSURL * rq_url = nil;
    if (isLocalFile)
        // File should be in the app bundle on the www folder
        rq_url = [NSURL URLWithString:ns_url relativeToURL:baseResourceWwwUrl];
    else if (![URLLoader hasConnection])
        rq_url = [NSURL URLWithString:ns_url];
    else
        rq_url = [NSURL URLWithString: ns_url relativeToURL: [URLLoader getBaseURL]];

    LogI(@"Create WKWebView for URL %@", rq_url);
    WKWebView * web_view = [[WKWebView alloc] init];
    web_view.navigationDelegate = commonWebViewDelegate;
    web_view.configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    web_view.configuration.allowsInlineMediaPlayback = YES; // Doesn't work for WKWebView - use video playsinline attribute only
    web_view.configuration.ignoresViewportScaleLimits = YES;
    [web_view.configuration.preferences setValue:@YES forKey:@"allowFileAccessFromFileURLs"];
    [web_view.configuration.userContentController addScriptMessageHandler:[[FlowWKMessageHandler alloc] initWithOwner:this] name:@"flow"];
    NSString* custom_ua = [[NSUserDefaults standardUserDefaults] objectForKey:@"FlowUserAgent"];
    web_view.customUserAgent = custom_ua;
    widget = web_view;
    
    NSDictionary * user_info = @{ @"webView" : widget, @"domain" : (rq_url && rq_url.host)? rq_url.host: @"" };
    [[NSNotificationCenter defaultCenter] postNotificationName: @"addInnerDomain" object: nil userInfo: user_info];
    [commonWebViewDelegate addInnerDomain: rq_url.host forWebView: widget]; // Add the main frame
    
    NSString* path = [[[baseResourceWwwUrl URLByDeletingLastPathComponent] path] stringByAppendingString:@"/flow-local-store/images/pwa_nnc_logo.png"];
    
    if (isLocalFile) {
        [web_view loadFileURL:rq_url allowingReadAccessToURL:[baseResourceWwwUrl URLByDeletingLastPathComponent]];
    } else {
        [web_view loadRequest:[NSURLRequest requestWithURL:rq_url]];
    }
    [WidgetsView addSubview:widget];
    
    return true;
}

StackSlot iosGLRenderSupport::webClipHostCall(GLWebClip *clip, const unicode_string &name, const StackSlot &args) {
    std::stringstream ss;
    getFlowRunner()->PrintData(ss, args);
    NSString * args_list = [NSString stringWithUTF8String: ss.str().c_str()];
    args_list = [args_list substringWithRange: NSMakeRange(1, [args_list length] - 2)];
    
    NSString * fn_str = [NSString stringWithFormat: @"%@(%@)", UNICODE2NS(name), args_list];
    
    UIView * view = (UIView*)NativeWidgets[clip];
    
    WKWebView * web_view = (WKWebView*)view;
    [web_view evaluateJavaScript: fn_str completionHandler: nil];
    RETVOID; // Cannnot get return value synchroneously
}

StackSlot iosGLRenderSupport::setWebClipZoomable(GLWebClip *clip, const StackSlot &args) {
    UIView * view = (UIView*)NativeWidgets[clip];
    bool zoomable = args.GetBool();
    
    WKWebView * web_view = (WKWebView*)view;
    LogI(@"Set WKWebView scalable to %s with current zoom %f", zoomable ? "YES" : "NO", web_view.scrollView.zoomScale);
    if (zoomable) {
        web_view.scrollView.delegate = nil;
    } else {
        web_view.scrollView.delegate = commonWebScrollViewDelegate;
    }

    RETVOID;
}

StackSlot iosGLRenderSupport::setWebClipDomains(GLWebClip *clip, const StackSlot &domains) {
    RUNNER_VAR = getFlowRunner();
    UIView * view = (UIView*)NativeWidgets[clip];
    
    int length = RUNNER->GetArraySize(domains);
    for (int i = 0; i < length; i++) {
        NSString* domain = UNICODE2NS( RUNNER->GetString( RUNNER->GetArraySlot(domains, i)));
        [commonWebViewDelegate addInnerDomain:domain forWebView:view];
    }
    
    RETVOID;
}

StackSlot iosGLRenderSupport::webClipEvalJS(GLWebClip* clip, const unicode_string& js, StackSlot& cb) {
    RUNNER_VAR = getFlowRunner();
    int cb_id = RUNNER->RegisterRoot(cb);
    
    UIView * view = (UIView*)NativeWidgets[clip];
    WKWebView * web_view = (WKWebView*)view;
    [web_view evaluateJavaScript: UNICODE2NS(js) completionHandler: ^void(id o, NSError * e) {
        RUNNER_VAR = getFlowRunner();
        WITH_RUNNER_LOCK_DEFERRED(RUNNER);
        RUNNER->EvalFunction(RUNNER->LookupRoot(cb_id), 1, RUNNER->AllocateString(NS2UNICODE((NSString*)o)));
        RUNNER->ReleaseRoot(cb_id);
    }];
    
    RETVOID;
}

void iosGLRenderSupport::callFlowFromJS(UIView * web_view, NSString * absolute_url) {
    GLWebClip *owner = flow_native_cast<GLWebClip>(NativeWidgetClips[web_view]);
    
    if (NULL != owner) {
        NSLog(@"Call from JS to Flow: %@", [absolute_url stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]);
        NSArray *args = [[absolute_url stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] componentsSeparatedByString:@":::"];
        ByteCodeRunner * RUNNER = getFlowRunner();
        RUNNER_DefSlots1(arr);
        arr = RUNNER->AllocateArray([args count] - 1);
        for (int i = 0; i < [args count] - 1; ++i) {
            RUNNER->SetArraySlot(arr, i, jsstring2stackslot([args objectAtIndex: i + 1]));
        }
        
        dispatchPageCall(owner, arr);
    }
}

StackSlot iosGLRenderSupport::jsstring2stackslot(NSString * str) {
    // Note : for array it receives empty string from js
    NSScanner * scaner = [NSScanner scannerWithString: str];
    double double_value;
    if (str == nil) {
        return StackSlot::MakeVoid();
    } if ([scaner scanDouble: &double_value]) {
        return StackSlot::MakeDouble(double_value);
    } else if ([str isEqualToString: @"true"]) {
        return StackSlot::MakeBool(1);
    } else if ([str isEqualToString: @"false"]) {
        return StackSlot::MakeBool(0);
    } else {
        return getFlowRunner()->AllocateString([str cStringUsingEncoding: NSUTF8StringEncoding]);
    }
}

void iosGLRenderSupport::adjustGlobalScale(CGPoint old, CGPoint cur, CGFloat scale)
{
    if (hasFullScreenTarget) return; // Disable zoomming for "fullscreen" mode
    GLRenderSupport::adjustGlobalScale(cur.x - old.x, cur.y - old.y, cur.x, cur.y, scale);
}

void iosGLRenderSupport::setFullScreenTargetRect(float x, float y, float width, float height)
{
    // TO DO: is it used?
    // Yes it is
    if ( UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]) )
    {
        FullScreenTargetCenterX = (x + width / 2) / targetRenderbufferWidth;
        FullScreenTargetCenterY = (y + height / 2) / targetRenderbufferHeight;
        FullScreenTargetScaleFactor = min(targetRenderbufferWidth / width, targetRenderbufferHeight / height);
    }
    else
    {
        FullScreenTargetCenterX = (x + width / 2) / targetRenderbufferWidth;
        FullScreenTargetCenterY = (y + height / 2) / targetRenderbufferHeight;
        FullScreenTargetScaleFactor = min(targetRenderbufferHeight / height, targetRenderbufferWidth / width);
    }
}

NativeFunction *iosGLRenderSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "Native."
    
    TRY_USE_NATIVE_METHOD(iosGLRenderSupport, setClipboard, 1);
    TRY_USE_NATIVE_METHOD(iosGLRenderSupport, hostCall, 2);
    
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "RenderSupport."

    TRY_USE_NATIVE_METHOD(iosGLRenderSupport, setFullScreenRectangle, 4);
    TRY_USE_NATIVE_METHOD(iosGLRenderSupport, isFullScreen, 0);
    TRY_USE_NATIVE_METHOD(iosGLRenderSupport, onFullScreen, 1);
    TRY_USE_NATIVE_METHOD(iosGLRenderSupport, setStatusBarVisible, 1);
    TRY_USE_NATIVE_METHOD(iosGLRenderSupport, setStatusBarIconsTheme, 1);
    TRY_USE_NATIVE_METHOD(iosGLRenderSupport, setStatusBarColor, 1);
    TRY_USE_NATIVE_METHOD(iosGLRenderSupport, setBackgroundColor, 1);
    
    return GLRenderSupport::MakeNativeFunction(name, num_args);
}

StackSlot iosGLRenderSupport::setFullScreenRectangle(RUNNER_ARGS)
{
    RUNNER_PopArgs4(x, y, width, height);
    RUNNER_CheckTag4(TDouble, x, y, width, height);
    
    setFullScreenTargetRect( x.GetDouble(), y.GetDouble(), width.GetDouble(), height.GetDouble() );
    
    RETVOID;
}

StackSlot iosGLRenderSupport::isFullScreen(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeBool(hasFullScreenTarget);
}

StackSlot iosGLRenderSupport::onFullScreen(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);
    //RUNNER->EvalFunction(cb, 1, StackSlot::MakeBool(true)); // It is already full screen 
    return RUNNER->AllocateConstClosure(0, StackSlot::MakeVoid());
}

StackSlot iosGLRenderSupport::setClipboard(RUNNER_ARGS)
{   
    RUNNER_PopArgs1(string);
    NSString * ns_string = UNICODE2NS( RUNNER->GetString(string) );
    
    UIPasteboard * pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = ns_string;
    
    RETVOID;
}

StackSlot iosGLRenderSupport::hostCall(RUNNER_ARGS)
{
    RUNNER_PopArgs2(name, args);
    RUNNER_CheckTag1(TString, name);
    RUNNER_CheckTag1(TArray, args);
    
    if ( encodeUtf8(RUNNER->GetString(name)) == "setBrightness" )
    {
        [UIScreen mainScreen].brightness = RUNNER->GetArraySlot(args, 0).GetDouble();
    }
    if ( encodeUtf8(RUNNER->GetString(name)) == "getBrowser" )
	{
    	NSString* code = [DeviceInfo getMachineName];
		return jsstring2stackslot(code);
	}
    if ( encodeUtf8(RUNNER->GetString(name)) == "getSysVersion" )
	{
    	NSString* code = [DeviceInfo getSysVersion];
		return jsstring2stackslot(code);
	}
    
    RETVOID;
}

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0];

StackSlot iosGLRenderSupport::setBackgroundColor(RUNNER_ARGS)
{
    RUNNER_PopArgs1(bgColor);
    RUNNER_CheckTag1(TInt, bgColor);
    
    GLViewController.view.backgroundColor = UIColorFromRGB(bgColor.GetInt());
    
    RETVOID;
}

StackSlot iosGLRenderSupport::setStatusBarColor(RUNNER_ARGS)
{
    RUNNER_PopArgs1(sbColor);
    RUNNER_CheckTag1(TInt, sbColor);
    
    UIColor* color = UIColorFromRGB(sbColor.GetInt());
    [GLViewController setStatusBarColor: color];
    
    RETVOID;
}

StackSlot iosGLRenderSupport::setStatusBarVisible(RUNNER_ARGS)
{
    RUNNER_PopArgs1(visible);
    RUNNER_CheckTag1(TBool, visible);
    
    [GLViewController setStatusBarVisible: visible.GetBool()];
    
    RETVOID;
}

StackSlot iosGLRenderSupport::setStatusBarIconsTheme(RUNNER_ARGS) {
    RUNNER_PopArgs1(light);
    RUNNER_CheckTag1(TBool, light);
    
    [GLViewController setStatusBarIconsTheme: light.GetBool()];
    
    RETVOID;
}

bool iosGLRenderSupport::sendPanGestureEvent(UIGestureRecognizerState state, CGPoint position, CGPoint translation)
{
    bool prevent_default = dispatchGestureEvent(FlowPanEvent, GestureRecognizerState2FlowGestureState(state), position.x * ScreenScale, position.y * ScreenScale,
                                                translation.x * ScreenScale, translation.y * ScreenScale);
    
    if (!prevent_default && isScreenScaled())
        adjustGlobalScale(CGPointMake(position.x - translation.x, position.y - translation.y), position, 1.0f);
    
    return prevent_default;
}

bool iosGLRenderSupport::sendPinchGestureEvent(UIGestureRecognizerState state, CGPoint center, float scale)
{
    return dispatchGestureEvent(FlowPinchEvent, GestureRecognizerState2FlowGestureState(state), center.x * ScreenScale, center.y * ScreenScale, scale, 0.0);
}

bool iosGLRenderSupport::sendSwipeGestureEvent(CGPoint pos, CGPoint vel)
{
    return dispatchGestureEvent(FlowSwipeEvent, FlowGestureStateEnd, pos.x * ScreenScale, pos.y * ScreenScale,
                                vel.x * ScreenScale, vel.y * ScreenScale);
}

void iosGLRenderSupport::doSetInterfaceOrientation(std::string orientation)
{
    static UIDeviceOrientation last_landscape_orientation = UIDeviceOrientationUnknown;
    flowUIOrientation = orientation == "landscape" ? FlowUILandscape : ( orientation == "portrait" ? FlowUIPortrait : FlowUIAuto );
    UIDeviceOrientation current_orientation = [UIDevice currentDevice].orientation;
    UIInterfaceOrientation uiOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    // Force switching to interface orientation.
    // Rotation will be locked by EAGLViewController
    if (flowUIOrientation == FlowUIPortrait) {
        if (UIDeviceOrientationIsLandscape(current_orientation)) last_landscape_orientation = current_orientation;
        [[UIDevice currentDevice] setValue: [NSNumber numberWithInt: UIDeviceOrientationUnknown] forKey: @"orientation"]; // Force layout views
        [[UIDevice currentDevice] setValue: [NSNumber numberWithInt: UIInterfaceOrientationPortrait] forKey: @"orientation"];
    } else if (flowUIOrientation == FlowUILandscape) {
        UIDeviceOrientation target_orientation = (UIDeviceOrientation) ( UIDeviceOrientationIsLandscape(current_orientation) ? current_orientation :
            ( last_landscape_orientation != UIDeviceOrientationUnknown ? last_landscape_orientation :
             // when current orientation is faceUp/Down - follow current UI orientation. When current orientation is portrait - unsure
             (uiOrientation == UIInterfaceOrientationLandscapeRight ? UIDeviceOrientationLandscapeLeft : UIDeviceOrientationLandscapeRight ) ) );
        [[UIDevice currentDevice] setValue: [NSNumber numberWithInt: UIDeviceOrientationUnknown] forKey: @"orientation"];
        [[UIDevice currentDevice] setValue: [NSNumber numberWithInt: target_orientation] forKey: @"orientation"];
    }
}

void iosGLRenderSupport::GetTargetTokens(std::set<std::string>& tokens)
{
    GLRenderSupport::GetTargetTokens(tokens);
    
    tokens.insert("iOS");
    tokens.insert("mobile");
    tokens.insert([[NSString stringWithFormat:@"dpi=%d", DisplayDPI] cStringUsingEncoding: NSUTF8StringEncoding]);
    tokens.insert([[NSString stringWithFormat:@"density=%f", [UIScreen mainScreen].scale] cStringUsingEncoding: NSUTF8StringEncoding]);
    tokens.insert(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad? "iPad" : "iPhone");
    if (![FlowAVPlayerView useOpenGLVideo]) tokens.insert("nativevideo");
}

bool iosGLRenderSupport::loadSystemFont(FontHeader *header, TextFont textFont) {
    header->tile_size = 64;
    header->grid_size = 4;
    header->render_em_size = header->tile_size * 0.875f;
    header->active_tile_size = (header->tile_size - 2) / header->render_em_size;
    
    NSString * font_name = [NSString stringWithUTF8String: textFont.family.c_str()];
    NSString * font_suffix = [NSString stringWithUTF8String: textFont.suffix().c_str()];
    if ([font_suffix length] != 0) {
        font_name = [font_name stringByAppendingFormat:@"-%@", font_suffix];
    }
    
    UIFont * font = [UIFont fontWithName: font_name size: header->render_em_size];
    
    if(![font_name isEqualToString: font.fontName]) return false;
    
    float coeff = 1.0f / header->render_em_size;
    
    CGSize m_size = [@"M" sizeWithAttributes: @{NSFontAttributeName: font}];
    
    header->dist_scale = 1.0f / ( header->tile_size * 0.25 );
    header->ascender = font.ascender * coeff;
    header->descender =  font.descender * coeff;
    header->line_height =  font.lineHeight  * coeff;
    header->max_advance = m_size.width * coeff;
    header->underline_position = 0.0 * coeff;
    header->underline_thickness = 1.0 * coeff;

    return true;
}

bool iosGLRenderSupport::loadSystemGlyph(const FontHeader *header, GlyphHeader *info, StaticBuffer *pixels, TextFont textFont, ucs4_char code) {
    const unsigned scale = 3;
    const unsigned render_size = header->tile_size * scale;
    const unsigned utf16Count = (code > 0xFFFF) + 1;

    UIGraphicsBeginImageContext(CGSizeMake(render_size, render_size));
    CGContextRef context = UIGraphicsGetCurrentContext();
#ifdef DEBUG_GLYPH
    CGContextSetRGBFillColor(context, 0, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(0, 0,render_size, render_size));
    CGContextSaveGState(context);
#endif
    CGContextConcatCTM(context, CGAffineTransformScale(CGAffineTransformMakeTranslation(0, render_size), 1.f, -1.f));
    
    NSMutableAttributedString * atext = [[NSMutableAttributedString alloc] initWithString: [[NSString alloc] initWithBytes:&code
                                                                                            length:4
                                                                                            encoding:NSUTF32LittleEndianStringEncoding]];
    
    NSString * font_name = [NSString stringWithUTF8String: textFont.family.c_str()];
    NSString * font_suffix = [NSString stringWithUTF8String: textFont.suffix().c_str()];
    if ([font_suffix length] != 0) {
        font_name = [font_name stringByAppendingFormat:@"-%@", font_suffix];
    }
    const float font_size = header->render_em_size * scale;
    
    CTFontRef ct_font = CTFontCreateWithName((CFStringRef) font_name, font_size, NULL);
    [atext addAttribute:(NSString*)kCTFontAttributeName value: (id)ct_font range: NSMakeRange(0, utf16Count)];
    [atext addAttribute:(NSString*)kCTForegroundColorAttributeName value: (id)[UIColor colorWithWhite: 1.0f alpha: 1.0f].CGColor range: NSMakeRange(0, utf16Count)];

    // Path for framesetter is bigger than rendersize because CT sometimes does not draw glyphs, although
    // they fits the frame. May be it assumes some margins
    CGRect frame_rect = CGRectMake(0.0, 0.0, render_size * 2.0 , render_size * 2.0);
    
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)atext);
    CGPathRef path = CGPathCreateWithRect(frame_rect, NULL);
    CTFrameRef textFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0,utf16Count), path, NULL);
    CFArrayRef lines = CTFrameGetLines(textFrame);
    
    if (CFArrayGetCount(lines) == 0) {
        LogW(@"Cannot render glyph with coretext. code = %04x", code);
        return false;
    }
    
    CGPoint lineOrigin = CGPointZero;
    CTFrameGetLineOrigins(textFrame, CFRangeMake(0, 1), &lineOrigin);
    
    lineOrigin.y = frame_rect.size.height - lineOrigin.y;
    CFArrayRef runs = CTLineGetGlyphRuns((CTLineRef)CFArrayGetValueAtIndex(lines, 0));
    CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, 0);
    
    CGFloat ascent, descent, leading;
    const double t_width = CTRunGetTypographicBounds(run, CFRangeMake(0, 1), &ascent, &descent, &leading);
    
    CGContextSetTextPosition(context, 0.0, render_size - ascent);
    CTRunDraw(run, context, CFRangeMake(0,1));
    
    CGRect rect = CTRunGetImageBounds(run, context, CFRangeMake(0, 1));
    
    const float coeff = 1.0f / header->render_em_size;
    info->advance = t_width / scale * coeff;
    info->bearing_x = rect.origin.x  / scale * coeff;
    info->bearing_y = - lineOrigin.y / scale * coeff;
    info->size_x = rect.size.width / scale  * coeff;
    info->size_y = rect.size.height / scale * coeff;
    info->field_bearing_x = (rect.origin.x / scale + 1) * coeff;
    info->field_bearing_y = (- lineOrigin.y /scale + 1) * coeff;
    
#ifdef DEBUG_GLYPH
    CGContextRestoreGState(context);
    CGContextSetRGBStrokeColor(context, 1.0, 0.0, 0.0, 1.0);
    CGContextStrokeRect(context, CGRectMake(0.0, 0.0, 10.0, 10.0));
    
    CGContextStrokeRect(context, rect);
    CGContextSetRGBStrokeColor(context, 0.0, 0.0, 1.0, 1.0);
    CGContextStrokeRect(context, CGRectMake(lineOrigin.x, lineOrigin.y, render_size, 2.0));
    
    CGContextSetRGBStrokeColor(context, 0.0, 1.0, 0.0, 1.0);
    CGContextStrokeRect(context, CGRectMake(0, ascent, render_size, descent));
#endif
    
    UIImage * image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGImageRef cgimage = image.CGImage;
    CGDataProviderRef provider = CGImageGetDataProvider(cgimage);
    NSData * data = (id)CGDataProviderCopyData(provider);
    [data autorelease];
    const uint8_t* bytes = (uint8_t*)[data bytes];
    
    bool isGreyGlyph = true;
    for (int i = 0; i < [data length]; i += 4) {
        uint8_t a = bytes[i + 3];
        uint8_t r = bytes[i + 2];
        uint8_t g = bytes[i + 1];
        uint8_t b = bytes[i + 0];
        
        bool equals = a == r && r == g && g == b;
        isGreyGlyph = isGreyGlyph && equals;
    }
    
    info->unicode_char = isGreyGlyph ? 0xD800 : 0x10000;
    
    if (!isGreyGlyph) {
        pixels->allocate([data length]);
        
        memcpy(pixels->writable_data(), bytes, [data length]);
    } else {
        size_t bpr = CGImageGetBytesPerRow(cgimage);
        size_t bpp = CGImageGetBitsPerPixel(cgimage);
        size_t bpc = CGImageGetBitsPerComponent(cgimage);
        size_t bytes_per_pixel = bpp / bpc;
        
        std::vector<uint8_t> bitmap(render_size * render_size, 0);
        uint8_t *buf = bitmap.data();
        
        for (unsigned y = 0; y < render_size; y++) {
            for (unsigned x = 0; x < render_size; x++) {
                unsigned * pi = ((unsigned*)(bytes + (y * bpr + x * bytes_per_pixel)));
                *buf++ = ( * pi != 0 ) ? 255 : 0;
            }
        }

        smoothFontBitmap(header, pixels, bitmap.data(), scale);
    }
    
    return true;
}

int iosGLRenderSupport::doGetNumberOfCameras() {
    return [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceFront]
    + [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceRear];
}

void iosGLRenderSupport::notifyCameraEvent(int code, std::string message, int width, int height) {
    getFlowRunner()->NotifyCameraEvent(code, message, lastCameraAdditionalArgs, width, height);
}

void iosGLRenderSupport::doCameraTakePhoto(int cameraId, std::string additionalInfo, int desiredWidth , int desiredHeight, int compressQuality, std::string fileName, int fitMode) {
    if (([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] == NO)) {
        getFlowRunner()->NotifyCameraEvent(1, "No camera presented on device!", additionalInfo, -1, -1);
        return;
    }
    
    lastCameraAdditionalArgs = additionalInfo;
    commonImagePickerControllerDelegate.flowCameraMode = FlowCameraPhotoMode;
    commonImagePickerControllerDelegate.desiredWidth = desiredWidth;
    commonImagePickerControllerDelegate.desiredHeight = desiredHeight;
    commonImagePickerControllerDelegate.compressQuality = compressQuality;
    commonImagePickerControllerDelegate.desiredFileName = [NSString stringWithUTF8String: fileName.c_str()];
    commonImagePickerControllerDelegate.fitMode = fitMode;
    
    // check cameraId, just to be safe
    if (cameraId >= 1 && [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceFront] == NO) {
        cameraId = 0;
    }
    // Show menu to choose between taking a photo or picking one from the library
    
    typedef void (^ActionHandler)(UIAlertAction * _Nonnull);
    
    ActionHandler takePhotoHandler = ^(UIAlertAction * _Nonnull action) {
        
        // Make sure camera control allow taking single pictures
        NSArray *availableMediaTypes = [UIImagePickerController availableMediaTypesForSourceType: UIImagePickerControllerSourceTypeCamera];
        if (![availableMediaTypes containsObject: (NSString *)kUTTypeImage]) {
            getFlowRunner()->NotifyCameraEvent(1, "kUTTypeImage not available in UIImagePickerController", additionalInfo, -1, -1);
            return;
        }
        
        UIImagePickerController * cameraUI = [[UIImagePickerController alloc] init];
        
        cameraUI.sourceType = UIImagePickerControllerSourceTypeCamera;
        cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeImage, nil];
        cameraUI.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
        cameraUI.cameraDevice = cameraId == 0 ? UIImagePickerControllerCameraDeviceRear : UIImagePickerControllerCameraDeviceFront;
        cameraUI.allowsEditing = NO;
        cameraUI.delegate = commonImagePickerControllerDelegate;
        
        [GLViewController presentViewController: cameraUI animated: YES completion: nil];
    };
    
    ActionHandler pickFromLibraryHandler = ^(UIAlertAction * _Nonnull action) {
        
        // Make sure camera control allow taking single pictures
        NSArray *availableMediaTypes = [UIImagePickerController availableMediaTypesForSourceType: UIImagePickerControllerSourceTypeCamera];
        if (![availableMediaTypes containsObject: (NSString *)kUTTypeImage]) {
            getFlowRunner()->NotifyCameraEvent(1, "kUTTypeImage not available in UIImagePickerController", additionalInfo, -1, -1);
            return;
        }
        
        UIImagePickerController * cameraUI = [[UIImagePickerController alloc] init];
        
        cameraUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeImage, nil];
        cameraUI.allowsEditing = NO;
        cameraUI.delegate = commonImagePickerControllerDelegate;
        
        [GLViewController presentViewController: cameraUI animated: YES completion: nil];
    };
    
    // TODO: This dialog ignores translation! Pass titles via arguments.
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle: @"Take a Photo"
                                          message: @""
                                          preferredStyle: UIAlertControllerStyleActionSheet];
    
    UIAlertAction *pickFromLibraryAction = [UIAlertAction
                                            actionWithTitle: @"Choose from Library"
                                            style: UIAlertActionStyleDefault
                                            handler: pickFromLibraryHandler];
    
    UIAlertAction *takePhotoAction = [UIAlertAction
                                      actionWithTitle: @"Take Photo"
                                      style: UIAlertActionStyleDefault
                                      handler: takePhotoHandler];
    
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle: @"Cancel"
                                   style: UIAlertActionStyleCancel
                                   handler: ^(UIAlertAction * _Nonnull action) {
                                       [alertController dismissViewControllerAnimated: YES completion: nil];
                                   }];
    
    [alertController addAction: takePhotoAction];
    [alertController addAction: pickFromLibraryAction];
    [alertController addAction: cancelAction];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alertController.popoverPresentationController.sourceView = GLView;
        alertController.popoverPresentationController.sourceRect = CGRectMake(GLView.bounds.size.width / 2.0, GLView.bounds.size.height, 1.0, 1.0);
    }
    
    [GLViewController presentViewController: alertController animated: YES completion: nil];
}

void iosGLRenderSupport::notifyCameraEventVideo(int code, std::string message, int width, int height, int duration, int size) {
    getFlowRunner()->NotifyCameraEventVideo(code, message, lastCameraAdditionalArgs, width, height, duration, size);
}

void iosGLRenderSupport::doCameraTakeVideo(int cameraId, std::string additionalInfo, int duration , int size, int quality, std::string fileName) {
    if (([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] == NO)) {
        getFlowRunner()->NotifyCameraEventVideo(1, "No camera presented on device!", additionalInfo, -1, -1, -1, -1);
        return;
    }
    
    lastCameraAdditionalArgs = additionalInfo;
    commonImagePickerControllerDelegate.flowCameraMode = FlowCameraVideoMode;
    commonImagePickerControllerDelegate.duration = duration;
    commonImagePickerControllerDelegate.size = size;
    commonImagePickerControllerDelegate.compressQuality = quality;
    commonImagePickerControllerDelegate.desiredFileName = [NSString stringWithUTF8String: fileName.c_str()];
    
    // check cameraId, just to be safe
    if (cameraId >= 1 && [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceFront] == NO) {
        cameraId = 0;
    }
    // Show menu to choose between taking a video or picking one from the library
    
    typedef void (^ActionHandler)(UIAlertAction * _Nonnull);
    
    ActionHandler takeVideoHandler = ^(UIAlertAction * _Nonnull action) {
        
        // Make sure camera control allow taking video
        NSArray *availableMediaTypes = [UIImagePickerController availableMediaTypesForSourceType: UIImagePickerControllerSourceTypeCamera];
        if (![availableMediaTypes containsObject: (NSString *)kUTTypeMovie]) {
            getFlowRunner()->NotifyCameraEventVideo(1, "kUTTypeMovie not available in UIImagePickerController", additionalInfo, -1, -1, -1, -1);
            return;
        }
        
        UIImagePickerController * cameraUI = [[UIImagePickerController alloc] init];
        
        cameraUI.sourceType = UIImagePickerControllerSourceTypeCamera;
        cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeMovie, nil];
        cameraUI.videoMaximumDuration = (double) duration;
        cameraUI.videoQuality = (quality > 0) ? UIImagePickerControllerQualityTypeHigh : UIImagePickerControllerQualityTypeLow;
        cameraUI.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
        cameraUI.cameraDevice = cameraId == 0 ? UIImagePickerControllerCameraDeviceRear : UIImagePickerControllerCameraDeviceFront;
        cameraUI.allowsEditing = NO;
        cameraUI.delegate = commonImagePickerControllerDelegate;
        
        [GLViewController presentViewController: cameraUI animated: YES completion: nil];
    };
    
    ActionHandler pickFromLibraryHandler = ^(UIAlertAction * _Nonnull action) {
        
        // Make sure camera control allow taking Video
        NSArray *availableMediaTypes = [UIImagePickerController availableMediaTypesForSourceType: UIImagePickerControllerSourceTypeCamera];
        if (![availableMediaTypes containsObject: (NSString *)kUTTypeMovie]) {
            getFlowRunner()->NotifyCameraEventVideo(1, "kUTTypeMovie not available in UIImagePickerController", additionalInfo, -1, -1, -1, -1);
            return;
        }
        
        UIImagePickerController * cameraUI = [[UIImagePickerController alloc] init];
        
        cameraUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeMovie, nil];
        cameraUI.allowsEditing = NO;
        cameraUI.delegate = commonImagePickerControllerDelegate;
        
        [GLViewController presentViewController: cameraUI animated: YES completion: nil];
    };
    
    // TODO: This dialog ignores translation! Pass titles via arguments.
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle: @"Take a Video"
                                          message: @""
                                          preferredStyle: UIAlertControllerStyleActionSheet];
    
    UIAlertAction *pickFromLibraryAction = [UIAlertAction
                                            actionWithTitle: @"Choose from Library"
                                            style: UIAlertActionStyleDefault
                                            handler: pickFromLibraryHandler];
    
    UIAlertAction *takeVideoAction = [UIAlertAction
                                      actionWithTitle: @"Take Video"
                                      style: UIAlertActionStyleDefault
                                      handler: takeVideoHandler];
    
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle: @"Cancel"
                                   style: UIAlertActionStyleCancel
                                   handler: ^(UIAlertAction * _Nonnull action) {
                                       [alertController dismissViewControllerAnimated: YES completion: nil];
                                   }];
    
    [alertController addAction: takeVideoAction];
    [alertController addAction: pickFromLibraryAction];
    [alertController addAction: cancelAction];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alertController.popoverPresentationController.sourceView = GLView;
        alertController.popoverPresentationController.sourceRect = CGRectMake(GLView.bounds.size.width / 2.0, GLView.bounds.size.height, 1.0, 1.0);
    }
    
    [GLViewController presentViewController: alertController animated: YES completion: nil];
}

void iosGLRenderSupport::notifyCameraEventAudio(int code, std::string message, int duration, int size) {
    getFlowRunner()->NotifyCameraEventAudio(code, message, lastCameraAdditionalArgs, duration, size);
}

void iosGLRenderSupport::dispatchKeyboardHeight(double height) {
    GLRenderSupport::dispatchVirtualKeyboardCallbacks(height);
}

bool iosGLRenderSupport::isKeyboardListenersAttached() {
    return GLRenderSupport::isVirtualKeyboardListenerAttached();
}


void iosGLRenderSupport::doStartRecordAudio(std::string additionalInfo, std::string fileName, int duration) {
    
    if (!commonAudioRecordControllerDelegate.audioRecorder.isRecording) {
        lastCameraAdditionalArgs = additionalInfo;
        commonAudioRecordControllerDelegate.duration = duration;
        commonAudioRecordControllerDelegate.desiredFileName = [NSString stringWithUTF8String: fileName.c_str()];


        NSMutableDictionary * recordSettings = [[NSMutableDictionary alloc] init];
        [recordSettings setValue: [NSNumber numberWithFloat: 44100.0f] forKey: AVSampleRateKey];
        [recordSettings setValue: [NSNumber numberWithInt: 2] forKey: AVNumberOfChannelsKey];
        [recordSettings setValue: [NSNumber numberWithInt: 16] forKey: AVLinearPCMBitDepthKey];
        [recordSettings setValue: [NSNumber numberWithBool: NO] forKey: AVLinearPCMIsBigEndianKey];
        [recordSettings setValue: [NSNumber numberWithInt: kAudioFormatMPEG4AAC] forKey: AVFormatIDKey];
        [recordSettings setValue: [NSNumber numberWithBool: NO] forKey: AVLinearPCMIsFloatKey];

        NSError * err = nil;
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory: AVAudioSessionCategoryRecord error: &err];

        if (err) {
            getFlowRunner()->NotifyCameraEventAudio(1, "Can't create audio session.", additionalInfo, -1, -1);
            return;
        }
        err = nil;

        if (commonAudioRecordControllerDelegate.audioRecordURL == nil) {
            NSArray * URLs = [[NSFileManager defaultManager] URLsForDirectory: NSDocumentDirectory inDomains: NSUserDomainMask];
            NSURL * documentsURL = URLs[0];
            NSString * fileName = [NSString stringWithFormat: @"%@.mp4", commonAudioRecordControllerDelegate.desiredFileName];
            NSURL * audioURL = [NSURL URLWithString: fileName relativeToURL: documentsURL];
            commonAudioRecordControllerDelegate.audioRecordURL = audioURL;
        }

        AVAudioRecorder * recorder = [[AVAudioRecorder alloc] initWithURL: commonAudioRecordControllerDelegate.audioRecordURL settings: recordSettings error: &err];

        if (err) {
            commonAudioRecordControllerDelegate.audioRecordURL = nil;
            getFlowRunner()->NotifyCameraEventAudio(2, "Can't create instance of audio recorder.", additionalInfo, -1, -1);
            return;
        }
        err = nil;

        recorder.delegate = commonAudioRecordControllerDelegate;
        commonAudioRecordControllerDelegate.audioRecorder = recorder;
        if (!([recorder prepareToRecord] && [recorder recordForDuration: (NSTimeInterval) commonAudioRecordControllerDelegate.duration])) {
            commonAudioRecordControllerDelegate.audioRecordURL = nil;
            getFlowRunner()->NotifyCameraEventAudio(3, "Failed to record for some reason.", additionalInfo, -1, -1);
        }
    }
}

void iosGLRenderSupport::doStopRecordAudio() {
    if (commonAudioRecordControllerDelegate.audioRecorder.isRecording) {
        [commonAudioRecordControllerDelegate.audioRecorder stop];
        commonAudioRecordControllerDelegate.manuallyStopped = true;
    }
}

void iosGLRenderSupport::doTakeAudioRecord() {

    if (commonAudioRecordControllerDelegate.audioRecorder.isRecording) {
        [commonAudioRecordControllerDelegate.audioRecorder stop];
        commonAudioRecordControllerDelegate.manuallyStopped = true;
    }

    if (commonAudioRecordControllerDelegate.audioRecordURL != nil) {

        NSURL * audioURL = commonAudioRecordControllerDelegate.audioRecordURL;
        NSData * audioData = [NSData dataWithContentsOfURL: audioURL options: NSDataReadingUncached error: nil];

        NSFileManager * fileManager = [NSFileManager defaultManager];
        NSDictionary * properties = [fileManager attributesOfItemAtPath: audioURL.path error: nil];

        NSNumber * audioFileSize = [properties objectForKey: NSFileSize];
        commonAudioRecordControllerDelegate.size = [audioFileSize intValue];

        AVURLAsset * audioAsset = [AVURLAsset URLAssetWithURL: audioURL options:nil];
        double sec = CMTimeGetSeconds(audioAsset.duration);
        commonAudioRecordControllerDelegate.duration = ceil(sec);

        if ([audioData writeToURL: audioURL atomically: NO] == YES) {
            getFlowRunner()->NotifyCameraEventAudio(0, [[audioURL path] UTF8String], 
                lastCameraAdditionalArgs, commonAudioRecordControllerDelegate.duration, commonAudioRecordControllerDelegate.size);
            [fileManager removeItemAtPath: audioURL.path error: nil];
        } else {
            getFlowRunner()->NotifyCameraEventAudio(4, "Failed to save audio file", lastCameraAdditionalArgs, -1, -1);
        }

    } else {
        getFlowRunner()->NotifyCameraEventAudio(5, "Nothing to save yet", lastCameraAdditionalArgs, -1, -1);
    }
}

