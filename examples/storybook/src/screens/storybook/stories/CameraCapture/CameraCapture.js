// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { SafeAreaView, Button } from 'react-native';
import { Provider } from 'react-redux';

import {
  Camera,
  requestCameraPermissions,
  startCameraPreview,
  createCameraStateHOC
} from '@jonbrennecke/react-native-camera';

import { createReduxStore } from './cameraCaptureStore';
import { StorybookStateWrapper } from '../../utils';

type State = {};

const store = createReduxStore();

const styles = {
  flex: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    backgroundColor: '#222',
  },
};

const initialState: State = {};

const CameraStateContainer = createCameraStateHOC(
  state => state.camera
);

const Component = CameraStateContainer(
  ({
    startCapture,
    stopCapture,
    captureStatus
  }) => {
    const setup = async (getState, setState): Promise<void> => {
      try {
        await requestCameraPermissions();
        startCameraPreview();
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error(error);
      }
    };
    const stop = () => {
      stopCapture({
        saveToCameraRoll: true,
        metadata: {
          blurAperture: 10,
        }
      });
    };
    return (
      <StorybookStateWrapper
        initialState={initialState}
        onMount={setup}
        render={getState => (
          <>
            <Camera
              style={styles.flex}
              cameraPosition="front"
              previewMode="normal"
              resizeMode="scaleAspectWidth"
            />
            <Button
              title={captureStatus === 'started' ? 'Stop' : 'Start'}
              onPress={() => captureStatus === 'started' ? stop() : startCapture()}
            />
          </>
        )}
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
