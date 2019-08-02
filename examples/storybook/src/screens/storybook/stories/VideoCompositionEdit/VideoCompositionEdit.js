// @flow
import React from 'react';
import { storiesOf } from '@storybook/react-native';
import { SafeAreaView } from 'react-native';
import { Provider } from 'react-redux';

import {
  authorizeMediaLibrary,
  queryVideos,
} from '@jonbrennecke/react-native-media';
import {
  VideoCompositionEdit,
  wrapWithVideoCompositionEditState,
} from '@jonbrennecke/react-native-camera';

import { createReduxStore } from './videoCompositionEditStore';
import { StorybookStateWrapper } from '../../utils';

import type { MediaObject } from '@jonbrennecke/react-native-media';

type State = {
  asset: ?MediaObject,
};

const store = createReduxStore();

const styles = {
  flex: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    backgroundColor: '#222',
  },
};

const initialState: State = { asset: null };

const VideoCompositionEditStateContainer = wrapWithVideoCompositionEditState(
  state => state.media
);

const Component = VideoCompositionEditStateContainer(
  ({
    playbackTime,
    isDepthPreviewEnabled,
    isPortraitModeEnabled,
    togglePortraitMode,
    toggleDepthPreview,
    exportAsset,
  }) => {
    const setup = async (getState, setState): Promise<void> => {
      try {
        await authorizeMediaLibrary();
        const assets = await queryVideos({ limit: 1 });
        if (!assets.length) {
          throw 'Could not find a video in the media library';
        }
        const asset = assets[0];
        setState({ asset });
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error(error);
      }
    };
    return (
      <StorybookStateWrapper
        initialState={initialState}
        onMount={setup}
        render={getState => (
          <VideoCompositionEdit
            style={styles.flex}
            asset={getState().asset}
            playbackTime={playbackTime}
            enableDepthPreview={isDepthPreviewEnabled}
            enablePortraitMode={isPortraitModeEnabled}
            onRequestTogglePortraitMode={togglePortraitMode}
            onRequestToggleDepthPreview={toggleDepthPreview}
            onRequestExport={() => {
              const { asset } = getState();
              if (!asset) {
                return;
              }
              exportAsset(asset.assetID);
            }}
          />
        )}
      />
    );
  }
);

storiesOf('Media Effects', module).add('Video Composition Edit', () => (
  <Provider store={store}>
    <SafeAreaView style={styles.safeArea}>
      <Component />
    </SafeAreaView>
  </Provider>
));
