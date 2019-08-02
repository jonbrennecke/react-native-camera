// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { SafeAreaView, Modal, View } from 'react-native';
import { Provider } from 'react-redux';
import noop from 'lodash/noop';

import {
  CameraSettingIdentifiers,
  createCameraStateHOC,
  CameraCapture,
  requestCameraPermissions,
  startCameraPreview,
  CameraFormatList,
  CameraFormatListItem,
  filterBestAvailableFormats,
  uniqueKeyForFormat,
  areFormatsEqual,
  startCameraEffects
} from '@jonbrennecke/react-native-camera';

import { createReduxStore } from './cameraStore';
import { StorybookStateWrapper } from '../../utils';

const store = createReduxStore();

const styles = {
  flex: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    backgroundColor: '#000',
  },
  camera: {
    flex: 1,
  },
  modal: {
    position: 'absolute',
    height: 300,
    width: '100%',
    backgroundColor: '#000',
    bottom: 0,
  },
  thumbnail: {
    backgroundColor: '#000',
    flex: 1,
  }
};

const CameraStateContainer = createCameraStateHOC();

const Component = CameraStateContainer(
  ({
    startCapture,
    stopCapture,
    iso,
    exposure,
    format: activeFormat,
    supportedISORange,
    supportedExposureRange,
    supportedFormats,
    loadSupportedFeatures,
    updateISO,
    updateExposure,
    updateFormat
  }) => {
    const setup = async (): Promise<void> => {
      try {
        await requestCameraPermissions();
        startCameraPreview();
        await startCameraEffects();
        await loadSupportedFeatures();
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error(error);
      }
    };
    return (
      <StorybookStateWrapper
        initialState={{
          showFormatModal: false,
          enableDepthPreview: false,
          cameraRef: React.createRef(),
          activeCameraSetting: CameraSettingIdentifiers.Exposure,
        }}
        onMount={setup}
        render={(getState, setState) => {
          return (
            <>
              <Modal
                transparent
                visible={getState().showFormatModal}
              >
                <View style={styles.modal}>
                  <CameraFormatList
                    style={styles.flex}
                    items={filterBestAvailableFormats(supportedFormats)}
                    keyForItem={({ format, depthFormat }) => uniqueKeyForFormat(format, depthFormat)}
                    renderItem={({ format, depthFormat }) => (
                      <CameraFormatListItem
                        isActive={areFormatsEqual(format, activeFormat)}
                        format={format}
                        depthFormat={depthFormat}
                        onPress={() => {
                          updateFormat(format, depthFormat);
                          setState({ showFormatModal: false })
                        }}
                      />
                    )}
                  />
                </View>
              </Modal>
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
                cameraLayoutStyle="fullscreen"
                supportedISORange={supportedISORange}
                activeCameraSetting={getState().activeCameraSetting}
                enableDepthPreview={getState().enableDepthPreview}
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
                onRequestSelectActiveCameraSetting={cameraSetting => {
                  setState({ activeCameraSetting: cameraSetting });
                }}
                onRequestShowFormatDialog={() => setState({ showFormatModal: true })}
                onRequestToggleDepthPreview={() => setState({ enableDepthPreview: !getState().enableDepthPreview })}
                onPressThumbnailButton={() => console.log('onPressThumbnailButton')}
                renderThumbnail={() => <View style={styles.thumbnail}/>}
              />
            </>
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
