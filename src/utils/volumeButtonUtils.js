// @flow
import { NativeModules, NativeEventEmitter } from 'react-native';

const { HSVolumeButtonObserver: NativeVolumeButtonObserver } = NativeModules;
const VolumeButtonObserverEventEmitter = new NativeEventEmitter(
  NativeVolumeButtonObserver
);

export const VolumeButtonEvents = {
  DidChangeVolume: 'volumeButtonObserverDidChangeVolume',
  DidEncounterError: 'volumeButtonObserverDidEncounterError',
};

export const addVolumeButtonListener = (listener: (volume: number) => void) => {
  return VolumeButtonObserverEventEmitter.addListener(
    VolumeButtonEvents.DidChangeVolume,
    ({ volume }) => listener(volume)
  );
};
