// @flow
/* eslint flowtype/generic-spacing: 0 */
import React, { PureComponent } from 'react';
import { createMediaStateHOC } from '@jonbrennecke/react-native-media';
import { autobind } from 'core-decorators';
import identity from 'lodash/identity';

import type { ComponentType } from 'react';
import type {
  MediaStateHOCProps,
  IMediaState,
} from '@jonbrennecke/react-native-media';

export type VideoCompositionEditState = {
  playbackTime: number,
  isPortraitModeEnabled: boolean,
};

export type VideoCompositionEditStateExtraProps = {
  togglePortraitMode: () => void,
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
        playbackTime: 0,
        isPortraitModeEnabled: false,
      };

      togglePortraitMode() {
        this.setState({
          isPortraitModeEnabled: !this.state.isPortraitModeEnabled,
        });
      }

      render() {
        return (
          <WrappedComponent
            {...this.props}
            {...this.state}
            togglePortraitMode={this.togglePortraitMode}
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
