// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { SafeAreaView, View } from 'react-native';

import { authorizeMediaLibrary, queryVideos } from '@jonbrennecke/react-native-media';
import { createComposition } from '@jonbrennecke/react-native-camera';

import { StorybookAsyncWrapper } from '../utils';

const styles = {
  flex: {
    flex: 1,
  },
};

const loadAsync = async () => {
  try {
    await authorizeMediaLibrary();
    const assets = await queryVideos({ limit: 1 });
    if (!assets.length) {
      throw 'Could not find a video in the media library';
    }
    const asset = assets[0];
    await createComposition(asset.assetID);
  }
  catch (error) {
    // eslint-disable-next-line no-console
    console.error(error);
  }
};

storiesOf('Media Effects', module).add('Effect Composition', () => (
  <SafeAreaView style={styles.flex}>
    <StorybookAsyncWrapper
      loadAsync={loadAsync}
      render={() => (
        <View />
      )}
    />
  </SafeAreaView>
));
