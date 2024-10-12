//
//  FeatureProcessorWrapper.h
//  
//
//  Created by Jeffrey Berthiaume on 10/12/24.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FeatureProcessorWrapper : NSObject

- (instancetype)initWithImage:(UIImage *)image;
- (void)processImage;
- (NSInteger)findQyoo;
- (void)findDots;

@end

NS_ASSUME_NONNULL_END
