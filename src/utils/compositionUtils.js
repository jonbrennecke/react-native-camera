// @flow
import Bluebird from 'bluebird';
import { NativeModules } from 'react-native';

const { HSEffectCompositor: NativeEffectCompositor } = NativeModules;
const EffectCompositor = Bluebird.promisifyAll(NativeEffectCompositor);

export const createComposition = async (assetID: string) => {
  const ret = await EffectCompositor.createCompositionAsync(assetID);
  console.log(ret);
};
