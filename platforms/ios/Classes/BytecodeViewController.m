#import "BytecodeViewController.h"
#import <QuartzCore/QuartzCore.h>

#define CLEAR_ALERT 1001

@interface  BytecodeViewController () 
- (void) refreshListOfCachedBytecodes;
- (void) showErrorMessage: (NSString*) message;
- (void) clearCacheAndLocalStorage;
@end

@implementation BytecodeViewController

#define URL_PARAMETERS_FILE @"bytecodes_url_parameters"
#define URL_AUTOCOMPLETION_FILE @"urls_to_autocomplete"

- (void)viewDidLoad {
    [super viewDidLoad];

    CachedBytecodes = [[NSMutableArray alloc] init];
    [self refreshListOfCachedBytecodes];
    if (0 < [CachedBytecodes count] ) {
        NSString * bytecode_name =[CachedBytecodes objectAtIndex: 0];
        URLParametersView.text = [BytecodesURLParameters objectForKey: bytecode_name];
    }
    
    BytecodesURLParameters = [[NSMutableDictionary alloc] initWithDictionary:
        [NSDictionary dictionaryWithContentsOfFile: 
          [[URLLoader cachePath] stringByAppendingPathComponent: URL_PARAMETERS_FILE]]];
    URLsToAutocomplete = [[NSMutableArray alloc] initWithArray:
        [NSArray arrayWithContentsOfFile:
          [[URLLoader cachePath] stringByAppendingPathComponent: URL_AUTOCOMPLETION_FILE]]];
}

- (void) dealloc {
    [CachedBytecodes release];
    [BytecodesURLParameters release];
    [URLsToAutocomplete release];

    [super dealloc];
}

// Bytecode field autocompletion
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [currentAutocompletionURLs count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *simpleTableIdentifier = @"SimpleTableItem";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    cell.textLabel.text = [currentAutocompletionURLs objectAtIndex: indexPath.row];
    
    return cell;
}

static NSMutableArray * currentAutocompletionURLs = [[NSMutableArray alloc] init];

- (NSArray *) getAutocompletionsForString: (NSString *) str {
    [currentAutocompletionURLs removeAllObjects];
    for (NSString* url in URLsToAutocomplete)
        if ([url hasPrefix: str]) [currentAutocompletionURLs addObject: url];
    
    return currentAutocompletionURLs;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if ([string length] == 1) { // User typing URL
        NSString * text = [textField.text stringByReplacingCharactersInRange: range withString: string];
        if ([[self getAutocompletionsForString: text] count] != 0) {
            AutocompleteTable.hidden = NO;
            [AutocompleteTable reloadData];
        } else {
            AutocompleteTable.hidden = YES;
        }
    } else {
        AutocompleteTable.hidden = YES;
    }
    
    return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    BytecodeNameView.text = [currentAutocompletionURLs objectAtIndex: indexPath.row];
    AutocompleteTable.hidden = YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField {
    AutocompleteTable.hidden = YES;
    return YES;
}

- (void) refreshListOfCachedBytecodes {
    NSArray * cached_files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: [URLLoader cachePath] error: nil];
    
    [CachedBytecodes removeAllObjects];
    for (NSString * name in cached_files) {
        if ( [name hasSuffix: @".bytecode"] || [name hasSuffix: @".b"])
            [ CachedBytecodes addObject: name ];
    }
}

- (void) showErrorMessage: (NSString*) message {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message: message delegate: self cancelButtonTitle: @"OK" otherButtonTitles: nil];
    [alert show];
    [alert release];
}

/********************************************
 PickerView datasource & delegate
 ********************************************/
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    [self refreshListOfCachedBytecodes];
    int rows = [CachedBytecodes count];
    return rows != 0 ? rows : 1;
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if ([CachedBytecodes count] == 0)
        return @"No downloaded bytecode files";
    
    return [CachedBytecodes objectAtIndex: row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    // Update Url parameters view here
    if (row >= [CachedBytecodes count]) return;
    NSString * bytecode_name = [CachedBytecodes objectAtIndex: row];
    URLParametersView.text = [BytecodesURLParameters objectForKey: bytecode_name];
}

