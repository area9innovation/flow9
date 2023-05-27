#import <WebKit/WebKit.h>

@class LLWebViewCampaign;
@protocol LLLocalyticsDelegate;

@protocol LLMarketingWebViewHandlerDelegate <NSObject>

- (void)handlerDidFinishLoad;
- (void)handlerDidFailLoadWithError:(nullable NSError *)error;

@optional
- (void)didHandleCloseRequest;

@end

@interface LLMarketingWebViewHandlerBuilder : NSObject

@property (nonatomic, strong, nullable) WKWebView *webView;
@property (nonatomic, strong, nullable) LLWebViewCampaign *campaign;
@property (nonatomic, assign) BOOL openCustomURLSchemas;
@property (nonatomic, assign) BOOL loadUnknownURLSchemas;
@property (nonatomic, assign) CGFloat videoConversionPercentage;
@property (nonatomic, assign, getter=isTestModeEnabled) BOOL testModeEnabled;
@property (nonatomic, weak, nullable) id<LLLocalyticsDelegate> localyticsDelegate;
@property (nonatomic, assign, nonnull) NSString *creativeFilePath;

+ (nonnull WKWebViewConfiguration *)webViewConfiguration:(nullable LLWebViewCampaign *)campaign
                              localyticsDelegate:(nonnull id<LLLocalyticsDelegate>)localyticsDelegate
                                andViewportWidth:(CGFloat)viewportWidth
                                 withViewportFit:(nullable NSString *)viewportFit
                       videoConversionPercentage:(CGFloat)videoConversionPercentage;

@end

@interface LLMarketingWebViewHandler : NSObject <WKNavigationDelegate, WKUIDelegate>

@property (nonatomic, strong) WKWebView * __nullable webView;
@property (nonatomic, strong) __nullable id<LLMarketingWebViewHandlerDelegate> delegate;
//exposed for wrappers
@property (nonatomic, strong, nullable) LLWebViewCampaign *campaign;

+ (nullable instancetype)marketingWebViewWithBlock:(nonnull void (^)(LLMarketingWebViewHandlerBuilder * __nonnull builder))block;

- (BOOL)loadCreative;
- (void)tagMarketingActionForURL:(nonnull NSURL *)url andQueryParams:(nonnull NSDictionary *)queryParams;
- (void)tagMarketingDismissAction;
- (BOOL)creativeHtmlFileExists;
- (void)executeJs:(nonnull NSString*)js;

@end
