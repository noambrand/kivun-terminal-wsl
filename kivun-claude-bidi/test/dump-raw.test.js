'use strict';

// Regression tests for KIVUN_BIDI_DUMP_RAW (added in v1.1.10).
//
// Background: v1.1.9 added strip-incoming with a count-and-log side
// channel (`bidi-strip.log`). That answers "how much did the wrapper
// strip" but not "what exactly was Claude emitting around the
// stripped chars". DUMP_RAW gives the full byte context: append every
// upstream chunk to a side file BEFORE strip touches it.
//
// Default is OFF — this is a debug-only feature, not production
// instrumentation. Tests pin: off-mode is silent, on-mode captures
// pre-strip bytes verbatim, session markers delineate sessions, and
// the 5 MiB rotation guard works.

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const TMP_DUMP = path.join(os.tmpdir(), `kivun-bidi-dump-test-${process.pid}.bin`);
const TMP_LOG = path.join(os.tmpdir(), `kivun-bidi-strip-test-${process.pid}.log`);

function loadInjector(dumpMode, dumpFile) {
  delete require.cache[require.resolve('../lib/injector')];
  const prevDumpMode = process.env.KIVUN_BIDI_DUMP_RAW;
  const prevDumpFile = process.env.KIVUN_BIDI_DUMP_RAW_FILE;
  const prevLogFile = process.env.KIVUN_BIDI_LOG_FILE;
  if (dumpMode === undefined) delete process.env.KIVUN_BIDI_DUMP_RAW;
  else process.env.KIVUN_BIDI_DUMP_RAW = dumpMode;
  if (dumpFile === undefined) delete process.env.KIVUN_BIDI_DUMP_RAW_FILE;
  else process.env.KIVUN_BIDI_DUMP_RAW_FILE = dumpFile;
  // Always pin the strip log somewhere harmless so the tests don't
  // touch the user's real ~/.local/state directory.
  process.env.KIVUN_BIDI_LOG_FILE = TMP_LOG;
  try {
    return require('../lib/injector');
  } finally {
    if (prevDumpMode === undefined) delete process.env.KIVUN_BIDI_DUMP_RAW;
    else process.env.KIVUN_BIDI_DUMP_RAW = prevDumpMode;
    if (prevDumpFile === undefined) delete process.env.KIVUN_BIDI_DUMP_RAW_FILE;
    else process.env.KIVUN_BIDI_DUMP_RAW_FILE = prevDumpFile;
    if (prevLogFile === undefined) delete process.env.KIVUN_BIDI_LOG_FILE;
    else process.env.KIVUN_BIDI_LOG_FILE = prevLogFile;
  }
}

function clearDump() { try { fs.unlinkSync(TMP_DUMP); } catch (_) { /* not present */ } }
function clearOld() { try { fs.unlinkSync(TMP_DUMP + '.old'); } catch (_) { /* not present */ } }
function readDumpBytes() { try { return fs.readFileSync(TMP_DUMP); } catch (_) { return Buffer.alloc(0); } }
function readDumpString() { return readDumpBytes().toString('utf8'); }

describe('KIVUN_BIDI_DUMP_RAW=off (default)', () => {
  before(() => { clearDump(); clearOld(); });
  after(() => { clearDump(); clearOld(); });

  it('writes nothing to the dump file when off', () => {
    clearDump();
    const mod = loadInjector('off', TMP_DUMP);
    const inj = new mod.Injector();
    inj.write(Buffer.from('hello ‫world‬\n', 'utf8'));
    inj.end();
    assert.equal(readDumpBytes().length, 0, 'off mode must not write');
  });

  it('defaults to off when env is unset', () => {
    clearDump();
    const mod = loadInjector(undefined, TMP_DUMP);
    const inj = new mod.Injector();
    inj.write(Buffer.from('hello ‫world‬\n', 'utf8'));
    inj.end();
    assert.equal(readDumpBytes().length, 0, 'unset must default to off');
  });
});

