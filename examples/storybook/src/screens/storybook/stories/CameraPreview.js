// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { SafeAreaView } from 'react-native';

import {
  CameraPreview,
  requestCameraPermissions,
  startCameraPreview
} from '@jonbrennecke/react-native-camera';

import { StorybookAsyncWrapper } from '../utils';

const styles = {
  flex: {
    flex: 1,
  },
};

const loadAsync = async () => {
  await requestCameraPermissions();
  startCameraPreview();
};

storiesOf('Camera', module).add('Camera Preview', () => (
  <SafeAreaView style={styles.flex}>
    <StorybookAsyncWrapper
      loadAsync={loadAsync}
      render={() => (
        <CameraPreview style={styles.flex} />
      )}
    />
  </SafeAreaView>
));
