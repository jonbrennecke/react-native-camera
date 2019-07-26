// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { View, SafeAreaView } from 'react-native';
import noop from 'lodash/noop';

import {
  CameraFormatList,
  CameraFormatListItem,
  requestCameraPermissions,
  getSupportedFormats,
  filterBestAvailableFormats,
  uniqueKeyForFormat
} from '@jonbrennecke/react-native-camera';

import { StorybookStateWrapper } from '../utils';

import type { CameraFormat } from '@jonbrennecke/react-native-camera';

type State = {
  bestAvailableFormats: { depthFormat: CameraFormat, format: CameraFormat }[]
};

const styles = {
  flex: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    backgroundColor: '#000',
  }
};

const initialState: State = { bestAvailableFormats: [] };

const setup = async (getState, setState): Promise<void> => {
  try {
    await requestCameraPermissions();
    const formats = await getSupportedFormats();
    const bestAvailableFormats = filterBestAvailableFormats(formats);
    setState({ bestAvailableFormats })
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(error);
  }
};

storiesOf('Camera', module).add('Camera Format List', () => (
  <SafeAreaView style={styles.safeArea}>
    <StorybookStateWrapper
      initialState={initialState}
      onMount={setup}
      render={(getState) => (
        <View style={styles.flex}>
          <CameraFormatList
            style={styles.flex}
            items={Object.values(getState().bestAvailableFormats)}
            keyForItem={({ format, depthFormat }) => uniqueKeyForFormat(format, depthFormat)}
            renderItem={({ format, depthFormat }) => (
              <CameraFormatListItem
                format={format}
                depthFormat={depthFormat}
                onPress={noop}
              />
            )}
          />
        </View>
      )}
    />
  </SafeAreaView>
));
