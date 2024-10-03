/*
 *  RawImage.cpp
 *  ShapeFinder
 *
 *  Created by Stephen Gifford on 10/15/09.
 *  Copyright 2009 Qyoo. All rights reserved.
 *
 */

#include "RawImage.h"

#ifdef QYOO_CMD
// Save out image for debugging
void gdSaveAsPng(gdImagePtr theImage,const char *fileName)
{
  FILE *fp = fopen(fileName,"wb");
  if (!fp)  return;

  gdImagePng(theImage,fp);
  fclose(fp);
}

// Flip and return the gd image
gdImagePtr gdFlipImage(gdImagePtr theImage)
{
  gdImagePtr outImg = gdImageCreate(gdImageSY(theImage),gdImageSX(theImage));
  for (unsigned int ic=0;ic<255;ic++)
    gdImageColorAllocate(outImg,ic,ic,ic);

  for (unsigned int ix=0;ix<gdImageSX(theImage);ix++)
    for (unsigned int iy=0;iy<gdImageSY(theImage);iy++)
      {
	int pixVal = gdImageRed(theImage,gdImageGetPixel(theImage,ix,iy));
	int red = gdImageRed(theImage,pixVal);
	int green = gdImageGreen(theImage,pixVal);
	int blue = gdImageBlue(theImage,pixVal);
	int outVal = (red+green+blue)/3;
	gdImageSetPixel(outImg,iy,ix,outVal);
      }

  return outImg;
}
#endif

// Construct with a new image
RawImageGray8::RawImageGray8(int sizeX,int sizeY)
{
	this->sizeX = sizeX;  this->sizeY = sizeY;
	isMine = true, useFree = false;
	img = new unsigned char [sizeX*sizeY];
	memset(img,0,totalSize());
}

// Destructor
RawImageGray8::~RawImageGray8()
{
	if (isMine)
	{
		if (useFree)
			free(img);
		else
			delete [] img;
	}
	img = NULL;
}

#ifdef QYOO_CMD
// Pull the data out of a GD Image
void RawImageGray8::copyFromGDImage(gdImagePtr inImage)
{
  gdImagePtr tmpImg = gdImageCreate(sizeX,sizeY);
  for (unsigned int ic=0;ic<255;ic++)
    gdImageColorAllocate(tmpImg,ic,ic,ic);
  gdImageCopyResampled(tmpImg,inImage,0,0,0,0,sizeX,sizeY,gdImageSX(inImage),gdImageSY(inImage));
  //  gdSaveAsPng(tmpImg,"gdInput.png");

  // Now pull out the data
  for (unsigned ix=0;ix<tmpImg->sx;ix++)
    for (unsigned int iy=0;iy<tmpImg->sy;iy++)
      {
	// We're assuming the input images are grayscale
	int pixVal = gdImageGetPixel(tmpImg,ix,iy);
	int red = gdImageRed(tmpImg,pixVal);
	int green = gdImageGreen(tmpImg,pixVal);
	int blue = gdImageGreen(tmpImg,pixVal);
	int gray = (red+green+blue)/3;
	getPixel(ix,iy) = gdImageRed(tmpImg,gray);
	if (pixVal != 0) 
	  {
	    int foo = 0;
	  }
      }

  gdImageDestroy(tmpImg);
}

// Pull the data out of a GDImage, but apply a transform
void RawImageGray8::copyFromGDImage(gdImagePtr inImage,QyooMatrix &mat)
{
  QyooMatrix invMat = mat;
  invMat.inverse();

  cml::vector3d pt0 = invMat * cml::vector3d(0,0,1.0);
  cml::vector3d pt1 = invMat * cml::vector3d(1,1,1.0);

  for (unsigned int ix=0;ix<sizeX;ix++)
    for (unsigned int iy=0;iy<sizeY;iy++)
      {
	float ixP = (float)ix/(float)sizeX;
	float iyP = (float)iy/(float)sizeY;
	// Project this pixel back to see where it falls
	cml::vector3d pt = invMat * cml::vector3d(ixP,iyP,1.0);
	int destX = pt[0]+0.5, destY = pt[1]+0.5;
	// Snap to the boundaries of the source
	if (destX < 0)  destX = 0;
	if (destX >= gdImageSX(inImage)) destX = gdImageSX(inImage)-1;
	if (destY < 0)  destY = 0;
	if (destY >= gdImageSY(inImage)) destY = gdImageSY(inImage)-1;

	// And assign the pixel
	// Note: This might look a little pixelated, but should work for out purposes
	//       Might also be off by half a pixel
	int pixVal = gdImageGetPixel(inImage,destX,destY);
	getPixel(ix,iy) = gdImageRed(inImage,pixVal);
      }
}

