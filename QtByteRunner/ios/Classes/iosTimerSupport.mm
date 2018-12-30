#import "iosTimerSupport.h"

#import <UIKit/UIKit.h>

iosTimerSupport::iosTimerSupport(ByteCodeRunner *Runner)
: NativeMethodHost(Runner), Runner(Runner)
{
    CallbackObject = [[TimerCallbackObject alloc] initWithRunner: Runner];
}

iosTimerSupport::~iosTimerSupport()
{
    [NSObject cancelPreviousPerformRequestsWithTarget: CallbackObject];
    [CallbackObject release];
}

void iosTimerSupport::OnRunnerReset(bool inDestructor)
{
    NativeMethodHost::OnRunnerReset(inDestructor);
    [NSObject cancelPreviousPerformRequestsWithTarget: CallbackObject];
}

NativeFunction *iosTimerSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "Native."
    TRY_USE_NATIVE_METHOD_NAME(iosTimerSupport, Timer, "timer", 2);
    
    return NULL;
}

StackSlot iosTimerSupport::Timer(RUNNER_ARGS)
{
    RUNNER_PopArgs2(time_ms, cb);
    RUNNER_CheckTag(TInt, time_ms);
    
    if (time_ms.GetInt() <= 5) {
        RUNNER->AddDeferredAction(cb);
    } else {
        int cbroot = RUNNER->RegisterRoot(cb);

        [CallbackObject performSelector: @selector(fire:) withObject: [NSNumber numberWithInt: cbroot] afterDelay: time_ms.GetInt() / 1000.0];
    }
    
    RETVOID;
}

@implementation TimerCallbackObject

-(id) initWithRunner: (ByteCodeRunner * ) rnr
{
    self = [super init];
    
    if (self)
        Runner = rnr;
    
    return self;
}
         
-(void) fire: (NSNumber *) root
{
    @autoreleasepool { // It is not event from UIKit so collect tmp objects
        int root_value = [root intValue];
    
        if (Runner) {
        
            StackSlot cb = Runner->LookupRoot(root_value);
            Runner->ReleaseRoot(root_value); // One timeout only            
            Runner->EvalFunction(cb, 0);
        
            Runner->NotifyHostEvent(NativeMethodHost::HostEventTimer);
        }
    }
}
@end
