#ifndef iosFileSystemInterface_h
#define iosFileSystemInterface_h

#include "utils/FileSystemInterface.h"

#import "EAGLViewController.h"

@class EAGLViewController;

@interface FlowUIImagePickerControllerDelegate : NSObject<UIImagePickerControllerDelegate> {
}
@property(readwrite, copy) void (^fileListener)(NSDictionary<UIImagePickerControllerInfoKey, id> *);
@property(readwrite, copy) void (^cancelListener)();

- (id) initWithFileListener:(void (^)(NSDictionary<UIImagePickerControllerInfoKey, id> *)) fileListener cancelListener: (void (^)()) cancelListener;

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info;
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;

@end

class iosFileSystemInterface : public FileSystemInterface
{
    
private:
    ByteCodeRunner *owner;
    EAGLViewController *viewController;
    
public:
    iosFileSystemInterface(ByteCodeRunner *owner, EAGLViewController *viewController);
    
protected:
    void doOpenFileDialog(int maxFilesCount, std::vector<std::string> fileTypes, StackSlot callback);
    std::string doFileType(const StackSlot &file);
};


#endif /* iosFileSystemInterface_h */