// Construct a GD Image out of the raw data
gdImagePtr RawImageGray8::makeGDImage()
{
  gdImagePtr newImage = gdImageCreate(sizeX,sizeY);
  for (unsigned int ic=0;ic<255;ic++)
    gdImageColorAllocate(newImage,ic,ic,ic);

  for (unsigned int ix=0;ix<sizeX;ix++)
    for (unsigned int iy=0;iy<sizeY;iy++)
      {
	gdImageSetPixel(newImage,ix,iy,getPixel(ix,iy));
      }

  return newImage;
}
#endif


#ifndef QYOO_CMD
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
#endif

// Run a simple contrast scaling operation
void RawImageGray8::runContrast()
{
	// Get the min/max values
	int minPix = 255,maxPix = -1;
	for (unsigned int ii=0;ii<totalSize();ii++)
	{
		unsigned char &val = img[ii];
		if (val < minPix)  minPix = val;
		if (val > maxPix)  maxPix = val;
	}
	
	// Now do the scale
	float scale = 256.0/(maxPix-minPix);
	for (unsigned int ii=0;ii<totalSize();ii++)
	{
		int newVal = (img[ii] - minPix)*scale;
		img[ii] = (newVal > 255) ? 255 : newVal;
	}
}

// Print the data around a cell, for debugging
void RawImageGray8::printCell(const char *what,int cx,int cy)
{
	printf("%s at (%d,%d)\n",what,cx,cy);
	for (unsigned int iy=cy+1;iy>=cy-1;iy--)
	{
		printf("  ");
		for (unsigned int ix=cx-1;ix<=cx+1;ix++)
		{
			printf("%4d\t",getPixel(ix, iy));
		}
		printf("\n");
	}
}

// Construct with a new image
RawImageGray32::RawImageGray32(int sizeX,int sizeY)
{
	this->sizeX = sizeX;  this->sizeY = sizeY;
	img = new int [sizeX*sizeY];
	bzero(img,totalSize()*sizeof(int));
}

// Destructor
RawImageGray32::~RawImageGray32()
{
	delete [] img;
	img = NULL;
}

#ifdef QYOO_CMD
// Construct a GDImage from the data
gdImagePtr RawImageGray32::makeImage(bool zeroAlpha)
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

	// Output image in grayscale
	gdImagePtr outImg = gdImageCreate(sizeX,sizeY);
	for (unsigned int ic=0;ic<255;ic++)
	  gdImageColorAllocate(outImg,ic,ic,ic);

	for (unsigned int ix=0;ix<sizeX;ix++)
	  for (unsigned int iy=0;iy<sizeY;iy++)
	    {
	      int pix = getPixel(ix,iy);
	      int scalePix = 255*(pix-minPix)/(float)(maxPix-minPix);
	      gdImageSetPixel(outImg,ix,iy,scalePix);
	    }

	return outImg;
}
#endif


#ifndef QYOO_CMD
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
#endif

// Print the data around a cell, for debugging
void RawImageGray32::printCell(const char *what,int cx,int cy)
{
	printf("%s at (%d,%d)\n",what,cx,cy);
	for (unsigned int iy=cy+1;iy>=cy-1;iy--)
	{
		printf("  ");
		for (unsigned int ix=cx-1;ix<=cx+1;ix++)
		{
			printf("%4d",getPixel(ix, iy));
		}
		printf("\n");
	}
}
