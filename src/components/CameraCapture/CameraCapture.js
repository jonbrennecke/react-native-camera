// @flow
import React from 'react';
import { View, StyleSheet } from 'react-native';

import { Camera } from '../Camera';
import { CaptureButton } from '../CaptureButton';
import { CameraFocusArea } from '../CameraFocusArea';
import { RangeInputDial } from '../RangeInputDial';
import { ThumbnailButton } from '../';
import { CameraSettingsSelect } from '../CameraSettingsSelect';
import { TopCameraControlsToolbar } from '../cameraControls';
import { Units, CameraSettingIdentifiers } from '../../constants';
import {
  shouldDisplayIntegerValues,
  makeDefaultValueFormatter,
} from '../../utils';

import type { SFC, Style, ReturnType, Children } from '../../types';
import type { CameraISORange } from '../../state';

const styles = {
  flex: {
    flex: 1,
  },
  absoluteFill: StyleSheet.absoluteFillObject,
  container: {
    backgroundColor: '#000',
  },
  bottomControls: {
    flexDirection: 'column',
  },
  cameraControlsRow: {
    paddingVertical: Units.small,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
  },
  captureRowItem: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cameraWrap: (cameraLayoutStyle: 'boxed' | 'fullscreen') =>
    cameraLayoutStyle === 'boxed'
      ? {
          flex: 1,
          borderRadius: Units.small,
          overflow: 'hidden',
        }
      : {
          ...styles.absoluteFill,
          borderRadius: Units.small,
          overflow: 'hidden',
        },
  cameraWrapSpacer: (cameraLayoutStyle: 'boxed' | 'fullscreen') =>
    cameraLayoutStyle === 'boxed'
      ? styles.absoluteFill
      : {
          flex: 1,
        },
  topToolbar: (cameraLayoutStyle: 'boxed' | 'fullscreen') =>
    cameraLayoutStyle === 'boxed'
      ? styles.cameraControlsRow
      : {
          paddingVertical: Units.small,
          flexDirection: 'row',
          justifyContent: 'center',
          alignItems: 'center',
          position: 'absolute',
          top: 0,
          width: '100%',
          zIndex: 2,
        },
};

export type CameraSettings = {
  [key: $Keys<typeof CameraSettingIdentifiers>]: {
    currentValue: number,
    supportedRange: { min: number, max: number },
  },
};

export type CameraCaptureProps = {
  style?: ?Style,
  cameraLayoutStyle?: 'boxed' | 'fullscreen',
  cameraRef: ((?Camera) => void) | ReturnType<typeof React.createRef>,
  activeCameraSetting: $Keys<typeof CameraSettingIdentifiers>,
  cameraSettings: CameraSettings,
  supportedISORange: CameraISORange,
  showManualCameraControls?: boolean,
  enableDepthPreview?: boolean,
  renderThumbnail: () => Children,
  onRequestFocus: ({ x: number, y: number }) => void,
  onRequestChangeISO: number => void,
  onRequestChangeExposure: number => void,
  onRequestSelectActiveCameraSetting: (
    $Keys<typeof CameraSettingIdentifiers>
  ) => void,
  onRequestBeginCapture: () => void,
  onRequestEndCapture: () => void,
  onRequestShowFormatDialog: () => void,
  onRequestToggleDepthPreview: () => void,
  onPressThumbnailButton: () => void,
};

export const CameraCapture: SFC<CameraCaptureProps> = ({
  style,
  cameraRef,
  cameraSettings,
  cameraLayoutStyle = 'boxed',
  activeCameraSetting,
  showManualCameraControls = false,
  enableDepthPreview = false,
  renderThumbnail,
  onRequestFocus,
  onRequestChangeISO,
  onRequestChangeExposure,
  onRequestSelectActiveCameraSetting,
  onRequestBeginCapture,
  onRequestEndCapture,
  onRequestShowFormatDialog,
  onRequestToggleDepthPreview,
  onPressThumbnailButton,
}: CameraCaptureProps) => {
  const updateSelectedCameraSettingValue = (value: number) => {
    switch (activeCameraSetting) {
      case CameraSettingIdentifiers.ISO:
        onRequestChangeISO(value);
        return;
      case CameraSettingIdentifiers.Exposure:
        onRequestChangeExposure(value);
        return;
    }
  };
  return (
    <View style={[styles.container, style]}>
      <TopCameraControlsToolbar
        style={styles.topToolbar(cameraLayoutStyle)}
        onRequestShowFormatDialog={onRequestShowFormatDialog}
        onRequestToggleDepthPreview={onRequestToggleDepthPreview}
      />
      <View style={styles.cameraWrapSpacer(cameraLayoutStyle)} />
      <View style={styles.cameraWrap(cameraLayoutStyle)}>
        <Camera
          style={styles.flex}
          ref={cameraRef}
          isDepthPreviewEnabled={enableDepthPreview}
        />
        <CameraFocusArea
          style={styles.absoluteFill}
          onRequestFocus={onRequestFocus}
        />
      </View>
      <View style={styles.bottomControls}>
        {showManualCameraControls && (
          <>
            <View style={styles.cameraControlsRow}>
              <RangeInputDial
                min={cameraSettings[activeCameraSetting].supportedRange.min}
                max={cameraSettings[activeCameraSetting].supportedRange.max}
                onSelectValue={updateSelectedCameraSettingValue}
              />
            </View>
            <View style={styles.cameraControlsRow}>
              <CameraSettingsSelect
                options={Object.values(CameraSettingIdentifiers)}
                keyForOption={option => `${CameraSettingIdentifiers[option]}`}
                labelTextForOption={option =>
                  formatSettingName(option, cameraSettings)
                }
                isSelectedOption={option => activeCameraSetting === option}
                onRequestSelectOption={onRequestSelectActiveCameraSetting}
              />
            </View>
          </>
        )}
        <View style={styles.cameraControlsRow}>
          <View style={styles.captureRowItem}>
            <ThumbnailButton onPress={onPressThumbnailButton}>
              {renderThumbnail()}
            </ThumbnailButton>
          </View>
          <View style={styles.captureRowItem}>
            <CaptureButton
              onRequestBeginCapture={onRequestBeginCapture}
              onRequestEndCapture={onRequestEndCapture}
            />
          </View>
          <View style={styles.captureRowItem} />
        </View>
      </View>
    </View>
  );
};

const formatSettingName = (
  key: $Keys<typeof CameraSettingIdentifiers>,
  settings: CameraSettings,
  isIntegerValued?: boolean = shouldDisplayIntegerValuesForCameraSettings(
    key,
    settings
  ),
  formatValue?: number => string = makeDefaultValueFormatter(isIntegerValued)
) => {
  return `${abbreviatedSettingName(key)} ${formatValue(
    settings[key].currentValue
  )}`;
};

const shouldDisplayIntegerValuesForCameraSettings = (
  key: $Keys<typeof CameraSettingIdentifiers>,
  settings: CameraSettings
) => {
  return shouldDisplayIntegerValues(
    settings[key].supportedRange.min,
    settings[key].supportedRange.max,
    101
  );
};

const abbreviatedSettingName = (
  key: $Keys<typeof CameraSettingIdentifiers>
) => {
  return {
    [CameraSettingIdentifiers.ShutterSpeed]: 'S',
    [CameraSettingIdentifiers.ISO]: 'ISO',
    [CameraSettingIdentifiers.Exposure]: 'EV',
    [CameraSettingIdentifiers.Focus]: 'F',
    [CameraSettingIdentifiers.WhiteBalance]: 'WB',
  }[key];
};
