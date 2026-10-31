import test from 'node:test';
import assert from 'node:assert/strict';
import { parseTelemetry } from '../config/uebersicht/mac-mod.widget/lib/telemetry.js';

test('parses macOS battery, load average and hardware capacity', () => {
  const output = "Now drawing from 'AC Power'\n -InternalBattery-0  84%; charging;\n\n---\n 12:30 up 2 days, 2 users, load averages: 1.25 1.10 1.05\n\n---\n8\n\n---\n17179869184\n";
  assert.deepEqual(parseTelemetry(output), { battery: 84, power: 'AC CONNECTED', load: '1.25', cores: 8, memory: 16 });
});

test('handles battery power and an empty battery without faking telemetry', () => {
  assert.equal(parseTelemetry("Now drawing from 'Battery Power'\n 0%; discharging").battery, 0);
  assert.equal(parseTelemetry("Now drawing from 'Battery Power'\n 63%; discharging").power, 'ON BATTERY');
  assert.deepEqual(parseTelemetry(), { battery: null, power: 'N/A', load: 'N/A', cores: null, memory: null });
  assert.equal(parseTelemetry('999%').battery, null);
  assert.equal(parseTelemetry('\n---\nload averages: ...').load, 'N/A');
});
