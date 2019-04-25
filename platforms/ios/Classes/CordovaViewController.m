//
//  CordovaViewController.m
//  flow
//
//  Created by Natili, Giorgio on 8/13/15.
//
//
#import "CordovaViewController.h"

@interface CordovaViewController ()

@end

@implementation CordovaViewController

- (void)viewDidLoad {
    // It's safer to use baseUserAgent property instead of _userAgent
    self.baseUserAgent = [[NSUserDefaults standardUserDefaults] objectForKey:@"FlowUserAgent"];
    
    [super viewDidLoad];
    
    // For scroll feature of WebView to prevent covering of input fields
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide) name:UIKeyboardWillHideNotification object:nil];

    UITapGestureRecognizer *webViewTapped = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapAction:)];
    webViewTapped.numberOfTapsRequired = 1;
    webViewTapped.delegate = self;
    [self.webView addGestureRecognizer:webViewTapped];
    [webViewTapped release];
    
    // Do any additional setup after loading the view.
    self.originalCordovaDelegate = (CDVUIWebViewDelegate*)((UIWebView*)self.webView).delegate;
    ((UIWebView*)self.webView).delegate = self.flowDelegate;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)tapAction:(UITapGestureRecognizer *)sender
{
    // Get the specific point that was touched
    self.tapPos = [sender locationInView:self.webView.scrollView];
}

-(void)keyboardWillShow {
    CGRect textFieldRect;
    CGFloat realTextFieldWidth;
    CGFloat realTextFieldHeight;

    CGFloat contentHeight = self.webView.scrollView.contentSize.height;
    CGFloat contentWidth = self.webView.scrollView.contentSize.width;

    NSString* tagName = [[self.webView stringByEvaluatingJavaScriptFromString:@"document.activeElement.tagName"] lowercaseString];

    CGFloat textFieldHeight;
    CGFloat textFieldWidth;

    if (![tagName isEqualToString:@"undefined"] && ![tagName isEqualToString:@"null"] && !(self.tapPos.x == 0 && self.tapPos.y == 0)) {
        if ([tagName  isEqual: @"input"] || [tagName  isEqual: @"textarea"]) {
            textFieldHeight = [[self.webView stringByEvaluatingJavaScriptFromString:@"document.activeElement.offsetHeight"] floatValue] * 0.8 + 5.0;
            textFieldWidth = [[self.webView stringByEvaluatingJavaScriptFromString:@"document.activeElement.offsetWidth"] floatValue] + 2.0;
        } else {
            textFieldHeight = 50.0;
            textFieldWidth = 20.0;
        }

        if (self.tapPos.y + textFieldHeight < contentHeight) {
            realTextFieldHeight = textFieldHeight;
        } else {
            realTextFieldHeight = contentHeight - self.tapPos.y - 2.0;
        }

        if (self.tapPos.x + textFieldWidth < contentWidth) {
            realTextFieldWidth = textFieldWidth;
        } else {
            realTextFieldWidth = contentWidth - self.tapPos.x - 2.0;
        }

        textFieldRect = CGRectMake(self.tapPos.x, self.tapPos.y, realTextFieldWidth, realTextFieldHeight);
        [self.webView.scrollView scrollRectToVisible:textFieldRect animated:YES];
    }
}

-(void)keyboardWillHide {
    self.tapPos = CGPointMake(0, 0);
    [self.webView.scrollView scrollRectToVisible:CGRectMake(self.tapPos.x, self.tapPos.y, 0, 0) animated:NO];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
