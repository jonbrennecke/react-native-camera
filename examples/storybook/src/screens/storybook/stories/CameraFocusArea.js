// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { withKnobs } from '@storybook/addon-knobs';
import { SafeAreaView, StyleSheet, Animated } from 'react-native';
import noop from 'lodash/noop';

import {
  Camera,
  CameraFocusArea,
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
  focusArea: StyleSheet.absoluteFill,
  focus: (position: Animated.ValueXY, touch: Animated.Value) => ({
    height: 100,
    width: 100,
    left: -50,
    top: -50,
    backgroundColor: 'red',
    transform: [
      {
        translateX: position.x
      },
      {
        translateY: position.y
      }
    ],
    opacity: touch
  }),
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
stories.add('Camera Focus Area', () => (
  <SafeAreaView style={styles.flex}>
    <StorybookAsyncWrapper
      loadAsync={loadAsync}
      render={() => (
        <>
          <Camera
            style={styles.camera}
            cameraPosition="front"
            previewMode="normal"
          />
          <CameraFocusArea
            style={styles.focusArea}
            onRequestFocus={noop}
            renderFocusArea={(positionAnim, touchAnim) => (
              <Animated.View style={styles.focus(positionAnim, touchAnim)} />
            )}
          />
        </>
      )}
    />
  </SafeAreaView>
));
