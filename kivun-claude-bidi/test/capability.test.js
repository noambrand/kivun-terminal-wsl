'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { checkCapability } = require('../lib/capability-check');
const { detectTerminal } = require('../lib/detect-terminal');

describe('HEAVY §7 capability-check fixtures', () => {
  it('TERM=dumb → warned, continues', () => {
    let msg = null;
    const res = checkCapability({ TERM: 'dumb' }, (m) => { msg = m; });
    assert.equal(res.ok, true);
    assert.equal(res.warned, true);
    assert.match(msg, /TERM='dumb'/);
  });

  it('TERM=xterm-256color → silent', () => {
    let msg = null;
    const res = checkCapability({ TERM: 'xterm-256color' }, (m) => { msg = m; });
    assert.equal(res.ok, true);
    assert.equal(res.warned, false);
    assert.equal(msg, null);
  });

  it('TERM unset → warned, continues', () => {
    let msg = null;
    const res = checkCapability({}, (m) => { msg = m; });
    assert.equal(res.ok, true);
    assert.equal(res.warned, true);
    assert.match(msg, /TERM=''/);
  });
});

describe('detect-terminal fixtures', () => {
  it('KONSOLE_VERSION set → ok with konsole name', () => {
    const res = detectTerminal({ KONSOLE_VERSION: '230400' });
    assert.equal(res.ok, true);
    assert.equal(res.name, 'konsole');
  });

  it('KONSOLE_DBUS_SESSION set → ok', () => {
    const res = detectTerminal({ KONSOLE_DBUS_SESSION: '/Sessions/1' });
    assert.equal(res.ok, true);
    assert.equal(res.name, 'konsole');
  });

  it('KONSOLE_PROFILE_NAME surfaced when set', () => {
    const res = detectTerminal({
      KONSOLE_VERSION: '230400',
      KONSOLE_PROFILE_NAME: 'KivunTerminal',
    });
    assert.equal(res.ok, true);
    assert.equal(res.profile, 'KivunTerminal');
  });

  it('empty env → not ok', () => {
    const res = detectTerminal({});
    assert.equal(res.ok, false);
    assert.match(res.reason, /Konsole/);
  });

  it('xterm-only env (no KONSOLE_*) → not ok (v1 policy)', () => {
    const res = detectTerminal({ TERM: 'xterm-256color' });
    assert.equal(res.ok, false);
  });
});
