/*
 *  FeatureDetector.cpp
 *  ShapeFinder
 *
 *  Created by Stephen Gifford on 10/20/09.
 *  Copyright 2009 Qyoo. All rights reserved.
 *
 *  This file contains the main logic for detecting Qyoo shapes and dots
 *  in an image. It includes processing the image, detecting features,
 *  finding dots, and validating the detected Qyoo codes.
 */

#include <iostream>
#include <sstream>

#import "FeatureDetector.h"
#import "QyooModel.h"
#include "Logger.h"

// Pixels per dot for detection
const int PixelsPerDot = 11;

// Define constants for closing distance and decimation tolerance
const float ClosedDist = 2.0f;  // Threshold distance to consider a feature closed
const float DecimateDist = 0.85f;  // Tolerance for decimating points in a feature

// FeatureDotsProcessor constructor
// Initializes the dot processor with an image, a feature processor, and a feature.

// Initialize with a UIImage
FeatureDotsProcessor::FeatureDotsProcessor(UIImage *inImage, FeatureProcessor *featProc,Feature *feat, bool flip, bool vertFlip)
{
    init(inImage,featProc,feat,flip,vertFlip);
}

void FeatureDotsProcessor::init(UIImage *inImage, FeatureProcessor *inFeatProc, Feature *inFeat, bool flip, bool vertFlip)
{
    grayImg = NULL;
    gaussImg = NULL;
    gradImg = NULL;
    featProc = NULL;
    feat = NULL;

    QyooModel *qyooModel = QyooModel::getQyooModel();
        
    featProc = inFeatProc;
    feat = inFeat;
        
    CGImageRef imgRef = inImage.CGImage;
    CGFloat imgWidth = CGImageGetWidth(imgRef);
    CGFloat imgHeight = CGImageGetHeight(imgRef);
        
        
    // Size of the image we want to render to
    int sizeX = (PixelsPerDot) * (qyooModel->numRows() + 2);
    int sizeY = (PixelsPerDot) * (qyooModel->numPos() + 2);
        
    // This transform will get us from the feature pixel space to unit qyoo space
    float scaleX = (float)imgWidth/(float)feat->imgSizeX, scaleY = (float)imgHeight/(float)feat->imgSizeY;
    CGAffineTransform forMat = CGAffineTransformConcat(feat->mat, CGAffineTransformMakeScale(scaleX,scaleY));
        
    // Focus on just the dots
    // But add in a dots worth of space around
    SimplePoint2D ll,ur;
    qyooModel->dotBounds(ll,ur,true);
    forMat = CGAffineTransformTranslate(forMat, ll.x, ll.y);
    forMat = CGAffineTransformScale(forMat, ur.x-ll.x, ur.y-ll.y);
        
    CGAffineTransform mat = CGAffineTransformInvert(forMat);
        
    // Transform from the big image down into the qyoo small image
    // Set up an image with just the dots, hopefully
    grayImg = new RawImageGray8(sizeX,sizeY);
    grayImg->renderFromImage(inImage,mat,flip,vertFlip);
    grayImg->runContrast();
}

// Destructor for the dot processor
FeatureDotsProcessor::~FeatureDotsProcessor()
{
    delete grayImg;
    delete gaussImg;
    delete gradImg;
    feat = nullptr;
}

// Calculate the average pixel value in a region
static int calcAvgPixel(RawImageGray8 *img, int px, int py, ConvolutionFilterInt *radFilter)
{
    std::vector<int> results(radFilter->getSize() * radFilter->getSize());
    radFilter->processPixel(img, px, py, &results[0]);

    float val = 0.0;
    for (int result : results)
        val += result;

    return val / radFilter->getFact();
}

// Constants used for dot detection
const int RadianceDistMatch = 60;
const float PassRatio = .40;  // 40% coverage

// Check if an area contains a dot by comparing the radiance of pixels
static bool isAdot(RawImageGray8 *img,int px,int py,int pixelsInDot,ConvolutionFilterInt *radFilter,int backColor)
{
	std::vector<int> results(radFilter->getSize()*radFilter->getSize());
	radFilter->processPixel(img,px,py,&results[0]);

	// Decide if the background color is "blackish" or "whiteish"
	bool isWhite = (backColor >= 128);

	// Run through and look for matching pixels
	int numMatch = 0;
	for (unsigned int ii=0;ii<radFilter->getSize()*radFilter->getSize();ii++)
	{
		int thisColor = results[ii];
		if (thisColor >= 0)
		{
			// Distance from this pixel to the grey value we're after
			int dist = backColor - thisColor;  if (dist < 0) dist *= -1;

			// The radiance needs to be far enough away and it needs to be
			//  on the opposite side of 128
			if (dist > RadianceDistMatch && ((isWhite && thisColor < 128+32) ||(!isWhite && thisColor > 128-32)))
				numMatch++;
		}
	}

	float ratio = (float)numMatch / (float)radFilter->getFact();

	return (ratio >= PassRatio);
}

// Convert decimal to binary string representation
static std::string dec2bin(int intDec)
{
    std::string strBin;
    while (intDec)
    {
        std::stringstream sstream;
        sstream << (intDec % 2) << strBin;
        strBin = sstream.str();
        intDec /= 2;
    }

    // Pad with extra zeroes to fit six bits
    while (strBin.size() < 6)
        strBin = "0" + strBin;

    return strBin;
}

