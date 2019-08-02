// @flow
/* eslint flowtype/generic-spacing: 0 */
import React, { PureComponent } from 'react';
import { createMediaStateHOC } from '@jonbrennecke/react-native-media';
import { autobind } from 'core-decorators';
import identity from 'lodash/identity';

import {
  exportComposition,
  addVideoCompositionExportProgressListener,
  addVideoCompositionExportFinishedListener,
  addVideoCompositionExportFailedListener,
} from '../../utils';

import type { ComponentType } from 'react';
import type {
  MediaStateHOCProps,
  IMediaState,
} from '@jonbrennecke/react-native-media';

import type { ReturnType } from '../../types';

export type VideoCompositionEditState = {
  exportProgress: number,
  playbackTime: number,
  isPortraitModeEnabled: boolean,
  isDepthPreviewEnabled: boolean,
};

export type VideoCompositionEditStateExtraProps = {
  togglePortraitMode: () => void,
  toggleDepthPreview: () => void,
  exportAsset: (assetID: string) => Promise<void>,
} & VideoCompositionEditState;

export function wrapWithVideoCompositionEditState<
  State,
  PassThroughProps: Object,
  C: ComponentType<
    VideoCompositionEditStateExtraProps & MediaStateHOCProps & PassThroughProps
  >
>(
  mediaStateSliceAccessor?: State => IMediaState = identity
): (WrappedComponent: C) => ComponentType<PassThroughProps> {
  return (WrappedComponent: C): ComponentType<PassThroughProps> => {
    // $FlowFixMe
    @autobind
    class VideoCompositionEditStateComponent extends PureComponent<
      MediaStateHOCProps & PassThroughProps,
      VideoCompositionEditState
    > {
      state: VideoCompositionEditState = {
        exportProgress: 0,
        playbackTime: 0,
        isPortraitModeEnabled: true,
        isDepthPreviewEnabled: false,
      };
      exportListener: ?ReturnType<
        typeof addVideoCompositionExportProgressListener
      >;
      exportFinishedListener: ?ReturnType<
        typeof addVideoCompositionExportFinishedListener
      >;
      exportFailedListener: ?ReturnType<
        typeof addVideoCompositionExportFailedListener
      >;

      togglePortraitMode() {
        this.setState({
          isPortraitModeEnabled: !this.state.isPortraitModeEnabled,
        });
      }

      toggleDepthPreview() {
        this.setState({
          isDepthPreviewEnabled: !this.state.isDepthPreviewEnabled,
        });
      }

      async exportAsset(assetID: string) {
        this.exportListener = addVideoCompositionExportProgressListener(
          this.onExportProgress
        );
        this.exportFinishedListener = addVideoCompositionExportFinishedListener(
          this.onExportFinished
        );
        this.exportFailedListener = addVideoCompositionExportFailedListener(
          this.onExportFailed
        );
        await exportComposition(assetID);
      }

      onExportProgress(progress: number) {
        this.setState({ exportProgress: progress });
      }

      onExportFinished(url: string) {
        console.log('export finished', url);
      }

      onExportFailed(error: Error) {
        console.warn(error);
      }

      render() {
        return (
          <WrappedComponent
            {...this.props}
            {...this.state}
            togglePortraitMode={this.togglePortraitMode}
            toggleDepthPreview={this.toggleDepthPreview}
            exportAsset={this.exportAsset}
          />
        );
      }
    }

    const withMediaState = createMediaStateHOC(mediaStateSliceAccessor);
    const Component = withMediaState(VideoCompositionEditStateComponent);
    const WrappedWithVideoCompositionEditState = props => (
      <Component {...props} />
    );
    return WrappedWithVideoCompositionEditState;
  };
}
