#include "iosFileSystemInterface.h"

#import <MobileCoreServices/MobileCoreServices.h>

#include "utils/flowfilestruct.h"
#include "core/RunnerMacros.h"

@implementation FlowUIImagePickerControllerDelegate

- (id) initWithFileListener:(void (^)(NSDictionary<UIImagePickerControllerInfoKey, id> *)) fileListener cancelListener: (void (^)()) cancelListener {
    self = [super init];
    self.fileListener = fileListener;
    self.cancelListener = cancelListener;
    
    return self;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    self.fileListener(info);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    self.cancelListener();
}

@end

iosFileSystemInterface::iosFileSystemInterface(ByteCodeRunner *owner, EAGLViewController *viewController): FileSystemInterface(owner), owner(owner), viewController(viewController)
{
}

void iosFileSystemInterface::doOpenFileDialog(int maxFilesCount, std::vector<std::string> fileTypes, StackSlot callback)
{
    RUNNER_VAR = owner;
    
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        NSArray<NSString*> *devices = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];

        UIImagePickerController *controller = [[UIImagePickerController alloc] init];
        controller.delegate = [[FlowUIImagePickerControllerDelegate alloc] initWithFileListener:^(NSDictionary<UIImagePickerControllerInfoKey,id> *info) {
            RUNNER_DefSlots1(flowFilesArray);
            flowFilesArray = RUNNER->AllocateArray(1);
            NSURL *fileURL = info[@"UIImagePickerControllerImageURL"];
            if([info[@"UIImagePickerControllerMediaType"] isEqualToString:@"public.movie"]) {
                fileURL = info[@"UIImagePickerControllerMediaURL"];
            }
            
            FlowFile *file = new FlowFile(RUNNER, [fileURL fileSystemRepresentation]);
            RUNNER->SetArraySlot(flowFilesArray, 0, RUNNER->AllocNative(file));
            RUNNER->EvalFunction(callback, 1, flowFilesArray);
            [viewController dismissViewControllerAnimated:YES completion:nil];
        } cancelListener:^{
            RUNNER->EvalFunction(callback, 1, RUNNER->AllocateArray(0));
            [viewController dismissViewControllerAnimated:YES completion:nil];
        }];
        controller.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        controller.mediaTypes = devices;
        [viewController presentViewController:controller animated:YES completion:nil];
    }
}

std::string iosFileSystemInterface::doFileType(const StackSlot &file)
{
    FlowFile *flowFile = owner->GetNative<FlowFile*>(file);
    NSString *filePath = [NSString stringWithCString:flowFile->getFilepath().c_str()
                                            encoding:[NSString defaultCStringEncoding]];
    NSString *fileExtension = [[NSURL fileURLWithPath:filePath] pathExtension];
    NSString *UTI = (NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtension, NULL);
    NSString *contentType = (NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);
    return [contentType UTF8String];
}