describe('KIVUN_BIDI_DUMP_RAW=on (verbose debug)', () => {
  before(() => { clearDump(); clearOld(); });
  after(() => { clearDump(); clearOld(); });

  it('captures the raw chunk verbatim BEFORE strip-incoming runs', () => {
    clearDump();
    const mod = loadInjector('on', TMP_DUMP);
    const inj = new mod.Injector();
    // Embed an RLE so we can confirm the dump shows the pre-strip
    // bytes (RLE present), even though the wrapper output below it
    // would have stripped them.
    const input = Buffer.from('hi ‫bye\n', 'utf8');
    inj.write(input);
    inj.end();
    const dump = readDumpBytes();
    // Dump must contain the raw input bytes (which include the RLE)
    assert.ok(dump.includes(input), 'dump must contain pre-strip raw bytes verbatim');
    // And the strip count must reflect that the strip pass DID still
    // run on the input — dump is observation, not bypass.
    assert.equal(inj.stripIncomingCount, 1);
  });

  it('writes session-start and session-end markers around each session', () => {
    clearDump();
    const mod = loadInjector('on', TMP_DUMP);
    const inj = new mod.Injector();
    inj.write(Buffer.from('payload\n', 'utf8'));
    inj.end();
    const dump = readDumpString();
    assert.match(dump, /=== session start \d{4}-\d{2}-\d{2}T/);
    assert.match(dump, /=== session end \d{4}-\d{2}-\d{2}T/);
    assert.ok(
      dump.indexOf('session start') < dump.indexOf('payload'),
      'start marker must come before the payload bytes'
    );
    assert.ok(
      dump.indexOf('payload') < dump.indexOf('session end'),
      'end marker must come after the payload bytes'
    );
  });

  it('appends multiple chunks in arrival order', () => {
    clearDump();
    const mod = loadInjector('on', TMP_DUMP);
    const inj = new mod.Injector();
    inj.write(Buffer.from('first ', 'utf8'));
    inj.write(Buffer.from('second ', 'utf8'));
    inj.write(Buffer.from('third\n', 'utf8'));
    inj.end();
    const dump = readDumpString();
    // All three pieces present in order
    const fIdx = dump.indexOf('first');
    const sIdx = dump.indexOf('second');
    const tIdx = dump.indexOf('third');
    assert.ok(fIdx >= 0 && sIdx > fIdx && tIdx > sIdx, `chunks must appear in order in dump (got: ${dump.replace(/\n/g, '\\n')})`);
  });

  it('rotates oversized dump file to .old at session start', () => {
    clearDump();
    clearOld();
    // Pre-populate the dump file with > 5 MiB of content. The next
    // session-start (constructor) should rotate it.
    fs.writeFileSync(TMP_DUMP, Buffer.alloc(5 * 1024 * 1024 + 1));
    assert.ok(fs.statSync(TMP_DUMP).size > 5 * 1024 * 1024, 'precondition');
    const mod = loadInjector('on', TMP_DUMP);
    new mod.Injector(); // constructor triggers rotate
    assert.ok(fs.existsSync(TMP_DUMP + '.old'), 'oversized dump must rotate to .old');
    // The new dump file should exist and be small (just the new
    // session-start marker, written immediately after rotate).
    const newSize = fs.statSync(TMP_DUMP).size;
    assert.ok(newSize < 1024, `post-rotate dump must be small (got ${newSize} bytes)`);
  });

  it('does not rotate when the dump file is below the threshold', () => {
    clearDump();
    clearOld();
    fs.writeFileSync(TMP_DUMP, Buffer.from('small file\n', 'utf8'));
    const mod = loadInjector('on', TMP_DUMP);
    new mod.Injector();
    assert.ok(!fs.existsSync(TMP_DUMP + '.old'), 'small dump must NOT rotate');
    // The new content should be appended (small file content + marker)
    const dump = readDumpString();
    assert.ok(dump.startsWith('small file'), 'pre-existing content must be preserved');
    assert.match(dump, /=== session start /);
  });
});
