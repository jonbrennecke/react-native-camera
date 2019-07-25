// @flow
import Bluebird from 'bluebird';
import { NativeModules } from 'react-native';

const {
  HSVideoCompositionExportManager: NativeVideoCompositionExportManager,
} = NativeModules;
const VideoCompositionExportManager = Bluebird.promisifyAll(
  NativeVideoCompositionExportManager
);

export const exportComposition = async (assetID: string) => {
  await VideoCompositionExportManager.exportAsync(assetID);
};
