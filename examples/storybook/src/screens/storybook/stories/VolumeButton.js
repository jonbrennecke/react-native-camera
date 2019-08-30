// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { withKnobs } from '@storybook/addon-knobs';
import { SafeAreaView } from 'react-native';

import {
  HiddenVolume,
  addVolumeButtonListener,
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
    addVolumeButtonListener(volume => console.log(`volume: ${volume}`));
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(error);
  }
};

const stories = storiesOf('Events', module);
stories.addDecorator(withKnobs);
stories.add('Volume Button Events', () => (
  <SafeAreaView style={styles.flex}>
    <StorybookAsyncWrapper
      loadAsync={loadAsync}
      render={() => <HiddenVolume />}
    />
  </SafeAreaView>
));
