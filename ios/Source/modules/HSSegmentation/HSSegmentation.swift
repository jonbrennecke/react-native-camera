import HSCameraUtils

public class HSSegmentation {
    private let model: HSSegmentationModel
    
    init(model: HSSegmentationModel) {
        self.model = model
    }
    
    public func runSegmentation(
        colorBuffer: HSPixelBuffer<Float32>,
        depthBuffer: HSPixelBuffer<Float32>
        ) throws {
        let input = HSSegmentationModelInput(
            color_image_input: colorBuffer.buffer,
            depth_image_input: depthBuffer.buffer
        )
        let output = try model.prediction(input: input)
        let multiArray = output.segmentation_image_output
        if .float32 != multiArray.dataType {
            return
        }
        //    multiArray.shape
        //    createBuffer(with pixelValues: inout [T], size: Size<Int>, bufferType: BufferType)
        //    return HSPixelBuffer(pixelBuffer: output.segmentation_image_output)
    }
}
