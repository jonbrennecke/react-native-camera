// @flow
export const shouldDisplayIntegerValues = (
  min: number,
  max: number,
  numberOfTicks: number
) => Math.abs(max - min) >= numberOfTicks;

export const makeDefaultValueFormatter = (isIntegerValued: boolean) => (
  value: number
) =>
  `${parseFloat(value)
    .toFixed(isIntegerValued ? 0 : 1)
    .toLocaleUpperCase()}`;
