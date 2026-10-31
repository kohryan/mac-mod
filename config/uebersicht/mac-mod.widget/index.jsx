import { command as telemetryCommand, parseTelemetry } from './lib/telemetry';

export const command = telemetryCommand;
export const refreshFrequency = 10000;

export const className = `
  inset: 0;
  width: 100vw;
  height: 100vh;
  pointer-events: none;
  user-select: none;
  color: #e8edf1;
  font-family: 'Helvetica Neue', sans-serif;
  background: radial-gradient(ellipse at 57% 46%, #14232b 0%, #0c151b 38%, #080e13 78%);
  overflow: hidden;

  * { box-sizing: border-box; }
  .mono { font-family: 'SF Mono', Menlo, monospace; }
  .dim { color: #7c949f; }
  .cyan { color: #8ed4d9; }
  .tiny { font-size: 9px; letter-spacing: 1.7px; line-height: 1.6; }
  .row { display: flex; align-items: center; justify-content: space-between; }
  .dot { display: inline-block; width: 5px; height: 5px; margin-right: 8px; border-radius: 50%; background: #8ed4d9; }
  .frame { position: absolute; inset: 28px 32px 62px; border: 1px solid #8ed4d912; }
  .frame:before, .frame:after { content: ''; position: absolute; width: 30px; height: 12px; border-color: #8ed4d970; }
  .frame:before { top: -1px; left: -1px; border-top: 1px solid; border-left: 1px solid; }
  .frame:after { bottom: -1px; right: -1px; border-bottom: 1px solid; border-right: 1px solid; }
  header { position: absolute; top: 52px; left: 64px; right: 64px; }
  .brand { display: flex; align-items: center; gap: 13px; }
  .brand-mark { width: 28px; height: 28px; }
  .brand-name { font-size: 12px; letter-spacing: 4px; font-weight: 600; }
  .brand-sub { margin-top: 5px; font-size: 8px; letter-spacing: 2.4px; color: #7c949f; }
  .left { position: absolute; top: 23%; left: 64px; width: 264px; }
  .eyebrow { margin-bottom: 18px; }
  h1 { margin: 0; font-size: 69px; font-weight: 200; letter-spacing: -3px; line-height: 1; }
  .unit-sub { margin-top: 14px; font-size: 9px; letter-spacing: 2px; }
  .divider { height: 1px; margin: 28px 0; background: #8ed4d926; }
  .clock { font-size: 61px; line-height: 1; font-weight: 200; letter-spacing: -2px; font-variant-numeric: tabular-nums; }
  .date { margin-top: 12px; font-size: 10px; letter-spacing: 1.2px; }
  .pilot { margin-top: 34px; display: flex; gap: 14px; align-items: center; }
  .pilot-number { width: 35px; height: 35px; border: 1px solid #8ed4d945; display: grid; place-items: center; font-size: 11px; }
  .pilot-name { margin-top: 3px; font-size: 12px; letter-spacing: 3px; }
  .blueprint { position: absolute; width: min(44vw, 600px); height: min(44vw, 600px); left: 51%; top: 47%; transform: translate(-50%, -50%); }
  .blueprint svg { width: 100%; height: 100%; }
  .right { position: absolute; right: 64px; top: 24%; width: 208px; }
  .panel-title { padding-bottom: 18px; border-bottom: 1px solid #8ed4d926; }
  .metric { padding: 21px 0; border-bottom: 1px solid #8ed4d91c; }
  .metric-value { margin-top: 10px; font-size: 35px; font-weight: 200; font-variant-numeric: tabular-nums; }
  .metric-value small { font-size: 11px; margin-left: 5px; color: #7c949f; font-weight: 400; letter-spacing: 1px; }
  .meter { display: flex; gap: 4px; height: 7px; margin: 15px 0 10px; }
  .meter i { flex: 1; background: #8ed4d91c; }
  .meter i.active { background: #8ed4d9; }
  .system-label { display: flex; align-items: center; gap: 12px; margin-top: 17px; }
  .system-label span:last-child { border: 1px solid #8ed4d930; padding: 3px 6px; font-size: 8px; }
  .bottom { position: absolute; left: 64px; right: 64px; bottom: 89px; display: flex; align-items: flex-end; justify-content: space-between; }
  .bottom-line { width: 64px; height: 2px; background: #8ed4d9; margin-bottom: 13px; }
  .coordinate { text-align: right; }
  .warning { color: #ddb986; }
  @media (max-width: 1100px) {
    header { left: 48px; right: 48px; }
    .left { left: 48px; width: 228px; }
    .right { right: 48px; width: 170px; }
    .blueprint { width: 38vw; left: 52%; opacity: .65; }
    h1 { font-size: 58px; }
    .clock { font-size: 50px; }
    .bottom { left: 48px; right: 48px; }
  }
  @media (max-height: 700px) {
    .left { top: 20%; }
    .right { top: 20%; }
    .divider { margin: 20px 0; }
    .pilot { margin-top: 20px; }
    .metric { padding: 14px 0; }
    .bottom { bottom: 80px; }
  }
`;

