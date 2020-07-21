//
//  iosClassKitSupport.m
//  flow
//
//  Created by Ivan Vereschaga on 07.07.2020.
//
#include "iosClassKitSupport.h"

#import "utils.h"


iosClassKitSupport::iosClassKitSupport(ByteCodeRunner *runner) : AbstractClassKitSupport(runner) {
    currentActivity = nil;
}

API_AVAILABLE(ios(11.3))
void iosClassKitSupport::doSetupContext(unicode_string identifier, unicode_string title, unicode_string type, std::function<void()> onOK, std::function<void(unicode_string)> onError) {
    NSString* nsIdentifier = UNICODE2NS(identifier);
    CLSContext* parent = CLSDataStore.shared.mainAppContext;
    
    [parent descendantMatchingIdentifierPath:@[nsIdentifier] completion:^(CLSContext* storedContext, NSError* error) {
        if (storedContext == nil) {
            CLSContext* context = [[CLSContext alloc] initWithType:parseContextType(UNICODE2NS(type)) identifier:nsIdentifier title:UNICODE2NS(title)];
            [parent addChildContext: context];
            
            [CLSDataStore.shared saveWithCompletion:^(NSError* error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error == nil) {
                        onOK();
                    } else {
                        onError(NS2UNICODE(error.localizedDescription));
                    }
                });
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                onOK();
            });
        }
    }];
}

API_AVAILABLE(ios(11.3))
void iosClassKitSupport::doStartContextActivity(unicode_string identifier) {
    if (currentActivity != nil)
        return;
    
    CLSContext* parent = CLSDataStore.shared.mainAppContext;
    
    [parent descendantMatchingIdentifierPath:@[UNICODE2NS(identifier)] completion:^(CLSContext* context, NSError* error) {
        if (context == nil) {
            return;
        }
        
        [context becomeActive];
        currentActivity = [context createNewActivity];
        [currentActivity start];
    }];
}

API_AVAILABLE(ios(11.3))
void iosClassKitSupport::doAddAdditionalBinaryItem(unicode_string identifier, unicode_string title, bool value) {
    CLSBinaryItem* item = [[CLSBinaryItem alloc] initWithIdentifier:UNICODE2NS(identifier) title:UNICODE2NS(title) type:CLSBinaryValueTypeTrueFalse];
    item.value = value;
    [currentActivity addAdditionalActivityItem:item];
    
}

API_AVAILABLE(ios(11.3))
void iosClassKitSupport::doAddAdditionalScoreItem(unicode_string identifier, unicode_string title, double score, double maxScore) {
    CLSScoreItem* item = [[CLSScoreItem alloc] initWithIdentifier:UNICODE2NS(identifier) title:UNICODE2NS(title) score:score maxScore:maxScore];
    [currentActivity addAdditionalActivityItem:item];
}

API_AVAILABLE(ios(11.3))
void iosClassKitSupport::doAddAdditionalQuantityItem(unicode_string identifier, unicode_string title, double quantity) {
    CLSQuantityItem* item = [[CLSQuantityItem alloc] initWithIdentifier:UNICODE2NS(identifier) title:UNICODE2NS(title)];
    item.quantity = quantity;
    [currentActivity addAdditionalActivityItem:item];
}

API_AVAILABLE(ios(11.3))
void iosClassKitSupport::doSetPrimaryScoreItem(unicode_string identifier, unicode_string title, double score, double maxScore) {
    CLSScoreItem* item = [[CLSScoreItem alloc] initWithIdentifier:UNICODE2NS(identifier) title:UNICODE2NS(title) score:score maxScore:maxScore];
    currentActivity.primaryActivityItem = item;
}

API_AVAILABLE(ios(11.3))
void iosClassKitSupport::doEndContextActivity(std::function<void()> onOK, std::function<void(unicode_string)> onError) {
    [currentActivity stop];
    [CLSDataStore.shared saveWithCompletion: ^(NSError* error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            currentActivity = nil;
            if (error == nil) {
                onOK();
            } else {
                onError(NS2UNICODE(error.localizedDescription));
            }
        });
    }];
}

API_AVAILABLE(ios(11.3))
CLSContextType iosClassKitSupport::parseContextType(NSString* type) {
    if ([type isEqualToString:@"app"]) {
        return CLSContextTypeApp;
    } else if ([type isEqualToString:@"audio"]) {
        return CLSContextTypeAudio;
    } else if ([type isEqualToString:@"book"]) {
        return CLSContextTypeBook;
    } else if ([type isEqualToString:@"challenge"]) {
        return CLSContextTypeChallenge;
    } else if ([type isEqualToString:@"chapter"]) {
        return CLSContextTypeChapter;
    } else if ([type isEqualToString:@"document"]) {
        return CLSContextTypeDocument;
    } else if ([type isEqualToString:@"exercise"]) {
        return CLSContextTypeExercise;
    } else if ([type isEqualToString:@"game"]) {
        return CLSContextTypeGame;
    } else if ([type isEqualToString:@"lesson"]) {
        return CLSContextTypeApp;
    } else if ([type isEqualToString:@"level"]) {
        return CLSContextTypeLesson;
    } else if ([type isEqualToString:@"page"]) {
        return CLSContextTypePage;
    } else if ([type isEqualToString:@"quiz"]) {
        return CLSContextTypeQuiz;
    } else if ([type isEqualToString:@"section"]) {
        return CLSContextTypeSection;
    } else if ([type isEqualToString:@"task"]) {
        return CLSContextTypeTask;
    } else if ([type isEqualToString:@"video"]) {
        return CLSContextTypeVideo;
    } else {
        return CLSContextTypeNone;
    }
}