// Detect dots in a grayscale image and mark their locations
void FeatureDotsProcessor::findDotsGray() {
    QyooModel *qyooModel = QyooModel::getQyooModel();
    ConvolutionFilterInt *radFilter = MakeRadiusFilter(PixelsPerDot, PixelsPerDot / 2);

    int avgPixel = calcAvgPixel(grayImg, PixelsPerDot / 2, PixelsPerDot / 2, radFilter);

    int numRow = qyooModel->numRows();
    int numPos = qyooModel->numPos();
    feat->dotBinStr.clear();
    feat->dotDecStr.clear();
    qyooBits = "";  // Start fresh with qyooBits

    for (int row = 0; row < numRow; row++) {  // We process from row 0 to numRow
        int resChar = 0;
        int rowPix = PixelsPerDot * (row + 1) + PixelsPerDot / 2;

        for (unsigned int pos = 0; pos < numPos; pos++) {
            int posPix = PixelsPerDot * (pos + 1) + PixelsPerDot / 2;

            
            if (isAdot(grayImg,rowPix,posPix,PixelsPerDot,radFilter,avgPixel)) {
                
                resChar |= 1 << pos;

        }

        // rows are read in reverse, and need to be reversed again
        unsigned char theChar;
        std::string currentRowBits = dec2bin(resChar);  // Get binary string representation of resChar
        qyooBits = currentRowBits + qyooBits;  // Prepend binary string (reversing row order)

        if (numRow - row - 1 >= 0 && numRow - row - 1 < QYOOSIZE) {
            qyooRows[numRow - row - 1] = resChar;  // Store in reverse row order
        } else {
            std::cerr << "Error: Invalid access to qyooRows at index " << (numRow - row - 1) << std::endl;
        }

        qyooModel->bitsToChar(resChar, theChar);
        feat->dotBits.push_back(resChar);

        // Debugging output for each row

        logVerbose("Row " + std::to_string(row) + ": resChar (binary) = " + currentRowBits);
        logVerbose("Current qyooBits = " + qyooBits);
    }
    feat->dotBinStr = qyooBits;

    // Convert the full binary string (qyooBits) to decimal, but first ensure it's within the range of an unsigned long long
    if (qyooBits.size() > 64) {
        std::cerr << "Error: qyooBits exceeds 64 bits, cannot convert to unsigned long long." << std::endl;
    } else {
        std::cout << "Binary = " << qyooBits << std::endl;

        feat->dotDecStr = std::to_string(std::stoull(qyooBits, nullptr, 2));  // Convert binary string to decimal
        std::cout << "Qyoo value = " << feat->dotDecStr << std::endl;
    }

    delete radFilter;

}

FeatureProcessor::FeatureProcessor(UIImage *inImage, int processSizeX, int processSizeY, bool flip, bool vertFlip)
{
    grayImg = NULL;
    gaussImg = NULL;
    gradImg = NULL;
    thetaImg = NULL;
    featImg = NULL;
    numFound = 0;

    grayImg = new RawImageGray8(processSizeX,processSizeY);
    grayImg->renderFromImage(inImage,flip,vertFlip);
    grayImg->runContrast();
}

// Destructor for FeatureProcessor
FeatureProcessor::~FeatureProcessor()
{
    delete gaussFilter;
    delete grayImg;
    delete gaussImg;
    delete gradImg;
    delete thetaImg;
    delete featImg;
    for (auto *dot : featureDots)
        delete dot;
}

// Process the image to detect edges and gradients
void FeatureProcessor::processImage()
{
    gaussFilter = MakeGaussianFilter_1_4();
    gaussImg = new RawImageGray8(grayImg->getSizeX(), grayImg->getSizeY());

    // Apply Gaussian filter to reduce noise
    gaussFilter->processImage(grayImg, gaussImg);

    // Compute gradient and edge angle
    gradImg = new RawImageGray32(grayImg->getSizeX(), grayImg->getSizeY());
    thetaImg = new RawImageGray8(grayImg->getSizeX(), grayImg->getSizeY());
    CannyGradientAndTheta(gaussImg, gradImg, thetaImg);

    // Suppress non-maximum values to highlight edges
    CannyNonMaxSupress(gradImg, thetaImg, 60.0);
}

// Find valid Qyoo features
int FeatureProcessor::findQyoo()
{
    logVerbose("Starting Qyoo detection...");

    featImg = new RawImageGray32(grayImg->getSizeX(), grayImg->getSizeY());
    CannyFindFeatures(gradImg, thetaImg, 10.0, 60.0, feats, featImg);

    logVerbose("Number of features detected: " + std::to_string(feats.size()) );

    // Iterate over the detected features and validate them
    numFound = 0;
    for (unsigned int ii = 0; ii < feats.size(); ii++)
    {
        Feature &feat = feats[ii];

        feat.imgSizeX = grayImg->getSizeX();
        feat.imgSizeY = grayImg->getSizeY();

        feat.calcClosed(ClosedDist * ClosedDist);
        feat.decimate(DecimateDist * DecimateDist);
        feat.checkSizeAndPosition(grayImg->getSizeX(), grayImg->getSizeY());

        if (feat.valid)
        {
            feat.findCorner();
            feat.refineCornerAndFindAngles(10 * 10);
            feat.modelCheck(0.04 * 0.04, 0.8);
        }

        if (feat.valid)
        {
            logVerbose("Qyoo shape feature found!");
            numFound++;
        }
    }

    logVerbose("Total Qyoo shapes detected: " + std::to_string(numFound) );
    return numFound;
}

// Detect dots in the valid Qyoo features

void FeatureProcessor::findDots(UIImage *inImage, bool flip, bool vertFlip)
{
    for (auto &feat : feats)
    {
        if (feat.valid)
        {
            FeatureDotsProcessor *featDots = new FeatureDotsProcessor(inImage,this,&feat,flip,vertFlip);
            featDots->findDotsGray();
            featureDots.push_back(featDots);
        }
    }
}
