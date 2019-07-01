// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { SafeAreaView } from 'react-native';

import {
  CameraEffect,
  requestCameraPermissions,
  startCameraPreview,
  startCameraEffects
} from '@jonbrennecke/react-native-camera';

import { StorybookAsyncWrapper } from '../utils';

const styles = {
  flex: {
    flex: 1,
  },
};

const loadAsync = async () => {
  try {
    await requestCameraPermissions();
    startCameraPreview();
    await startCameraEffects();
  }
  catch (error) {
    // eslint-disable-next-line no-console
    console.error(error);
  }
};

storiesOf('Camera', module).add('Camera Effect', () => (
  <SafeAreaView style={styles.flex}>
    <StorybookAsyncWrapper
      loadAsync={loadAsync}
      render={() => (
        <CameraEffect style={styles.flex} />
      )}
    />
  </SafeAreaView>
));
