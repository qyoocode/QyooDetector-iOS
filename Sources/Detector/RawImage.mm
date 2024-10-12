/*
 *  RawImage.cpp
 *  ShapeFinder
 *
 *  Created by Stephen Gifford on 10/15/09.
 *  Copyright 2009 Qyoo. All rights reserved.
 *
 */

#include "RawImage.h"

/**
 * Constructor for creating a grayscale image of 8-bit depth.
 * @param sizeX The width of the image.
 * @param sizeY The height of the image.
 */
RawImageGray8::RawImageGray8(int sizeX, int sizeY)
{
    this->sizeX = sizeX;
    this->sizeY = sizeY;
    isMine = true;
    useFree = false;
    img = new unsigned char[sizeX * sizeY];
    memset(img, 0, totalSize());
}

/**
 * Destructor for the 8-bit grayscale image.
 * Frees up the allocated memory for the image data.
 */
RawImageGray8::~RawImageGray8()
{
    if (isMine)
    {
        if (useFree)
            free(img);
        else
            delete[] img;
    }
    img = NULL;
}

// Render a UIImage down into the given raw image
// We're also stripping the image of its orientation information
void RawImageGray8::renderFromImage(UIImage *inImage, BOOL flip, BOOL vertFlip)
{
    CGImageRef imgRef = inImage.CGImage;

    CGFloat width = CGImageGetWidth(imgRef);
    CGFloat height = CGImageGetHeight(imgRef);
    
    CGRect bounds = (flip ? CGRectMake(0, 0, sizeY, sizeX) : CGRectMake(0, 0, sizeX, sizeY));
    
    CGFloat scaleRatio = bounds.size.width / width;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(img, sizeX, sizeY, 8, 1*sizeX, colorSpace, kCGBitmapByteOrderDefault);
    CGColorSpaceRelease(colorSpace);

    if (flip)
    {
        CGContextScaleCTM(context, -scaleRatio, scaleRatio);
        CGContextRotateCTM(context, M_PI / 2.0);
    }
    else
    {
        if (vertFlip)
        {
            CGContextScaleCTM(context, scaleRatio, -scaleRatio);
            CGContextTranslateCTM(context, 0.0, -height);
        }
        else
        {
            CGContextScaleCTM(context, scaleRatio, scaleRatio);
        }
    }
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imgRef);
    CGContextRelease(context);
}

// Render a UIImage down into the given raw image
// We're also stripping the image of its orientation information
void RawImageGray8::renderFromImage(UIImage *inImage, CGAffineTransform &inMat, BOOL flip, BOOL vertFlip)
{
    CGImageRef imgRef = inImage.CGImage;
    CGFloat imgWidth = CGImageGetWidth(imgRef);
    CGFloat imgHeight = CGImageGetHeight(imgRef);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(img, sizeX, sizeY, 8, 1*sizeX, colorSpace, kCGBitmapByteOrderDefault);
    CGColorSpaceRelease(colorSpace);

    // This will let us work within (0,0)->(1,1)
    if (vertFlip)
    {
        CGContextScaleCTM(context, sizeX, sizeY);
    }
    else
    {
        CGContextTranslateCTM(context, 0.0, sizeY);
        CGContextScaleCTM(context, sizeX, -sizeY);
    }
    
    // The transform the caller passed in
    CGContextConcatCTM(context, inMat);
    
    if (flip)
    {
        CGContextTranslateCTM(context, 0, imgHeight);
        CGContextScaleCTM(context, -1.0, -1.0);
        CGContextRotateCTM(context, M_PI / 2.0);
        
        CGContextDrawImage(context, CGRectMake(0.0, 0.0, imgHeight, imgWidth), imgRef);
    }
    else
    {
        CGContextTranslateCTM(context, 0, imgHeight);
        CGContextScaleCTM(context, 1.0, -1.0);
        CGContextDrawImage(context, CGRectMake(0.0, 0.0, imgWidth, imgHeight), imgRef);
    }

    CGContextRelease(context);
}


