/**
 * Copyright (c) 2012 Moodstocks SAS
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "MSScannerController.h"

#import "MSOverlayController.h"
#import "MSDebug.h"
#import "MSImage.h"

#include "moodstocks_sdk.h"

/**
 * Enabled scanning formats
 * Here we only allow offline image recognition.
 * Feel free to add barcodes decoding flags according to your needs
 * e.g. to enable EAN-13 decoding in addition use:
 *   MS_RESULT_TYPE_IMAGE | MS_RESULT_TYPE_EAN13
 *
 * See moodstocks_sdk.h for the list of available flags
 */
static NSInteger kMSScanOptions = MS_RESULT_TYPE_IMAGE;

/* Private stuff */
@interface MSScannerController ()

- (void)showFlash;
- (void)setActivityView:(BOOL)show;

- (void)snapAction:(UIGestureRecognizer *)gestureRecognizer;
- (void)dismissAction;

@end


@implementation MSScannerController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        UIBarButtonItem *barButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                    target:self
                                                                                    action:@selector(dismissAction)] autorelease];
        self.navigationItem.leftBarButtonItem = barButton;
        
        _scannerSession = [[MSScannerSession alloc] initWithScanner:[MSScanner sharedInstance]];
#if MS_SDK_REQUIREMENTS
        [_scannerSession setScanOptions:kMSScanOptions];
        [_scannerSession setDelegate:self];
#endif
        
        _overlayController = [[MSOverlayController alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_overlayController release];
    _overlayController = nil;
    
    [_scannerSession release];
    
    [_result release];
    _result = nil;
    
    [super dealloc];
}

#pragma mark - Private stuff

- (void)showFlash {
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    UIView *flashView = [[UIView alloc] initWithFrame:frame];
    [flashView setBackgroundColor:[UIColor whiteColor]];
    [self.view addSubview:flashView];
    
    void (^animate)(void) = ^{
        [flashView setAlpha:0.f];
    };
    
    void (^finish)(BOOL finished) = ^(BOOL finished){
        [flashView removeFromSuperview];
        [flashView release];
    };
    
    [UIView animateWithDuration:.4f animations:animate completion:finish];
}

- (void)setActivityView:(BOOL)show {
    MSActivityView *activityIndicator = nil;
    if (show) {
        CGRect statusFrame = [UIApplication sharedApplication].statusBarFrame;
        CGFloat offsetY = statusFrame.size.height + 44 /* toolbar height in portrait */;
        CGRect frame = CGRectMake(0, offsetY, self.view.frame.size.width, self.view.frame.size.height);
        activityIndicator = [[MSActivityView alloc] initWithFrame:frame];
        activityIndicator.text = @"Searching...";
        activityIndicator.isAnimating = YES;
        activityIndicator.delegate = self;
        // Place this view at the navigation controller level to make sure it ignores tap gestures
        [self.navigationController.view addSubview:activityIndicator];
        [activityIndicator release];
    }
    else {
        for (UIView *v in [self.navigationController.view subviews]) {
            if ([v isKindOfClass:[MSActivityView class]]) {
                activityIndicator = (MSActivityView *) v;
                break;
            }
        }
        [activityIndicator removeFromSuperview];
    }
}

#pragma mark - View lifecycle

- (void)loadView {
    [super loadView];
    
    CGFloat w = self.view.frame.size.width;
    CGFloat h = self.view.frame.size.height;
    
    CGRect videoFrame = CGRectMake(0, 0, w, h);
    _videoPreview = [[UIView alloc] initWithFrame:videoFrame];
    _videoPreview.backgroundColor = [UIColor blackColor];
    _videoPreview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _videoPreview.autoresizesSubviews = YES;
    [self.view addSubview:_videoPreview];
    
    [_overlayController.view setFrame:CGRectMake(0, 0, w, h)];
    [self.view addSubview:_overlayController.view];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(snapAction:)];
    tapRecognizer.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:tapRecognizer];
    [tapRecognizer release];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = nil;
    
    CALayer *videoPreviewLayer = [_videoPreview layer];
    [videoPreviewLayer setMasksToBounds:YES];
    
    CALayer *captureLayer = [_scannerSession previewLayer];
    [captureLayer setFrame:[_videoPreview bounds]];
    
    [videoPreviewLayer insertSublayer:captureLayer below:[[videoPreviewLayer sublayers] objectAtIndex:0]];
    
    [_scannerSession startCapture];
    
    NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithBool:!!(kMSScanOptions & MS_RESULT_TYPE_EAN8)],   @"decode_ean_8",
                           [NSNumber numberWithBool:!!(kMSScanOptions & MS_RESULT_TYPE_EAN13)],  @"decode_ean_13",
                           [NSNumber numberWithBool:!!(kMSScanOptions & MS_RESULT_TYPE_QRCODE)], @"decode_qrcode",
                           [NSNumber numberWithBool:!!(kMSScanOptions & MS_RESULT_TYPE_DMTX)],   @"decode_datamatrix", nil];
    [_overlayController scanner:self stateUpdated:state];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    [_videoPreview release];
    _videoPreview = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Actions

