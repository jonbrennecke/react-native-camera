// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { SafeAreaView } from 'react-native';

import {
  authorizeMediaLibrary,
  queryVideos,
} from '@jonbrennecke/react-native-media';
import { VideoComposition } from '@jonbrennecke/react-native-camera';

import { StorybookStateWrapper } from '../utils';

const styles = {
  flex: {
    flex: 1,
  },
};

const onMount = async (getState, setState): Promise<void> => {
  try {
    await authorizeMediaLibrary();
    const assets = await queryVideos({ limit: 1 });
    if (!assets.length) {
      throw 'Could not find a video in the media library';
    }
    const asset = assets[0];
    setState({ asset });
    // asset.assetID
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(error);
  }
};

storiesOf('Media Effects', module).add('Video Composition', () => (
  <SafeAreaView style={styles.flex}>
    <StorybookStateWrapper
      initialState={{ asset: null }}
      onMount={onMount}
      render={getState => {
        const { asset } = getState();
        return (
          <VideoComposition
            style={styles.flex}
            assetID={asset?.assetID}
            enableDepthPreview={false}
          />
        );
      }}
    />
  </SafeAreaView>
));
