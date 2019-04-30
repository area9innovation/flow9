//
//  CordovaViewController.h
//  flow
//
//  Created by Natili, Giorgio on 8/13/15.
//
//

#import "CDVViewController.h"
#import "CDVUIWebViewDelegate.h"

@interface CordovaViewController : CDVViewController<UIGestureRecognizerDelegate>
@property (nonatomic, assign) CDVUIWebViewDelegate *originalCordovaDelegate;
@property (nonatomic, assign) id <UIWebViewDelegate> flowDelegate;

@property (nonatomic, assign) CGPoint tapPos;
-(void)keyboardWillShow;
-(void)keyboardWillHide;

@end
