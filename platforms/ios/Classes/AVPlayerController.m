//
//  AVPlayerViewController.m
//  flow
//
//  Created by Vsevolod Zakharov on 16/06/16.
//
//

#import "AVPlayerController.h"

@interface FlowAVPlayerController ()

@end

@implementation FlowAVPlayerController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) setVideoSubtitle: (NSString*) subtitle {
    SubtitleText.text = subtitle;
}

- (void) showPlayButton {
    PlayButtonImage.hidden = NO;
}

- (void) hidePlayButton {
    PlayButtonImage.hidden = YES;
}
@end
