// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { SafeAreaView } from 'react-native';
import { Provider } from 'react-redux';

import {
  createCameraStateHOC,
  CameraCapture,
  requestCameraPermissions,
  startCameraPreview,
} from '@jonbrennecke/react-native-camera';

import { createReduxStore } from './cameraStore';
import { StorybookStateWrapper } from '../../utils';

const store = createReduxStore();

const styles = {
  safeArea: {
    flex: 1,
    backgroundColor: '#000',
  },
  camera: {
    flex: 1,
  },
};

const CameraStateContainer = createCameraStateHOC();

const Component = CameraStateContainer(
  ({
    startCapture,
    stopCapture,
    supportedISORange,
    supportedExposureRange,
    loadSupportedFeatures,
  }) => {
    const setup = async (): Promise<void> => {
      try {
        await requestCameraPermissions();
        startCameraPreview();
        await loadSupportedFeatures();
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error(error);
      }
    };
    return (
      <StorybookStateWrapper
        initialState={{ cameraRef: React.createRef() }}
        onMount={setup}
        render={getState => {
          return (
            <CameraCapture
              style={styles.camera}
              cameraRef={getState().cameraRef}
              supportedISORange={supportedISORange}
              onRequestBeginCapture={startCapture}
              onRequestEndCapture={() =>
                stopCapture({
                  saveToCameraRoll: true,
                })
              }
              onRequestFocus={point => {
                const { cameraRef } = getState();
                if (cameraRef.current) {
                  cameraRef.current.focusOnPoint(point);
                }
              }}
            />
          );
        }}
      />
    );
  }
);

storiesOf('Camera', module).add('Camera Capture', () => (
  <Provider store={store}>
    <SafeAreaView style={styles.safeArea}>
      <Component />
    </SafeAreaView>
  </Provider>
));
