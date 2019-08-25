// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { withKnobs } from '@storybook/addon-knobs';
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
stories.add('Multi Camera', () => (
  <SafeAreaView style={styles.flex}>
    <StorybookAsyncWrapper
      loadAsync={loadAsync}
      render={() => (
        <>
          <Camera
            style={styles.camera}
            cameraPosition="front"
            previewMode="normal"
            resizeMode="scaleAspectWidth"
          />
          <Camera
            style={styles.camera}
            cameraPosition="front"
            previewMode="depth"
            resizeMode="scaleAspectWidth"
          />
        </>
      )}
    />
  </SafeAreaView>
));
