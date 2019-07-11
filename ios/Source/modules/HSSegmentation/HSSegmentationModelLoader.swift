import CoreML
import Foundation

public struct HSSegmentationModelLoader {
  public enum LoadModelError {
    case failedToDownloadModel
    case failedToCompileModel
    case failedToSaveModel
  }

  private static let sessionConfig = URLSessionConfiguration.default

  // TODO: read from environment variable
  private static let urlProtocol = "http://"
  private static let address = "192.168.254.24"
//  private static let address = "172.20.10.2"
  private static let port = "8000"
  private static let modelFileName = "SegmentationModel.mlmodel"

  private static let modelURL: URL = {
    URL(string: "\(urlProtocol)\(address):\(port)/\(modelFileName)")!
  }()

  private static let fileManager = FileManager.default

  private static func downloadModel(_ completionHandler: @escaping (Result<URL, Error>) -> Void) {
    let session = URLSession(configuration: sessionConfig)
    var request = URLRequest(url: modelURL)
    request.httpMethod = "GET"
    let task = session.downloadTask(with: request) { url, _, error in
      if let error = error {
        completionHandler(.err(error))
        return
      }
      completionHandler(.ok(url!))
    }
    task.resume()
  }

  private static func compileModel(at url: URL, _ completionHandler: @escaping (Result<HSSegmentationModel, LoadModelError>) -> Void) {
    guard let tmpURL = try? MLModel.compileModel(at: url) else {
      completionHandler(.err(.failedToCompileModel))
      return
    }

    guard let compiledModelURL = try? fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: tmpURL,
      create: true
    ) else {
      completionHandler(.err(.failedToCompileModel))
      return
    }
    do {
      if fileManager.fileExists(atPath: compiledModelURL.relativePath) {
        _ = try fileManager.replaceItemAt(compiledModelURL, withItemAt: tmpURL)
      } else {
        try fileManager.copyItem(at: tmpURL, to: compiledModelURL)
      }
    } catch {
      completionHandler(.err(.failedToCompileModel))
    }

    guard let model = try? HSSegmentationModel(contentsOf: compiledModelURL) else {
      completionHandler(.err(.failedToCompileModel))
      return
    }
    completionHandler(.ok(model))
  }

  private static func saveModel(at url: URL) -> URL? {
    guard let filesURL = try? fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ) else {
      return nil
    }
    let modelFileURL = filesURL
      .appendingPathComponent("SegmentationModel")
      .appendingPathExtension("mlmodel")
    do {
      if fileManager.fileExists(atPath: modelFileURL.relativePath) {
        _ = try fileManager.replaceItemAt(modelFileURL, withItemAt: url)
      } else {
        try fileManager.copyItem(at: url, to: modelFileURL)
      }
    } catch {
      return nil
    }
    return modelFileURL
  }

  internal static func loadModel(_ completionHandler: @escaping (Result<HSSegmentationModel, LoadModelError>) -> Void) {
    downloadModel { result in
      switch result {
      case let .ok(downloadedURL):
        guard let modelFileURL = saveModel(at: downloadedURL) else {
          completionHandler(.err(.failedToSaveModel))
          return
        }
        compileModel(at: modelFileURL) { result in
          completionHandler(result)
        }
      case .err:
        completionHandler(.err(.failedToDownloadModel))
        return
      }
    }
  }
}
