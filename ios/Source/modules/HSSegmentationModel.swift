import CoreML

/// Model Prediction Input Type
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class HSSegmentationModelInput: MLFeatureProvider {
  /// color_image_input as color (kCVPixelFormatType_32BGRA) image buffer, 1080 pixels wide by 1920 pixels high
  var color_image_input: CVPixelBuffer

  /// depth_image_input as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 1080 pixels wide by 1920 pixels high
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

/// Model Prediction Output Type
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class HSSegmentationModelOutput: MLFeatureProvider {
  /// Source provided by CoreML

  private let provider: MLFeatureProvider

  /// segmentation_image_output as 1 x 1914 x 1080 3-dimensional array of doubles
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

/// Class for model loading and prediction
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class HSSegmentationModel {
  var model: MLModel

  /**
   Construct a model with explicit path to mlmodelc file
   - parameters:
   - url: the file url of the model
   - throws: an NSError object that describes the problem
   */
  init(contentsOf url: URL) throws {
    model = try MLModel(contentsOf: url)
  }

  /**
   Construct a model with explicit path to mlmodelc file and configuration
   - parameters:
   - url: the file url of the model
   - configuration: the desired model configuration
   - throws: an NSError object that describes the problem
   */
  @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
  init(contentsOf url: URL, configuration: MLModelConfiguration) throws {
    model = try MLModel(contentsOf: url, configuration: configuration)
  }

  /**
   Make a prediction using the structured interface
   - parameters:
   - input: the input to the prediction as SegmentationModelInput
   - throws: an NSError object that describes the problem
   - returns: the result of the prediction as SegmentationModelOutput
   */
  func prediction(input: HSSegmentationModelInput) throws -> HSSegmentationModelOutput {
    return try prediction(input: input, options: MLPredictionOptions())
  }

  /**
   Make a prediction using the structured interface
   - parameters:
   - input: the input to the prediction as SegmentationModelInput
   - options: prediction options
   - throws: an NSError object that describes the problem
   - returns: the result of the prediction as SegmentationModelOutput
   */
  func prediction(input: HSSegmentationModelInput, options: MLPredictionOptions) throws -> HSSegmentationModelOutput {
    let outFeatures = try model.prediction(from: input, options: options)
    return HSSegmentationModelOutput(features: outFeatures)
  }

  /**
   Make a prediction using the convenience interface
   - parameters:
   - color_image_input as color (kCVPixelFormatType_32BGRA) image buffer, 1080 pixels wide by 1920 pixels high
   - depth_image_input as grayscale (kCVPixelFormatType_OneComponent8) image buffer, 1080 pixels wide by 1920 pixels high
   - throws: an NSError object that describes the problem
   - returns: the result of the prediction as SegmentationModelOutput
   */
  func prediction(color_image_input: CVPixelBuffer, depth_image_input: CVPixelBuffer) throws -> HSSegmentationModelOutput {
    let input_ = HSSegmentationModelInput(color_image_input: color_image_input, depth_image_input: depth_image_input)
    return try prediction(input: input_)
  }

  /**
   Make a batch prediction using the structured interface
   - parameters:
   - inputs: the inputs to the prediction as [SegmentationModelInput]
   - options: prediction options
   - throws: an NSError object that describes the problem
   - returns: the result of the prediction as [SegmentationModelOutput]
   */
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
