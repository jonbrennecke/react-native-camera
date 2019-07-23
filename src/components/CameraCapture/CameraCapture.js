// @flow
import React from 'react';
import { View, StyleSheet } from 'react-native';

import { Camera } from '../Camera';
import { CaptureButton } from '../CaptureButton';
import { CameraFocusArea } from '../CameraFocusArea';
import { RangeInputDial } from '../RangeInputDial';
import { CameraSettingsSelect } from '../CameraSettingsSelect';
import { Units, CameraSettingIdentifiers } from '../../constants';
import {
  shouldDisplayIntegerValues,
  makeDefaultValueFormatter,
} from '../../utils';

import type { SFC, Style, ReturnType } from '../../types';
import type { CameraISORange } from '../../state';

const styles = {
  flex: {
    flex: 1,
  },
  absoluteFill: {
    ...StyleSheet.absoluteFillObject,
  },
  container: {
    backgroundColor: '#000',
  },
  bottomControls: {
    flexDirection: 'column',
  },
  cameraWrap: {
    flex: 1,
    borderRadius: Units.small,
    overflow: 'hidden',
  },
  cameraControlsRow: {
    paddingVertical: Units.small,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
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
  cameraRef: ((?Camera) => void) | ReturnType<typeof React.createRef>,
  activeCameraSetting: $Keys<typeof CameraSettingIdentifiers>,
  cameraSettings: CameraSettings,
  supportedISORange: CameraISORange,
  onRequestFocus: ({ x: number, y: number }) => void,
  onRequestChangeISO: number => void,
  onRequestChangeExposure: number => void,
  onRequestSelectActiveCameraSetting: (
    $Keys<typeof CameraSettingIdentifiers>
  ) => void,
  onRequestBeginCapture: () => void,
  onRequestEndCapture: () => void,
};

export const CameraCapture: SFC<CameraCaptureProps> = ({
  style,
  cameraRef,
  cameraSettings,
  activeCameraSetting,
  onRequestFocus,
  onRequestChangeISO,
  onRequestChangeExposure,
  onRequestSelectActiveCameraSetting,
  onRequestBeginCapture,
  onRequestEndCapture,
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
      <View style={styles.cameraWrap}>
        <Camera ref={cameraRef} style={styles.flex} />
        <CameraFocusArea
          style={styles.absoluteFill}
          onRequestFocus={onRequestFocus}
        />
      </View>
      <View style={styles.bottomControls}>
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
        <View style={styles.cameraControlsRow}>
          <CaptureButton
            onRequestBeginCapture={onRequestBeginCapture}
            onRequestEndCapture={onRequestEndCapture}
          />
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
