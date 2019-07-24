// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { SafeAreaView } from 'react-native';

import {
  authorizeMediaLibrary,
  queryVideos,
} from '@jonbrennecke/react-native-media';
import { VideoCompositionEdit } from '@jonbrennecke/react-native-camera';

import { StorybookStateWrapper } from '../utils';

import type { MediaObject } from '@jonbrennecke/react-native-media';

const styles = {
  flex: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    backgroundColor: '#000',
  },
};

const initialState: { asset: ?MediaObject } = { asset: null };

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

storiesOf('Media Effects', module).add('Video Composition Edit', () => (
  <SafeAreaView style={styles.safeArea}>
    <StorybookStateWrapper
      initialState={initialState}
      onMount={onMount}
      render={getState => {
        const { asset } = getState();
        return (
          <VideoCompositionEdit
            style={styles.flex}
            assetID={asset?.assetID}
            enableDepthPreview={false}
          />
        );
      }}
    />
  </SafeAreaView>
));
