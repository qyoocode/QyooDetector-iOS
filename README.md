# QyooDetector

QyooDetector is a Swift package that provides image processing capabilities, particularly focused on handling grayscale images. The core functionality includes feature detection, image contrast adjustment, and transformation of images into grayscale. The package leverages Objective-C++ for performance, making it suitable for both modern Swift applications and legacy C++ systems.

## Features

- Grayscale image processing for 8-bit and 32-bit images.
- Conversion of `UIImage` objects to grayscale and feature detection.
- Image contrast scaling for enhancing image clarity.
- Ability to create indexed images using custom color masks.

## Installation

### Using Swift Package Manager

To integrate **QyooDetector** into your project, you can add it as a dependency using Swift Package Manager.

1. In your Xcode project, go to **File > Swift Packages > Add Package Dependency**.
2. Enter the repository URL:
   ```
   https://github.com/yourusername/QyooDetector.git
   ```
3. Choose the latest version and add it to your target.

Alternatively, you can add the package directly to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/qyoocode/QyooDetector-iOS", from: "1.0.0")
]
```

## Package Structure

The package is divided into two main components:
- **Detector**: Contains the Objective-C++ image processing code, which performs the core image manipulation functions.
- **QyooDetector**: Swift-based interface that exposes the image processing functionality for use in Swift projects.

### Key Classes and Methods

#### `RawImageGray8`

This class handles 8-bit grayscale image data.

- **Initialization**:
  ```objc
  RawImageGray8 *image = [[RawImageGray8 alloc] initWithSizeX:100 sizeY:100];
  ```
  
- **Render from `UIImage`**:
  Converts a `UIImage` to a raw grayscale image:
  ```objc
  [image renderFromImage:uiImage flip:NO vertFlip:NO];
  ```

- **Image Contrast**:
  Enhances the contrast of the grayscale image:
  ```objc
  [image runContrast];
  ```

- **Convert back to `UIImage`**:
  Generates a `UIImage` from the raw grayscale data:
  ```objc
  UIImage *outputImage = [image makeImageWithCopy:YES];
  ```

#### `RawImageGray32`

This class handles 32-bit grayscale image data.

- **Initialization**:
  ```objc
  RawImageGray32 *image = [[RawImageGray32 alloc] initWithSizeX:100 sizeY:100];
  ```

- **Create a `UIImage`**:
  ```objc
  UIImage *outputImage = [image makeImageWithZeroAlpha:NO];
  ```

## Usage

Here’s an example of how you can use the package in a Swift-based iOS/macOS project:

```swift
import Detector

class ImageProcessor {
    func processImage(_ image: UIImage) -> UIImage? {
        let rawImage = RawImageGray8(sizeX: Int(image.size.width), sizeY: Int(image.size.height))
        rawImage.renderFromImage(image, flip: false, vertFlip: false)
        rawImage.runContrast()
        return rawImage.makeImageWithCopy(true)
    }
}
```

## Contributing

We welcome contributions to improve the QyooDetector package. If you would like to contribute, please open an issue or submit a pull request.

## License

This project is licensed under the **BSD-3 Clause License**. See the `LICENSE` file for details.
