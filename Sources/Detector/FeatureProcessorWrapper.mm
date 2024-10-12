//
//  FeatureProcessorWrapper.mm.cpp
//  
//
//  Created by Jeffrey Berthiaume on 10/12/24.
//

#import "FeatureProcessorWrapper.h"
#import "FeatureDetector.h"
#import "RawImage.h"

@implementation FeatureProcessorWrapper {
    FeatureProcessor *featureProcessor;
}

- (instancetype)initWithImage:(UIImage *)image {
    self = [super init];
    if (self) {
        // Convert UIImage to raw pixel data suitable for C++
        CGImageRef cgImage = image.CGImage;
        if (!cgImage) {
            return nil;
        }

        size_t width = CGImageGetWidth(cgImage);
        size_t height = CGImageGetHeight(cgImage);
        size_t bitsPerComponent = 8;
        size_t bytesPerRow = 4 * width;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        unsigned char *rawData = (unsigned char *)malloc(height * bytesPerRow);
        if (!rawData) {
            CGColorSpaceRelease(colorSpace);
            return nil;
        }

        CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                     bitsPerComponent, bytesPerRow, colorSpace,
                                                     kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(colorSpace);

        if (!context) {
            free(rawData);
            return nil;
        }

        CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
        CGContextRelease(context);

        // Create a RawImage instance (assuming your C++ code has a suitable constructor)
        RawImage *rawImage = new RawImage((int)width, (int)height, rawData);

        // Initialize the C++ FeatureProcessor with the raw image
        featureProcessor = new FeatureProcessor(rawImage, (int)width, (int)height);

        // Clean up
        free(rawData);
    }
    return self;
}

- (void)processImage {
    if (featureProcessor) {
        featureProcessor->processImage();
    }
}

- (NSInteger)findQyoo {
    if (featureProcessor) {
        return featureProcessor->findQyoo();
    }
    return 0;
}

- (void)findDots {
    if (featureProcessor) {
        // Assuming findDots takes no parameters
        featureProcessor->findDots();
    }
}

- (void)dealloc {
    if (featureProcessor) {
        delete featureProcessor;
    }
}

@end
