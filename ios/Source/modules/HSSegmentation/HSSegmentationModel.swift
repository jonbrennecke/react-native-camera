import CoreML
import HSCameraUtils

@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class HSSegmentationModelInput: MLFeatureProvider {
  var color_image_input: CVPixelBuffer
  var depth_image_input: CVPixelBuffer
  var featureNames: Set<String> {
    return ["color_image_input", "depth_image_input"]
  }

  func featureValue(for featureName: String) -> MLFeatureValue? {
    if featureName == "color_image_input" {
      return MLFeatureValue(pixelBuffer: color_image_input)
    }
    if featureName == "depth_image_input" {
      return MLFeatureValue(pixelBuffer: depth_image_input)
    }
    return nil
  }

  init(color_image_input: CVPixelBuffer, depth_image_input: CVPixelBuffer) {
    self.color_image_input = color_image_input
    self.depth_image_input = depth_image_input
  }
}

@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class HSSegmentationModelOutput: MLFeatureProvider {
  private let provider: MLFeatureProvider

  lazy var segmentation_image_output: MLMultiArray = {
    [unowned self] in self.provider.featureValue(for: "segmentation_image_output")!.multiArrayValue
  }()!

  var featureNames: Set<String> {
    return provider.featureNames
  }

  func featureValue(for featureName: String) -> MLFeatureValue? {
    return provider.featureValue(for: featureName)
  }

  init(segmentation_image_output: MLMultiArray) {
    provider = try! MLDictionaryFeatureProvider(dictionary: ["segmentation_image_output": MLFeatureValue(multiArray: segmentation_image_output)])
  }

  init(features: MLFeatureProvider) {
    provider = features
  }
}

@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
internal class HSSegmentationModel {
  private var model: MLModel

  public enum InputKey: String {
    case cameraImage = "color_image_input"
    case depthImage = "depth_image_input"

    public var stringValue: String {
      return rawValue
    }
  }

  public enum OutputKey: String {
    case segmentationImage = "segmentation_image_output"

    public var stringValue: String {
      return rawValue
    }
  }

  init(contentsOf url: URL) throws {
    model = try MLModel(contentsOf: url)
  }

  @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
  init(contentsOf url: URL, configuration: MLModelConfiguration) throws {
    model = try MLModel(contentsOf: url, configuration: configuration)
  }

  internal func sizeOf(input: InputKey) -> Size<Int>? {
    guard
      let featureDescription = model.modelDescription.inputDescriptionsByName[input.stringValue],
      let constraint = featureDescription.imageConstraint
    else {
      return nil
    }
    return Size(width: constraint.pixelsWide, height: constraint.pixelsHigh)
  }

  internal func sizeOf(output: OutputKey) -> Size<Int>? {
    guard
      let featureDescription = model.modelDescription.outputDescriptionsByName[output.stringValue],
      let constraint = featureDescription.multiArrayConstraint
    else {
      return nil
    }
    let height = constraint.shape[1].intValue
    let width = constraint.shape[2].intValue
    return Size(width: width, height: height)
  }

  func prediction(input: HSSegmentationModelInput) throws -> HSSegmentationModelOutput {
    return try prediction(input: input, options: MLPredictionOptions())
  }

  func prediction(input: HSSegmentationModelInput, options: MLPredictionOptions) throws -> HSSegmentationModelOutput {
    let outFeatures = try model.prediction(from: input, options: options)
    return HSSegmentationModelOutput(features: outFeatures)
  }

  func prediction(color_image_input: CVPixelBuffer, depth_image_input: CVPixelBuffer) throws -> HSSegmentationModelOutput {
    let input_ = HSSegmentationModelInput(color_image_input: color_image_input, depth_image_input: depth_image_input)
    return try prediction(input: input_)
  }

  @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
  func predictions(inputs: [HSSegmentationModelInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [HSSegmentationModelOutput] {
    let batchIn = MLArrayBatchProvider(array: inputs)
    let batchOut = try model.predictions(from: batchIn, options: options)
    var results: [HSSegmentationModelOutput] = []
    results.reserveCapacity(inputs.count)
    for i in 0 ..< batchOut.count {
      let outProvider = batchOut.features(at: i)
      let result = HSSegmentationModelOutput(features: outProvider)
      results.append(result)
    }
    return results
  }
}