- (void)snapAction:(UIGestureRecognizer *)gestureRecognizer {
    [self showFlash];
    [_scannerSession snap];
}

- (void)dismissAction {
    [_scannerSession stopCapture];
    
    // This is to make sure any pending API search is cancelled
    [_scannerSession cancel];
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - MSScannerSessionDelegate

#if MS_SDK_REQUIREMENTS

- (void)session:(MSScannerSession *)session didScan:(MSResult *)result {
    // Notify the overlay
    // --
    if (result != nil) {
        // We choose to notify only if a *new* result has been found
        if (![_result isEqualToResult:result]) {
            [_result release];
            _result = [result copy];
            
            // This is to prevent the scanner to keep scanning while a result
            // is shown on the overlay side (see `resume` method below)
            [_scannerSession pause];
            
            // Make sure this happens into the *main* thread
            CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^(void) {
                [_overlayController scanner:self resultFound:result];
            });
        }
    }
}

- (void)session:(MSScannerSession *)scanner failedToScan:(NSError *)error {
    MSDLog(@" [MOODSTOCKS SDK] SCAN ERROR: %@", [NSString stringWithCString:ms_errmsg([error code])
                                                                   encoding:NSUTF8StringEncoding]);
}

- (void)scannerWillSearch:(MSScanner *)scanner {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self setActivityView:YES];
}

- (void)scanner:(MSScanner *)scanner didSearchWithResult:(MSResult *)result {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self setActivityView:NO];
    
    if (result != nil) {
        [_scannerSession pause];
        [_overlayController scanner:self resultFound:result];
    }
    else {
        // Feel free to choose the proper UI component used to warn the user
        // that the API search could not found a match
        [[[[UIAlertView alloc] initWithTitle:@"No match found"
                                     message:nil
                                    delegate:nil
                           cancelButtonTitle:@"OK"
                           otherButtonTitles:nil] autorelease] show];
    }
}

- (void)scanner:(MSScanner *)scanner failedToSearchWithError:(NSError *)error {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self setActivityView:NO];
    
    ms_errcode ecode = [error code];
    // NOTE: ignore negative error codes (e.g. -1 when the request has been cancelled)
    if (ecode >= 0) {
        NSString *errStr = [NSString stringWithCString:ms_errmsg(ecode) encoding:NSUTF8StringEncoding];
        
        MSDLog(@" [MOODSTOCKS SDK] FAILED TO SEARCH WITH ERROR: %@", errStr);
        
        // Here you may want to inform the user that an error occurred
        // Fee free to adapt to your needs (wording, display policy, etc)
        switch (ecode) {
            case MS_NOCONN:
                errStr = @"No Internet connection.";
                break;
                
            case MS_TIMEOUT:
                errStr = @"The request timed out.";
                break;
                
            default:
                errStr = [NSString stringWithFormat:@"An error occurred (code = %d).", ecode];
                break;
        }
        
        // Feel free to choose the proper UI component to warn the user that an error occurred
        [[[[UIAlertView alloc] initWithTitle:@"Search error"
                                     message:errStr
                                    delegate:nil
                           cancelButtonTitle:@"OK"
                           otherButtonTitles:nil] autorelease] show];
    }
}
#endif

#pragma mark - MSActivityViewDelegate

- (void)activityViewDidCancel:(MSActivityView *)view {
    [_scannerSession cancel];
}

#pragma mark - Public

- (void)resume {
    [_result release];
    _result = nil;
    [_scannerSession resume];
}

@end
