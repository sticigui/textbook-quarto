// SurveyJS custom functions for SticiGui exercises

function generateRandomData(params) {
  const count = params[0] !== undefined ? params[0] : 25;
  const min = params[1] !== undefined ? params[1] : -50;
  const max = params[2] !== undefined ? params[2] : 50;
  const data = [];
  for (let i = 0; i < count; i++) {
    data.push(Math.floor(Math.random() * (max - min + 1)) + min);
  }
  return data;
}

function sortData(params) {
  const data = params[0];
  if (!Array.isArray(data)) return [];
  return data.slice().sort((a, b) => a - b);
}

function generateRandomPercentiles(params) {
  const count = params[0] !== undefined ? params[0] : 5;
  const min = params[1] !== undefined ? params[1] : 1;
  const max = params[2] !== undefined ? params[2] : 99;
  const percentiles = [];
  const used = {};
  while (percentiles.length < count) {
    const p = Math.floor(Math.random() * (max - min + 1)) + min;
    if (!used[p]) {
      percentiles.push(p);
      used[p] = true;
    }
  }
  return percentiles.sort((a, b) => a - b);
}

function calculatePercentiles(params) {
  const sortedData = params[0];
  const percentiles = params[1];
  if (!Array.isArray(sortedData) || !Array.isArray(percentiles)) return {};
  const results = {};
  for (let i = 0; i < percentiles.length; i++) {
    let index = Math.ceil(percentiles[i] * sortedData.length / 100) - 1;
    index = Math.max(index, 0);
    index = Math.min(index, sortedData.length - 1);
    results['p' + (i + 1)] = sortedData[index];
  }
  return results;
}

function getOrdinal(params) {
  const num = params[0];
  if (typeof num !== 'number') return num + 'th';
  let suffix = 'th';
  if (num % 10 === 1 && num % 100 !== 11) suffix = 'st';
  else if (num % 10 === 2 && num % 100 !== 12) suffix = 'nd';
  else if (num % 10 === 3 && num % 100 !== 13) suffix = 'rd';
  return num + suffix;
}

function getGravityPercentile(params) {
  const percentile = params[0];
  const gravityData = [-152,-132,-132,-128,-122,-121,-120,-113,-112,-108,-107,-107,-106,-106,-106,-105,-101,-101,-99,-87,-86,-83,-83,-80,-80,-79,-74,-74,-74,-68,-66,-59,-55,-54,-54,-52,-50,-49,-48,-48,-47,-44,-43,-38,-37,-35,-34,-34,-29,-27,-27,-26,-24,-24,-19,-19,-19,-19,-18,-16,-16,-15,-14,-14,-12,-12,-12,-4,-1,0,0,1,2,7,14,14,14,18,18,19,24,29,29,41,45,51,72,150,155];
  let index = Math.ceil(percentile * gravityData.length / 100) - 1;
  index = Math.max(0, Math.min(index, gravityData.length - 1));
  return gravityData[index];
}

function randomGravityPercentile(params) {
  const min = params[0] !== undefined ? params[0] : 51;
  const max = params[1] !== undefined ? params[1] : 74;
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomInt(params) {
  const min = params[0] !== undefined ? params[0] : 1;
  const max = params[1] !== undefined ? params[1] : 100;
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomIntDistinct(params) {
  const min = params[0] !== undefined ? params[0] : 1;
  const max = params[1] !== undefined ? params[1] : 100;
  const exclude = Array.isArray(params[2]) ? params[2] : [];
  let candidate;
  let tries = 0;
  do {
    candidate = Math.floor(Math.random() * (max - min + 1)) + min;
    tries++;
    if (tries > 1000) break; // avoid infinite loop
  } while (exclude.includes(candidate));
  return candidate;
}

function getPercentileValue(params) {
  const sortedData = params[0];
  const percentile = params[1];
  if (!Array.isArray(sortedData) || typeof percentile !== 'number') return null;
  let index = Math.ceil(percentile * sortedData.length / 100) - 1;
  index = Math.max(index, 0);
  index = Math.min(index, sortedData.length - 1);
  return sortedData[index];
}

// List of custom functions to register
const sticiguiCustomFunctions = [
  { name: 'generateRandomData', fn: generateRandomData },
  { name: 'sortData', fn: sortData },
  { name: 'generateRandomPercentiles', fn: generateRandomPercentiles },
  { name: 'calculatePercentiles', fn: calculatePercentiles },
  { name: 'getOrdinal', fn: getOrdinal },
  { name: 'getGravityPercentile', fn: getGravityPercentile },
  { name: 'randomGravityPercentile', fn: randomGravityPercentile },
  { name: 'randomInt', fn: randomInt },
  { name: 'randomIntDistinct', fn: randomIntDistinct },
  { name: 'getPercentileValue', fn: getPercentileValue }
];

// Register all functions with SurveyJS FunctionFactory
function registerSticiGuiFunctions(Survey) {
  if (typeof Survey !== 'undefined' && Survey.FunctionFactory) {
    sticiguiCustomFunctions.forEach(({ name, fn }) => {
      Survey.FunctionFactory.Instance.register(name, fn);
    });
  }
}

// Optionally auto-register if Survey is present (for legacy use)
if (typeof Survey !== 'undefined' && Survey.FunctionFactory) {
  registerSticiGuiFunctions(Survey);
}