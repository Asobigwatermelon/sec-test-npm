/**
 * String utility functions
 * This is a legitimate package with no malicious code
 */

function toUpperCase(str) {
  return str.toUpperCase();
}

function toLowerCase(str) {
  return str.toLowerCase();
}

function reverse(str) {
  return str.split('').reverse().join('');
}

module.exports = {
  toUpperCase,
  toLowerCase,
  reverse
};
