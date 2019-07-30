// @flow
import groupBy from 'lodash/groupBy';
import maxBy from 'lodash/maxBy';
import map from 'lodash/map';
import isEqual from 'lodash/isEqual';

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

export const areFormatsEqual = (a: CameraFormat, b: CameraFormat): boolean =>
  a.mediaType === b.mediaType &&
  a.mediaSubType === b.mediaSubType &&
  isEqual(a.dimensions, b.dimensions) &&
  isEqual(a.supportedFrameRates, b.supportedFrameRates);
