#import <UIKit/UIKit.h>
#import "URLLoader.h"
#import "iosAppDelegate.h"

@interface BytecodeViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate> {
    IBOutlet UITextField * BytecodeNameView;
    IBOutlet UIPickerView * BytecodePickerView;
    IBOutlet UITextField * URLParametersView;
    IBOutlet UITableView * AutocompleteTable;
    IBOutlet UIProgressView * ProgressView;
@private
    NSMutableArray * CachedBytecodes;
    NSMutableDictionary * BytecodesURLParameters;
    NSMutableArray * URLsToAutocomplete;
}

- (IBAction) applyUrlParameters:(id)sender;
- (IBAction) downloadBytecodeFile:(id)sender;
- (IBAction) clearLocalStorage: (id)sender;
- (IBAction) runSelectedBytecodeFile: (id)sender;
@end
