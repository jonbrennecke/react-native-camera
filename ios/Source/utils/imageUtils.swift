import CoreGraphics

internal func createImage<T>(
    pixelValues: [T],
    imageSize: Size<Int>,
    colorSpace: CGColorSpace,
    bitmapInfo: CGBitmapInfo,
    bytesPerPixel: Int = MemoryLayout<UInt8>.size
    ) -> CGImage? {
    let bitsPerComponent = 8
    let bitsPerPixel = bytesPerPixel * bitsPerComponent
    let bytesPerRow = bytesPerPixel * imageSize.width
    let totalBytes = imageSize.height * bytesPerRow
    var pixelValues = pixelValues
    return withUnsafePointer(to: &pixelValues) { ptr -> CGImage? in
        let data = UnsafeRawPointer(ptr.pointee).assumingMemoryBound(to: T.self)
        let releaseData: CGDataProviderReleaseDataCallback = {
            (_: UnsafeMutableRawPointer?, _: UnsafeRawPointer, _: Int) -> Void in
        }
        guard let provider = CGDataProvider(dataInfo: nil, data: data, size: totalBytes, releaseData: releaseData) else {
            return nil
        }
        return CGImage(
            width: imageSize.width,
            height: imageSize.height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