export const render = ({ output = '', error }) => {
  const system = parseTelemetry(error ? '' : output);
  const now = new Date();
  const time = now.toLocaleTimeString('en-GB', { timeZone: 'Asia/Jakarta', hour: '2-digit', minute: '2-digit' });
  const date = now.toLocaleDateString('en-GB', { timeZone: 'Asia/Jakarta', weekday: 'short', day: '2-digit', month: 'short', year: 'numeric' });
  const synced = !error && system.load !== 'N/A';
  return (
    <main aria-label="Gundam cockpit desktop dashboard">
      <div className="frame" />
      <header className="row">
        <div className="brand">
          <svg className="brand-mark" viewBox="0 0 32 32" fill="none" aria-hidden="true"><path d="M2 5 16 23 30 5M8 6l8 11 8-11M16 23v6" stroke="#8ed4d9" strokeWidth="1.4" /></svg>
          <div><div className="brand-name">E.F.S.F.</div><div className="brand-sub mono">PERSONAL OPERATING SYSTEM</div></div>
        </div>
        <div className="mono tiny dim">U.C. 0079 <span className="cyan">/</span> COCKPIT INTERFACE 01</div>
      </header>

      <section className="left">
        <div className="eyebrow mono tiny cyan"><span className="dot" />MOBILE SUIT / RX SERIES</div>
        <h1>RX-78<span className="dim">-2</span></h1>
        <div className="unit-sub mono dim">GUNDAM · GENERAL PURPOSE TYPE</div>
        <div className="divider" />
        <div className="clock">{time}</div>
        <div className="date mono dim">{date.toUpperCase()} <span className="cyan">/ WIB</span></div>
        <div className="pilot">
          <div className="pilot-number mono cyan">01</div>
          <div><div className="tiny mono dim">PILOT CALLSIGN</div><div className="pilot-name">KOHRYAN</div></div>
        </div>
      </section>

      <div className="blueprint" aria-hidden="true">
        <svg viewBox="0 0 600 600" fill="none">
          <g stroke="#8ed4d9" strokeWidth="1" opacity=".12">
            <circle cx="300" cy="300" r="239" /><circle cx="300" cy="300" r="220" strokeDasharray="1 12" /><circle cx="300" cy="300" r="188" />
            <path d="M300 30v62m0 416v62M30 300h62m416 0h62M101 101l28 28m342 342 28 28M101 499l28-28m342-342 28-28M300 110v380M110 300h380" />
          </g>
          <g stroke="#8ed4d9" strokeWidth="1.3" opacity=".55" strokeLinejoin="round">
            <path d="m300 168-52 32-26 64 7 105 36 47h70l36-47 7-105-26-64-52-32Z" />
            <path d="m248 200 28 26h48l28-26M276 226l-10 47h68l-10-47M266 273l-26 17 9 66 29 18h44l29-18 9-66-26-17M249 356l16 40h70l16-40M278 374v22m44-22v22M229 305l-20 12 4 58 27 12m131-82 20 12-4 58-27 12M264 404v26h72v-26" />
            <path d="m290 243-116-92 92 122m44-30 116-92-92 122" strokeWidth="2" opacity=".9" />
            <path d="m300 278-9 31 9 15 9-15-9-31Zm-29 60h58m-54 9h50m-45 9h40" />
          </g>
          <path d="m249 294 39 11-9 10-26-5-4-16Zm102 0-39 11 9 10 26-5 4-16Z" fill="#b4edf0" opacity=".8" />
          <g stroke="#8ed4d9" opacity=".28"><path d="m355 209 55-55h71M366 357h62l31 31h44M265 430l-48 48h-85" /><circle cx="355" cy="209" r="3" /><circle cx="366" cy="357" r="3" /></g>
          <g fill="#7c949f" fontFamily="Menlo,monospace" fontSize="8" letterSpacing="1.5"><text x="418" y="145">V-FIN / 01</text><text x="441" y="407">HEAD UNIT</text><text x="132" y="496">RX-78-2</text></g>
          <path d="M250 544h100" stroke="#8ed4d9" opacity=".25" /><text x="300" y="564" textAnchor="middle" fill="#7c949f" fontFamily="Menlo,monospace" fontSize="8" letterSpacing="3">TACTICAL SCHEMATIC</text>
        </svg>
      </div>

      <section className="right" aria-label="Live system telemetry">
        <div className="panel-title row mono tiny"><span>SYSTEM TELEMETRY</span><span className={synced ? 'cyan' : 'warning'}>{synced ? 'LIVE' : 'N/A'}</span></div>
        <div className="metric">
          <div className="mono tiny dim">01 / ENERGY RESERVE</div>
          <div className="metric-value">{system.battery === null ? 'N/A' : system.battery}<small>{system.battery === null ? '' : '%'}</small></div>
          <div className="meter">{Array.from({ length: 20 }, (_, i) => <i key={i} className={system.battery !== null && i < Math.ceil(system.battery / 5) ? 'active' : ''} />)}</div>
          <div className="mono tiny dim">{system.power}</div>
        </div>
        <div className="metric">
          <div className="mono tiny dim">02 / SYSTEM LOAD</div>
          <div className="metric-value">{system.load}<small>1 MIN</small></div>
          <div className="mono tiny dim" style={{ marginTop: 10 }}>{system.cores === null ? 'N/A' : `${system.cores} LOGICAL CORES`}</div>
        </div>
        <div className="system-label mono tiny dim"><span>{system.memory === null ? 'N/A' : `${system.memory} GB RAM`}</span><span>LOCAL ONLY</span></div>
      </section>

      <footer className="bottom">
        <div><div className="bottom-line" /><div className="mono tiny cyan">{synced ? 'TELEMETRY LINK ESTABLISHED' : error ? 'TELEMETRY UNAVAILABLE' : 'AWAITING TELEMETRY'}</div><div className="mono tiny dim" style={{ marginTop: 6 }}>MAC-MOD / PERSONAL DESKTOP SYSTEM</div></div>
        <div className="coordinate mono tiny dim">EARTH FEDERATION SPACE FORCE<br /><span className="cyan">RX-78-2</span> / WHITE BASE · SCV-70</div>
      </footer>
    </main>
  );
};
