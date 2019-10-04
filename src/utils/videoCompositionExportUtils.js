// @flow
import Bluebird from 'bluebird';
import { NativeModules, NativeEventEmitter } from 'react-native';

const {
  HSVideoCompositionExportManager: NativeVideoCompositionExportManager,
} = NativeModules;
const VideoCompositionExportManager = Bluebird.promisifyAll(
  NativeVideoCompositionExportManager
);

const VideoCompositionExportManagerEventEmitter = new NativeEventEmitter(
  NativeVideoCompositionExportManager
);

export const VideoCompositionExportManagerEvents = {
  DidFinishExport: 'videoExportManagerDidFinish',
  DidFail: 'videoExportManagerDidFail',
  DidUpdateProgress: 'videoExportManagerDidUpdateProgress',
};

export const exportComposition = async (
  assetID: string,
  config?: { blurAperture?: number, watermarkImageNameWithExtension?: ?string }
) => {
  await VideoCompositionExportManager.exportAsync(assetID, config);
};

export const addVideoCompositionExportProgressListener = (
  listener: (progress: number) => void
) => {
  return VideoCompositionExportManagerEventEmitter.addListener(
    VideoCompositionExportManagerEvents.DidUpdateProgress,
    ({ progress }) => listener(progress)
  );
};

export const addVideoCompositionExportFinishedListener = (
  listener: (url: string) => void
) => {
  return VideoCompositionExportManagerEventEmitter.addListener(
    VideoCompositionExportManagerEvents.DidFinishExport,
    ({ url }) => listener(url)
  );
};

export const addVideoCompositionExportFailedListener = (
  listener: (error: Error) => void
) => {
  return VideoCompositionExportManagerEventEmitter.addListener(
    VideoCompositionExportManagerEvents.DidFail,
    listener
  );
};