// Callback to release a buffer handed off as a data provider
void releaseBuffer(void *info, const void *data, size_t size)
{
    unsigned char *theData = (unsigned char *)info;
    delete [] theData;
}

// Construct a UIImage from our data
UIImage *RawImageGray8::makeImage(bool makeCopy)
{
    CGDataProviderRef provider;
    if (makeCopy)
    {
        unsigned char *newData = new unsigned char [totalSize()];
        bcopy(img, newData, totalSize());
        provider = CGDataProviderCreateWithData(newData, newData, totalSize(), releaseBuffer);
    }
    else
    {
        provider = CGDataProviderCreateWithData(img, img, totalSize(), NULL);
    }
    
    const int bitsPerComponent = 8;
    const int bitsPerPixel = bitsPerComponent;
    const int bytesPerRow = sizeX;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceGray();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef imageRef = CGImageCreate(sizeX, sizeY, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    CGDataProviderRelease(provider);
    
    UIImage *myImage = [UIImage imageWithCGImage:imageRef];  // ARC handles memory management
    CGImageRelease(imageRef);
    
    return myImage;
}

// Colors used for display of indexed image data
const int MaxColor = 9;
unsigned char displayColors[] = {0,0,0, 255,255,0, 0,255,0, 64,64,255, 255,0,0, 255,255,255, 128,128,128, 45,128,128, 200,96,0};

// Construct a color indexed UIImage from our data
// Note: We've hardwired the colors.  Yes, that's lame
UIImage *RawImageGray8::makeIndexImage(unsigned char check, unsigned char mask)
{
    CGDataProviderRef provider;
    unsigned char *newData = new unsigned char [2*totalSize()];
    
    // Copy the data over and give us an alpha channel
    for (unsigned int ii = 0; ii < totalSize(); ii++)
    {
        unsigned char val = img[ii];
        if (val & check)
            val = (val & mask) % (MaxColor - 1) + 1;
        else
            val = 0;

        newData[2 * ii] = val;
        newData[2 * ii + 1] = (val ? 255 : 0);
    }
    
    provider = CGDataProviderCreateWithData(newData, newData, 2 * totalSize(), releaseBuffer);

    const int bitsPerComponent = 8;
    const int bitsPerPixel = 16;
    const int bytesPerRow = 2 * sizeX;
    CGColorSpaceRef rgbSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateIndexed(rgbSpaceRef, 5 - 1, displayColors);
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaLast;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef imageRef = CGImageCreate(sizeX, sizeY, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    CGDataProviderRelease(provider);
    
    UIImage *myImage = [UIImage imageWithCGImage:imageRef];  // ARC handles memory management
    CGImageRelease(imageRef);
    
    return myImage;
}

/**
 * Perform a simple contrast scaling operation on the grayscale image.
 * Adjusts pixel values to enhance contrast.
 */
void RawImageGray8::runContrast()
{
    int minPix = 255, maxPix = -1;
    for (unsigned int ii = 0; ii < totalSize(); ii++)
    {
        unsigned char &val = img[ii];
        if (val < minPix) minPix = val;
        if (val > maxPix) maxPix = val;
    }

    float scale = 256.0 / (maxPix - minPix);
    for (unsigned int ii = 0; ii < totalSize(); ii++)
    {
        int newVal = (img[ii] - minPix) * scale;
        img[ii] = (newVal > 255) ? 255 : newVal;
    }
}

/**
 * Print the pixel data around a specific cell for debugging purposes.
 * @param what The message to display.
 * @param cx The x-coordinate of the cell.
 * @param cy The y-coordinate of the cell.
 */
void RawImageGray8::printCell(const char *what, int cx, int cy)
{
    printf("%s at (%d,%d)\n", what, cx, cy);
    for (unsigned int iy = cy + 1; iy >= cy - 1; iy--)
    {
        printf("  ");
        for (unsigned int ix = cx - 1; ix <= cx + 1; ix++)
        {
            printf("%4d\t", getPixel(ix, iy));
        }
        printf("\n");
    }
}

/**
 * Constructor for creating a grayscale image of 32-bit depth.
 * @param sizeX The width of the image.
 * @param sizeY The height of the image.
 */
RawImageGray32::RawImageGray32(int sizeX, int sizeY)
{
    this->sizeX = sizeX;
    this->sizeY = sizeY;
    img = new int[sizeX * sizeY];
    bzero(img, totalSize() * sizeof(int));
}

/**
 * Destructor for the 32-bit grayscale image.
 * Frees up the allocated memory for the image data.
 */
RawImageGray32::~RawImageGray32()
{
    delete[] img;
    img = NULL;
}

// Construct a UIImage from our data
UIImage *RawImageGray32::makeImage(bool zeroAlpha)
{
    // Get the min and max
    int minPix=1<29,maxPix=-(1<<29);
    for (unsigned int ii=0;ii<totalSize();ii++)
    {
        int pix = img[ii];
        if (pix < minPix)  minPix = pix;
        if (pix > maxPix)  maxPix = pix;
    }
    // Floor at zero
    if (minPix > 0)  minPix = 0;
    
    CGDataProviderRef provider;
    unsigned char *newData = new unsigned char [2*totalSize()];
    // Run through and scale the data
    for (unsigned int ii=0;ii<totalSize();ii++)
    {
        int pix = img[ii];
        if (maxPix!=minPix)
          pix = (pix-minPix)/(float)(maxPix-minPix) * 255;
        if (pix < 0) pix = 0;
        if (pix > 255) pix = 255;
        newData[2*ii] = pix;
        newData[2*ii+1] = (zeroAlpha ? (pix == 0 ? 0 : 255) : 255);
    }
    
    provider = CGDataProviderCreateWithData(newData, newData, totalSize(), releaseBuffer);

    const int bitsPerComponent = 8;
    const int bitsPerPixel = 16;
    const int bytesPerRow = 2*sizeX;
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceGray();
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault|kCGImageAlphaLast;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef imageRef = CGImageCreate(sizeX, sizeY, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    CGDataProviderRelease(provider);
    
    UIImage *myImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return myImage;
}

// Construct a color indexed UIImage from our data
// Note: We've hardwired the colors.  Yes, that's lame
UIImage *RawImageGray32::makeIndexImage(unsigned int check,unsigned int mask)
{
    CGDataProviderRef provider;
    unsigned char *newData = new unsigned char [2*totalSize()];
    
    // Copy the data over and give us an alpha channel
    // Also make sure the data's within range
    for (unsigned int ii=0;ii<totalSize();ii++)
    {
        unsigned char val = img[ii];
        if (val & check)
            val = (val & mask) % (MaxColor-1) + 1;
        else
            val = 0;
        
        newData[2*ii] = val;
        newData[2*ii+1] = (val ? 255 : 0);
    }
    
    provider = CGDataProviderCreateWithData(newData, newData, 2*totalSize(), releaseBuffer);
    
    const int bitsPerComponent = 8;
    const int bitsPerPixel = 16;
    const int bytesPerRow = 2*sizeX;
    CGColorSpaceRef rgbSpaceRef = CGColorSpaceCreateDeviceRGB();
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateIndexed(rgbSpaceRef,5-1,displayColors);
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault|kCGImageAlphaLast;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef imageRef = CGImageCreate(sizeX, sizeY, bitsPerComponent, bitsPerPixel, bytesPerRow, colorSpaceRef, bitmapInfo, provider, NULL, NO, renderingIntent);
    CGDataProviderRelease(provider);
    
    UIImage *myImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return myImage;
}

/**
 * Print the pixel data around a specific cell for debugging purposes.
 * @param what The message to display.
 * @param cx The x-coordinate of the cell.
 * @param cy The y-coordinate of the cell.
 */
void RawImageGray32::printCell(const char *what, int cx, int cy)
{
    printf("%s at (%d,%d)\n", what, cx, cy);
    for (unsigned int iy = cy + 1; iy >= cy - 1; iy--)
    {
        printf("  ");
        for (unsigned int ix = cx - 1; ix <= cx + 1; ix++)
        {
            printf("%4d", getPixel(ix, iy));
        }
        printf("\n");
    }
}
