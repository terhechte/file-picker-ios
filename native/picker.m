#include <stdbool.h>
#include <stddef.h>

#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#include <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface FilePickerDelegate : NSObject <UIDocumentPickerDelegate> {
  void (^closure)(NSData *, NSString *);
}
@property void (^closure)(NSData *, NSString *);
- (instancetype)initWithClosure:(void (^)(NSData *, NSString *))closure;
@end

@implementation FilePickerDelegate
@synthesize closure;

- (instancetype)initWithClosure:(void (^)(NSData *, NSString *))c {
  if ([self init]) {
    self.closure = c;
  }
  return self;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
    didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  NSFileCoordinator *coordinator =
      [[NSFileCoordinator alloc] initWithFilePresenter:nil];
  BOOL success = NO;
  for (NSURL *url in urls) {
    if ([url startAccessingSecurityScopedResource]) {
      success = YES;
      [coordinator
          coordinateReadingItemAtURL:url
                             options:NSFileCoordinatorReadingWithoutChanges
                               error:nil
                          byAccessor:^(NSURL *newUrl) {
                            NSData *data = [NSData
                                dataWithContentsOfURL:newUrl
                                              options:NSDataReadingMappedIfSafe
                                                error:nil];
                            NSString *filename = [newUrl lastPathComponent];
                            self.closure(data, filename);
                          }];
      [url stopAccessingSecurityScopedResource];
    }
  }
  if (!success) {
    self.closure(nil, nil);
  }
}

- (void)documentPickerWasCancelled:
    (UIDocumentPickerViewController *)controller {
  self.closure(nil, nil);
}
@end

FilePickerDelegate *
show_browser(UIViewController *__unsafe_unretained __nullable controller,
             const char *const *const extensions, const size_t types_len,
             const bool allow_multiple,
             void (*closure)(const void *, size_t, char *, void *),
             void *closure_data) {

  NSMutableArray<UTType *> *types =
      [NSMutableArray arrayWithCapacity:types_len];
  for (size_t i = 0; i < types_len; i++) {
    NSString *ex = [NSString stringWithUTF8String:extensions[i]];
    UTType *type = [UTType typeWithFilenameExtension:ex];
    [types addObject:type];
  }
  FilePickerDelegate *delegate =
      [[FilePickerDelegate alloc] initWithClosure:^(NSData *data, NSString *filename) {
        if (data) {
          closure([data bytes], [data length], [filename cStringUsingEncoding: NSUTF8StringEncoding], closure_data);
        } else {
          closure(NULL, 0, @"", closure_data);
        }
      }];
  
  dispatch_async(dispatch_get_main_queue(), ^{

    UIDocumentPickerViewController *browser =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types];
    browser.allowsMultipleSelection = allow_multiple ? YES : NO;
    browser.shouldShowFileExtensions = YES;

    browser.delegate = delegate;

    UIViewController *selectedController = controller != nil ? controller : [UIApplication sharedApplication].keyWindow.rootViewController;
      [selectedController presentViewController:browser animated:YES completion:nil];
  });
 

  return delegate;
}
