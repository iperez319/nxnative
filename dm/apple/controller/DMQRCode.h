#pragma once
#import <CoreImage/CoreImage.h>
// Shared with the native QR decode test. Four white modules surround the code;
// integer scaling and nearest-neighbour display preserve the module edges.
static inline CGImageRef DMCreatePairingQR(NSString *code) CF_RETURNS_RETAINED {
    if (!code.length || code.length > 1024) return nil;
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    [filter setValue:[code dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
    [filter setValue:@"M" forKey:@"inputCorrectionLevel"];
    CIImage *image = filter.outputImage; if (!image) return nil;
    CIImage *white = [[CIImage imageWithColor:CIColor.whiteColor] imageByCroppingToRect:CGRectInset(image.extent, -4, -4)];
    image = [[image imageByCompositingOverImage:white] imageByApplyingTransform:CGAffineTransformMakeScale(8, 8)];
    CIContext *context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer:@YES}];
    return [context createCGImage:image fromRect:image.extent];
}
