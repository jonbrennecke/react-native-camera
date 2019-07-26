// @flow
import groupBy from 'lodash/groupBy';
import maxBy from 'lodash/maxBy';
import map from 'lodash/map';

import type { CameraFormat } from '../state';

export const filterBestAvailableFormats = (
  allSupportedFormats: CameraFormat[]
): { depthFormat: CameraFormat, format: CameraFormat }[] => {
  const formatsWithDepth = allSupportedFormats.filter(
    fmt => !!fmt.supportedDepthFormats.length
  );
  const groupedFormats = groupBy(
    formatsWithDepth,
    fmt => `${fmt.dimensions.width},${fmt.dimensions.height}`
  );
  return map(groupedFormats, formats => ({
    format: formats.find(fmt =>
      maxBy(fmt.supportedDepthFormats, depthFmt => depthFmt.dimensions.width)
    ),
    depthFormat: maxBy(
      formats.map(fmt =>
        maxBy(fmt.supportedDepthFormats, depthFmt => depthFmt.dimensions.width)
      ),
      fmt => fmt.dimensions.width
    ),
  }));
};

export const uniqueKeyForFormat = (
  format: CameraFormat,
  depthFormat: CameraFormat
) =>
  `${format.dimensions.width}-${format.mediaSubType}-${
    depthFormat.mediaSubType
  }`;