/*****************************************
 Buttons events
 *****************************************/

- (IBAction)downloadBytecodeFile:(id)sender {
    AutocompleteTable.hidden = YES;
    
    NSString * bytecode_name = BytecodeNameView.text;
    if ([bytecode_name isEqualToString: @""]) {
        [self showErrorMessage: @"Enter bytecode name"];
        return;
    }
    
    if (!([bytecode_name hasSuffix: @".bytecode"] || [bytecode_name hasSuffix: @".b"])) bytecode_name = [bytecode_name stringByAppendingPathExtension: @"bytecode"];
    
    if ([URLsToAutocomplete indexOfObject: bytecode_name] == NSNotFound) { // Save new URL for autocompletion
        [URLsToAutocomplete addObject: bytecode_name];
        [URLsToAutocomplete writeToFile: [[URLLoader cachePath] stringByAppendingPathComponent: URL_AUTOCOMPLETION_FILE] atomically: YES];
    }
    
    ProgressView.hidden = NO;
    ProgressView.progress = 0.0;
    self.view.userInteractionEnabled = NO;
    
    URLLoader * loader = nil;
    void (^on_progress)(float p) = ^void(float p) { ProgressView.progress = p; };
    
    void (^on_error)(void) = ^void(void) {
        ProgressView.hidden = YES; self.view.userInteractionEnabled = YES;
        [self showErrorMessage: @"Cannot download file"];
    };
    
    void (^on_success)(NSData * data) = ^void(NSData * data) {
        ProgressView.hidden = YES; self.view.userInteractionEnabled = YES;
        [BytecodePickerView reloadAllComponents];
    };
    
    loader = [[URLLoader alloc] initWithURL: bytecode_name onSuccess:on_success onError:on_error onProgress: on_progress onlyCache:YES];
    [loader start];
}


- (IBAction) applyUrlParameters:(id)sender {
    int row =  [BytecodePickerView selectedRowInComponent: 0];
    if (row >= [CachedBytecodes count]) return;
    NSString * bytecode_name = [CachedBytecodes objectAtIndex: row];
    [BytecodesURLParameters setObject: URLParametersView.text forKey: bytecode_name];
    [BytecodesURLParameters writeToFile: [[URLLoader cachePath] stringByAppendingPathComponent: URL_PARAMETERS_FILE] atomically:YES];
}

- (IBAction) clearLocalStorage:(id)sender {
    UIAlertView * alert_view = [[UIAlertView alloc] initWithTitle: @"Clear" message:@"Are you sure to clear the cache?" delegate:self cancelButtonTitle:@"No" otherButtonTitles: @"Yes", nil];
    alert_view.tag = CLEAR_ALERT;
    [alert_view show];
    [alert_view release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == CLEAR_ALERT)
    {
        if (buttonIndex == 1)  {// Yes
            [self clearCacheAndLocalStorage];
            BytecodeNameView.text = @"";
            URLParametersView.text = @"";
        }
    }
}

- (void) clearCacheAndLocalStorage {
    [URLLoader clearCache]; // Remove bytecodes files etc.
    
    // Remove local flow storage too
    NSString * flow_storage_path = [ applicationLibraryDirectory() stringByAppendingString: @"/flow-local-store" ];
    [ [NSFileManager defaultManager] removeItemAtPath: flow_storage_path error: nil ];
    
    [BytecodePickerView reloadAllComponents];
}

- (IBAction) runSelectedBytecodeFile: (id) sender {
    int row =  [BytecodePickerView selectedRowInComponent: 0];
    if (row >= [CachedBytecodes count]) {
        [self showErrorMessage: @"No bytecode file selected"];
         return;
    }
    NSString * bytecode_name = [CachedBytecodes objectAtIndex: row];

    iosAppDelegate * app =[UIApplication sharedApplication].delegate;
    app.DefaultURLParameters = URLParametersView.text;
    app.BytecodeFilePath = [[URLLoader cachePath] stringByAppendingPathComponent: bytecode_name];
    
    [self performSegueWithIdentifier: @"RunFlowViewFromLauncher" sender: self];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}
@end
