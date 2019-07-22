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
import { StorybookAsyncWrapper } from '../../utils';

const store = createReduxStore();

const styles = {
  safeArea: {
    flex: 1,
    backgroundColor: '#000'
  },
  camera: {
    flex: 1,
  },
};

const CameraStateContainer = createCameraStateHOC();

const Component = CameraStateContainer(({ startCapture, stopCapture }) => {
  return (
    <StorybookAsyncWrapper
      loadAsync={loadAsync}
      render={() => (
        <CameraCapture
          style={styles.camera}
          onRequestBeginCapture={startCapture}
          onRequestEndCapture={() =>
            stopCapture({
              saveToCameraRoll: true,
            })
          }
        />
      )}
    />
  );
});

const loadAsync = async () => {
  try {
    await requestCameraPermissions();
    startCameraPreview();
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(error);
  }
};

storiesOf('Camera', module).add('Camera Capture', () => (
  <Provider store={store}>
    <SafeAreaView style={styles.safeArea}>
      {/* $FlowFixMe */}
      <Component />
    </SafeAreaView>
  </Provider>
));
