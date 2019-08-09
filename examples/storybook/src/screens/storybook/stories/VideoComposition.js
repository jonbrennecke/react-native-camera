// @flow
import React, { Component, createRef } from 'react';
import { storiesOf } from '@storybook/react-native';
import { withKnobs, select, button } from '@storybook/addon-knobs';
import { SafeAreaView } from 'react-native';

import {
  authorizeMediaLibrary,
  queryVideos,
} from '@jonbrennecke/react-native-media';
import { VideoComposition } from '@jonbrennecke/react-native-camera';

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

type Props = {};

type State = {
  asset: ?MediaObject
};

class StoryComponent extends Component<Props, State> {
  state = {
    asset: null
  };
  compositionRef = createRef()

  async componentDidMount() {
    await authorizeMediaLibrary();
    const assets = await queryVideos({ limit: 1 });
    if (!assets.length) {
      throw 'Could not find a video in the media library';
    }
    const asset = assets[0];
    this.setState({ asset });
  }

  configureButtons() {
    button('Play', () => {
      if (this.compositionRef.current) {
        this.compositionRef.current.play();
      }
    });
    button('Pause', () => {
      if (this.compositionRef.current) {
        this.compositionRef.current.pause();
      }
    });
    button('Seek to middle', () => {
      if (this.compositionRef.current) {
        this.compositionRef.current.seekToProgress(0.5);
      }
    });
  }

  render() {
    this.configureButtons();
    const { asset } = this.state;
    return (
      <VideoComposition
        ref={this.compositionRef}
        style={styles.flex}
        assetID={asset?.assetID}
        previewMode={select(
          'Preview mode',
          {
            Normal: 'normal',
            Depth: 'depth',
            'Portrait mode': 'portraitMode',
          },
          'portraitMode'
        )}
        resizeMode={select(
          'Resize mode',
          {
            'Scale to fit width': 'scaleAspectWidth',
            'Scale to fit height': 'scaleAspectHeight',
            'Scale to fill': 'scaleAspectFill',
          },
          'scaleAspectWidth'
        )}
      />
    );
  }
}

const stories = storiesOf('Media Effects', module)
stories.addDecorator(withKnobs);
stories.add('Video Composition', () => (
  <SafeAreaView style={styles.safeArea}>
    <StoryComponent/>
  </SafeAreaView>
));
