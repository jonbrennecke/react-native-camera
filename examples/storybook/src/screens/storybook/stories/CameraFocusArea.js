// @flow
import React, { createRef } from 'react';
import { storiesOf } from '@storybook/react-native';
import { withKnobs, select } from '@storybook/addon-knobs';
import { SafeAreaView, StyleSheet, Animated } from 'react-native';

import {
  Camera,
  CameraFocusArea,
  requestCameraPermissions,
  startCameraPreview,
} from '@jonbrennecke/react-native-camera';

import { StorybookStateWrapper } from '../utils';

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
        translateX: position.x,
      },
      {
        translateY: position.y,
      },
    ],
    opacity: touch,
  }),
};

const loadAsync = async (): Promise<void> => {
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
    <StorybookStateWrapper
      onMount={loadAsync}
      initialState={{ cameraRef: createRef() }}
      render={getState => (
        <>
          <Camera
            style={styles.camera}
            ref={getState().cameraRef}
            cameraPosition="front"
            previewMode={select(
              'Preview mode',
              {
                Normal: 'normal',
                Depth: 'depth',
                'Portrait mode': 'portraitMode',
              },
              'portraitMode'
            )}
          />
          <CameraFocusArea
            style={styles.focusArea}
            onRequestFocus={focusPoint => {
              const { cameraRef } = getState();
              if (cameraRef && cameraRef.current) {
                cameraRef.current.focusOnPoint(focusPoint);
              }
            }}
            renderFocusArea={(positionAnim, touchAnim) => (
              <Animated.View style={styles.focus(positionAnim, touchAnim)} />
            )}
          />
        </>
      )}
    />
  </SafeAreaView>
));
