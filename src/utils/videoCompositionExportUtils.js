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

export const exportComposition = async (assetID: string) => {
  await VideoCompositionExportManager.exportAsync(assetID);
};

export const addVideoCompositionExportProgressListener = (
  listener: (progress: number) => void
) => {
  return VideoCompositionExportManagerEventEmitter.addListener(
    VideoCompositionExportManagerEvents.DidUpdateProgress,
    ({ progress }) => listener(progress)
  );
};
