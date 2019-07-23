// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { SafeAreaView } from 'react-native';
import { Provider } from 'react-redux';

import {
  CameraSettingIdentifiers,
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
    iso,
    exposure,
    supportedISORange,
    supportedExposureRange,
    loadSupportedFeatures,
    updateISO,
    updateExposure
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
        initialState={{
          cameraRef: React.createRef(),
          selectedCameraSetting: CameraSettingIdentifiers.Exposure,
        }}
        onMount={setup}
        render={(getState, setState) => {
          return (
            <CameraCapture
              style={styles.camera}
              cameraRef={getState().cameraRef}
              cameraSettings={{
                [CameraSettingIdentifiers.ISO]: {
                  currentValue: iso,
                  supportedRange: supportedISORange,
                },
                [CameraSettingIdentifiers.Exposure]: {
                  currentValue: exposure,
                  supportedRange: supportedExposureRange,
                },
                [CameraSettingIdentifiers.ShutterSpeed]: {
                  currentValue: exposure,
                  supportedRange: supportedExposureRange,
                }, // TODO
                [CameraSettingIdentifiers.Focus]: {
                  currentValue: exposure,
                  supportedRange: supportedExposureRange,
                }, // TODO
                [CameraSettingIdentifiers.WhiteBalance]: {
                  currentValue: exposure,
                  supportedRange: supportedExposureRange,
                }, // TODO
              }}
              supportedISORange={supportedISORange}
              selectedCameraSetting={getState().selectedCameraSetting}
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
              onRequestChangeISO={iso => updateISO(iso)}
              onRequestChangeExposure={exposure => updateExposure(exposure)}
              onRequestChangeSelectedCameraSetting={cameraSetting => {
                setState({ selectedCameraSetting: cameraSetting });
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
