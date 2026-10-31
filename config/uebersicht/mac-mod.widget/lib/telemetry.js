export const command = [
  'LC_ALL=C /usr/bin/pmset -g batt',
  'LC_ALL=C /usr/bin/uptime',
  '/usr/sbin/sysctl -n hw.logicalcpu',
  '/usr/sbin/sysctl -n hw.memsize',
].join("; /usr/bin/printf '\\n---\\n'; ");

export function parseTelemetry(output = '') {
  const [power = '', uptime = '', cores = '', memory = ''] = output.split('\n---\n');
  const percent = power.match(/\b(\d{1,3})%/);
  const battery = percent && Number(percent[1]) <= 100 ? Number(percent[1]) : null;
  const load = uptime.match(/load averages?:\s*([\d.]+)/i);
  return {
    battery,
    power: power.includes('AC Power') ? 'AC CONNECTED' : battery === null ? 'N/A' : 'ON BATTERY',
    load: load && Number.isFinite(Number(load[1])) ? Number(load[1]).toFixed(2) : 'N/A',
    cores: /^\d+$/.test(cores.trim()) ? Number(cores.trim()) : null,
    memory: /^\d+$/.test(memory.trim()) ? Math.round(Number(memory.trim()) / 1024 ** 3) : null,
  };
}
