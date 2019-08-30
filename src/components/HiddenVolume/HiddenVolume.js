// @flow
import React from 'react';
import { requireNativeComponent } from 'react-native';

import type { SFC } from '../../types';

export type HiddenVolumeProps = {};

const NativeHiddenVolumeView = requireNativeComponent('HSHiddenVolumeView');

export const HiddenVolume: SFC<HiddenVolumeProps> = () => (
  <NativeHiddenVolumeView />
);
