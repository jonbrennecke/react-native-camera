// @flow
import React, { PureComponent } from 'react';
import { Provider } from 'react-redux';
import { storiesOf } from '@storybook/react-native';
import { withKnobs } from '@storybook/addon-knobs';
import { SafeAreaView, Button } from 'react-native';
import { autobind } from 'core-decorators';
import {
  VideoComposition,
  exportComposition,
  addVideoCompositionExportFinishedListener,
  addVideoCompositionExportProgressListener,
} from '@jonbrennecke/react-native-camera';
import {
  authorizeMediaLibrary,
  createMediaStateHOC,
} from '@jonbrennecke/react-native-media';

import { createReduxStore } from './store';

import type { CameraStateHOCProps } from '@jonbrennecke/react-native-camera';
import type { MediaStateHOCProps } from '@jonbrennecke/react-native-media';

const styles = {
  flex: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    backgroundColor: '#000',
    alignItems: 'center',
    justifyContent: 'center',
  },
};

const store = createReduxStore();

// $FlowFixMe
@createMediaStateHOC(state => state.media)
@autobind
class StoryComponent extends PureComponent<MediaStateHOCProps> {
  async componentDidMount() {
    await authorizeMediaLibrary();
    await this.props.queryMedia({ limit: 1, mediaType: 'video' });
    addVideoCompositionExportFinishedListener(this.handleExportDidFinish);
    addVideoCompositionExportProgressListener(this.handleExportProgress);
  }

  handleExportProgress(progress: number) {
    // eslint-disable-next-line no-console
    console.log(`progress: ${progress}`);
  }

  handleExportDidFinish(url: string) {
    // eslint-disable-next-line no-console
    console.log('finished export', url);
  }

  render() {
    return (
      <SafeAreaView style={styles.safeArea}>
        {/* <VideoComposition
        /> */}
        <Button
          title="Export"
          onPress={() => {
            const lastAsset = this.props.assets.last();
            console.log(lastAsset);
            exportComposition(lastAsset.assetID);
          }}
        />
      </SafeAreaView>
    );
  }
}

const stories = storiesOf('Media Effects', module);
stories.addDecorator(withKnobs);
stories.add('Video Composition Export', () => (
  <Provider store={store}>
    {/* $FlowFixMe */}
    <StoryComponent />
  </Provider>
));
