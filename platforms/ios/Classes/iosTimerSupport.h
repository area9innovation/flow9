#include "ByteCodeRunner.h"
#include "RunnerMacros.h"

@interface TimerCallbackObject : NSObject {
@private
    ByteCodeRunner * Runner;
}

- (id) initWithRunner: (ByteCodeRunner*) rnr;
- (void) fire: (NSNumber *) root;
@end

class iosTimerSupport : public NativeMethodHost
{
public:
    iosTimerSupport(ByteCodeRunner *Runner);
    ~iosTimerSupport();
protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);
    void OnRunnerReset(bool inDestructor);
        
private:
    ByteCodeRunner* Runner;
    TimerCallbackObject * CallbackObject;
        
    DECLARE_NATIVE_METHOD(Timer);
};

