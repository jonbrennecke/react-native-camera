// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { withKnobs, select, number, boolean } from '@storybook/addon-knobs';
import { SafeAreaView } from 'react-native';

import {
  Camera,
  requestCameraPermissions,
  startCameraPreview,
} from '@jonbrennecke/react-native-camera';

import { StorybookAsyncWrapper } from '../utils';

const styles = {
  flex: {
    flex: 1,
  },
  camera: {
    flex: 1,
  },
};

const loadAsync = async () => {
  try {
    await requestCameraPermissions();
    startCameraPreview();
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(error);
  }
};

const stories = storiesOf('Camera', module);
stories.addDecorator(withKnobs);
stories.add('Camera', () => (
  <SafeAreaView style={styles.flex}>
    <StorybookAsyncWrapper
      loadAsync={loadAsync}
      render={() => (
        <Camera
          style={styles.camera}
          cameraPosition={select(
            'Camera Position',
            {
              Front: 'front',
              Back: 'back',
            },
            'back'
          )}
          previewMode={select(
            'Preview mode',
            {
              Normal: 'normal',
              Depth: 'depth',
              'Portrait mode': 'portraitMode',
            },
            'portraitMode'
          )}
          resizeMode={select(
            'Resize mode',
            {
              'Scale to fit width': 'scaleAspectWidth',
              'Scale to fit height': 'scaleAspectHeight',
              'Scale to fill': 'scaleAspectFill',
            },
            'scaleAspectWidth'
          )}
          isPaused={boolean('Paused', false)}
          blurAperture={number('Blur aperture', 3, {
            range: true,
            min: 1.4,
            max: 20,
            step: 0.1,
          })}
        />
      )}
    />
  </SafeAreaView>
));
