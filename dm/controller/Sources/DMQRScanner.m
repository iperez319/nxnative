#import "DMQRScanner.h"
#import "DMControllerPairing.h"
#import <AVFoundation/AVFoundation.h>

@interface DMQRScanner () <AVCaptureMetadataOutputObjectsDelegate> @end
@implementation DMQRScanner {
    AVCaptureSession *_capture;
    AVCaptureVideoPreviewLayer *_preview;
    dispatch_queue_t _cameraQueue;
    UILabel *_hint;
    BOOL _visible, _finished;
    NSUInteger _generation;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"Scan receiver QR"; self.view.backgroundColor = UIColor.blackColor;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    _cameraQueue = dispatch_queue_create("org.nxnative.controller.camera", DISPATCH_QUEUE_SERIAL);
    _capture = [AVCaptureSession new];
    _preview = [AVCaptureVideoPreviewLayer layerWithSession:_capture]; _preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:_preview];
    _hint = [UILabel new]; _hint.text = @"Point the camera at the QR code shown in nx Input Test on your iPad.";
    _hint.textColor = UIColor.whiteColor; _hint.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    _hint.numberOfLines = 0; _hint.textAlignment = NSTextAlignmentCenter; _hint.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_hint];
    [NSLayoutConstraint activateConstraints:@[[_hint.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [_hint.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
        [_hint.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-24]]];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; _preview.frame = self.view.bounds;
    AVCaptureConnection *connection = _preview.connection;
    UIInterfaceOrientation orientation = self.view.window.windowScene.effectiveGeometry.interfaceOrientation;
    CGFloat angle = orientation == UIInterfaceOrientationLandscapeLeft ? 0 : orientation == UIInterfaceOrientationLandscapeRight ? 180 :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? 270 : 90;
    if ([connection isVideoRotationAngleSupported:angle]) connection.videoRotationAngle = angle;
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated]; _visible = YES; NSUInteger generation = ++_generation;
    AVAuthorizationStatus permission = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (permission == AVAuthorizationStatusAuthorized) [self startCamera:generation];
    else if (permission == AVAuthorizationStatusNotDetermined) {
        __weak DMQRScanner *weak = self;
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                DMQRScanner *s = weak; if (!s || !s->_visible || s->_generation != generation) return;
                if (granted) [s startCamera:generation]; else [s cameraDenied];
            });
        }];
    } else [self cameraDenied];
}
- (void)cameraDenied { _hint.text = @"Allow Camera access for nx Controller in Settings, or Cancel and paste the invitation manually."; }
- (void)startCamera:(NSUInteger)generation {
    AVCaptureSession *session = _capture; __weak DMQRScanner *weak = self;
    dispatch_async(_cameraQueue, ^{
        if (!session.inputs.count) {
            AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
            AVCaptureDeviceInput *input = camera ? [AVCaptureDeviceInput deviceInputWithDevice:camera error:nil] : nil;
            AVCaptureMetadataOutput *output = [AVCaptureMetadataOutput new];
            [session beginConfiguration];
            BOOL valid = input && [session canAddInput:input];
            if (valid) { [session addInput:input]; valid = [session canAddOutput:output]; }
            if (valid) {
                [session addOutput:output];
                valid = [output.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode];
                if (valid) { [output setMetadataObjectsDelegate:weak queue:dispatch_get_main_queue()]; output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode]; }
            }
            [session commitConfiguration];
            if (!valid) { dispatch_async(dispatch_get_main_queue(), ^{ DMQRScanner *s = weak; if (s) s->_hint.text = @"Camera unavailable. Cancel to use the manual invitation."; }); return; }
        }
        // Lifecycle stop is queued on the same executor, so a dismissal during
        // configuration cannot leave the camera running after this task.
        [session startRunning];
        dispatch_async(dispatch_get_main_queue(), ^{
            DMQRScanner *s = weak;
            if (!s || !s->_visible || s->_generation != generation) dispatch_async(self->_cameraQueue, ^{ [session stopRunning]; });
        });
    });
}
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)objects fromConnection:(AVCaptureConnection *)connection {
    if (!_visible || _finished) return;
    for (AVMetadataObject *item in objects) {
        if (![item isKindOfClass:AVMetadataMachineReadableCodeObject.class]) continue;
        NSString *value = ((AVMetadataMachineReadableCodeObject *)item).stringValue;
        DMControllerPairing *pairing = [DMControllerPairing parseCode:value];
        if (!pairing) { _hint.text = @"This is not a supported nx Controller pairing QR. Scan the code in nx Input Test."; continue; }
        _finished = YES;
        void (^scanned)(DMControllerPairing *) = self.scanned;
        [self.navigationController popViewControllerAnimated:NO];
        if (scanned) scanned(pairing);
        break;
    }
}
- (void)cancel { [self.navigationController popViewControllerAnimated:YES]; }
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated]; _visible = NO; _generation++;
    AVCaptureSession *session = _capture; dispatch_async(_cameraQueue, ^{
        for (AVCaptureOutput *output in session.outputs) if ([output isKindOfClass:AVCaptureMetadataOutput.class])
            [(AVCaptureMetadataOutput *)output setMetadataObjectsDelegate:nil queue:nil];
        [session stopRunning];
    });
}
@end
