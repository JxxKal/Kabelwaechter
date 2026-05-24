// cyber-shared.jsx — Shared visual primitives for Kabelwächter
// Tunnel visualizations, ATV frame, status pills, icon glyphs.

// ─────────────────────────────────────────────────────────────
// Cyber theme — single source of truth (overridable via props)
// ─────────────────────────────────────────────────────────────
const Cyber = {
  bg0: '#05080d',           // deepest
  bg1: '#0a0f1a',           // surface
  bg2: '#0f1825',           // raised
  grid: 'rgba(0, 212, 255, 0.08)',
  line: 'rgba(0, 212, 255, 0.35)',
  lineDim: 'rgba(0, 212, 255, 0.15)',
  cyan: '#00d4ff',
  cyanSoft: '#5be0ff',
  accent: '#00ff9d',        // connected
  warn: '#ffb84d',          // connecting
  err: '#ff4757',           // error
  text: '#e6f3ff',
  textDim: 'rgba(230, 243, 255, 0.55)',
  textFaint: 'rgba(230, 243, 255, 0.32)',
  mono: '"JetBrains Mono", "SF Mono", ui-monospace, Menlo, monospace',
  sans: 'Inter, "SF Pro Text", -apple-system, system-ui, sans-serif',
};

// Inject once: font import, scanline backdrop, blink keyframe
if (typeof document !== 'undefined' && !document.getElementById('cyber-globals')) {
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = 'https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600;700&display=swap';
  document.head.appendChild(link);
  const s = document.createElement('style');
  s.id = 'cyber-globals';
  s.textContent = `
    @keyframes cyberBlink { 0%, 60% { opacity: 1 } 70%, 100% { opacity: 0.25 } }
    @keyframes cyberPulse { 0%, 100% { opacity: 0.85 } 50% { opacity: 0.35 } }
    @keyframes cyberScan { 0% { transform: translateY(-100%) } 100% { transform: translateY(100%) } }
    @keyframes cyberFlow { 0% { stroke-dashoffset: 0 } 100% { stroke-dashoffset: -40 } }
    @keyframes cyberDash { 0% { stroke-dashoffset: 80 } 100% { stroke-dashoffset: 0 } }
    @keyframes cyberRingPulse { 0% { transform: scale(0.85); opacity: 0.9 } 100% { transform: scale(1.6); opacity: 0 } }
    @keyframes cyberStatusBlip { 0%, 100% { opacity: 1 } 50% { opacity: 0.35 } }
    @keyframes cyberFlicker { 0%, 100% { opacity: 1 } 50% { opacity: 0.6 } 50.5% { opacity: 1 } 51% { opacity: 0.7 } }
    @keyframes cyberTunnelDepth { 0% { transform: translateZ(0) } 100% { transform: translateZ(180px) } }
    .cyber-mono { font-family: ${Cyber.mono}; }
    .cyber-sans { font-family: ${Cyber.sans}; }
    .cyber-grain::before {
      content: ''; position: absolute; inset: 0; pointer-events: none;
      background-image: radial-gradient(rgba(255,255,255,0.018) 1px, transparent 1px);
      background-size: 3px 3px; mix-blend-mode: overlay; opacity: 0.5;
    }
  `;
  document.head.appendChild(s);
}

// ─────────────────────────────────────────────────────────────
// CyberBackdrop — base canvas with subtle grid + glow
// ─────────────────────────────────────────────────────────────
function CyberBackdrop({ accent = Cyber.cyan, children, style = {}, showScan = true }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, overflow: 'hidden',
      background: `radial-gradient(ellipse at 50% 40%, ${Cyber.bg2} 0%, ${Cyber.bg1} 45%, ${Cyber.bg0} 100%)`,
      ...style,
    }}>
      {/* grid */}
      <div style={{
        position: 'absolute', inset: 0,
        backgroundImage: `
          linear-gradient(to right, ${Cyber.grid} 1px, transparent 1px),
          linear-gradient(to bottom, ${Cyber.grid} 1px, transparent 1px)
        `,
        backgroundSize: '40px 40px',
        maskImage: 'radial-gradient(ellipse at center, black 30%, transparent 80%)',
        WebkitMaskImage: 'radial-gradient(ellipse at center, black 30%, transparent 80%)',
      }} />
      {/* edge vignette */}
      <div style={{
        position: 'absolute', inset: 0,
        background: `radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.55) 100%)`,
        pointerEvents: 'none',
      }} />
      {/* horizontal scan line */}
      {showScan && (
        <div style={{
          position: 'absolute', left: 0, right: 0, height: 60,
          background: `linear-gradient(to bottom, transparent, ${accent}11, transparent)`,
          animation: 'cyberScan 8s linear infinite',
          pointerEvents: 'none',
        }} />
      )}
      {children}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// TunnelViz — perspective wireframe tunnel, configurable
//   variant: 'rings' | 'grid' | 'particles'
//   state: 'idle' | 'connecting' | 'connected' | 'error'
// ─────────────────────────────────────────────────────────────
function TunnelViz({
  variant = 'rings', state = 'connected', accent = Cyber.cyan, accentConnected = Cyber.accent,
  width = 800, height = 500, intensity = 1,
}) {
  const isErr = state === 'error';
  const isConnecting = state === 'connecting';
  const ringColor = isErr ? Cyber.err : (state === 'connected' ? accentConnected : accent);
  const lineColor = isErr ? 'rgba(255,71,87,0.4)' : `${accent}66`;
  const speed = isConnecting ? 1.4 : (state === 'connected' ? 2.6 : 0.6);

  const cx = width / 2, cy = height / 2;

  // Generate ring stack — concentric, scaled by depth
  const rings = [];
  const RING_COUNT = 14;
  for (let i = 0; i < RING_COUNT; i++) {
    const t = i / (RING_COUNT - 1);
    const radius = 30 + Math.pow(t, 0.9) * Math.min(width, height) * 0.55;
    const opacity = (1 - t * 0.7) * intensity;
    rings.push({ i, radius, opacity, delay: i * (1 / speed) * -0.4 });
  }

  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
      <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`}
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
        <defs>
          <radialGradient id="tunnelCore" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor={ringColor} stopOpacity="0.55" />
            <stop offset="40%" stopColor={ringColor} stopOpacity="0.12" />
            <stop offset="100%" stopColor={ringColor} stopOpacity="0" />
          </radialGradient>
          <filter id="tunnelGlow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="2.5" result="blur" />
            <feMerge><feMergeNode in="blur" /><feMergeNode in="SourceGraphic" /></feMerge>
          </filter>
        </defs>

        {/* core glow */}
        <circle cx={cx} cy={cy} r={Math.min(width, height) * 0.45} fill="url(#tunnelCore)" />

        {/* perspective rays */}
        {variant !== 'particles' && Array.from({ length: 16 }).map((_, i) => {
          const angle = (i / 16) * Math.PI * 2;
          const x2 = cx + Math.cos(angle) * Math.max(width, height);
          const y2 = cy + Math.sin(angle) * Math.max(width, height);
          return (
            <line key={i} x1={cx} y1={cy} x2={x2} y2={y2}
              stroke={lineColor} strokeWidth="0.5" opacity={0.5 * intensity} />
          );
        })}

        {/* ring stack */}
        {variant === 'rings' && rings.map(({ i, radius, opacity, delay }) => (
          <g key={i} style={{
            transformOrigin: `${cx}px ${cy}px`,
            animation: `tunnelRing${i} ${4 / speed}s linear infinite`,
            animationDelay: `${delay}s`,
          }}>
            <circle cx={cx} cy={cy} r={radius}
              fill="none" stroke={ringColor} strokeWidth={i < 3 ? 1.4 : 0.8}
              opacity={opacity * (isErr ? 0.7 : 1)}
              filter={i < 4 ? 'url(#tunnelGlow)' : undefined}
              strokeDasharray={isConnecting && i < 6 ? '6 4' : undefined} />
          </g>
        ))}

        {/* perspective grid quads */}
        {variant === 'grid' && rings.map(({ i, radius, opacity }) => {
          const sides = 6;
          const pts = [];
          for (let k = 0; k <= sides; k++) {
            const a = (k / sides) * Math.PI * 2;
            pts.push(`${cx + Math.cos(a) * radius},${cy + Math.sin(a) * radius}`);
          }
          return (
            <polygon key={i} points={pts.join(' ')}
              fill="none" stroke={ringColor} strokeWidth={i < 3 ? 1.2 : 0.7}
              opacity={opacity * (isErr ? 0.7 : 1)}
              filter={i < 3 ? 'url(#tunnelGlow)' : undefined} />
          );
        })}

        {/* particles flowing into center */}
        {variant === 'particles' && Array.from({ length: 60 }).map((_, i) => {
          const angle = (i * 137.5) % 360;
          const r = ((i * 73) % 100) / 100 * Math.min(width, height) * 0.5 + 20;
          const px = cx + Math.cos(angle * Math.PI / 180) * r;
          const py = cy + Math.sin(angle * Math.PI / 180) * r;
          return (
            <circle key={i} cx={px} cy={py} r={1.5} fill={ringColor}
              opacity={0.4 + ((i * 17) % 60) / 100}>
              <animate attributeName="r" values="2.4;0.4;2.4"
                dur={`${(2 + ((i * 31) % 200) / 100) / speed}s`} repeatCount="indefinite"
                begin={`${-((i * 11) % 200) / 100}s`} />
            </circle>
          );
        })}

        {/* center reticle */}
        <g>
          <circle cx={cx} cy={cy} r={6} fill={ringColor} opacity={isErr ? 0.7 : 1}
            filter="url(#tunnelGlow)" />
          <circle cx={cx} cy={cy} r={2} fill={Cyber.text} />
        </g>
      </svg>

      {/* per-ring keyframes — scale outward */}
      <style dangerouslySetInnerHTML={{ __html: rings.map(({ i }) => `
        @keyframes tunnelRing${i} {
          0% { transform: scale(0.4); opacity: 0; }
          15% { opacity: 1; }
          100% { transform: scale(1.4); opacity: 0; }
        }
      `).join('\n') }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// ATVFrame — Apple TV-styled bezel: 16:9 black rounded screen
// ─────────────────────────────────────────────────────────────
function ATVFrame({ width = 1280, height = 720, children, label = 'apple TV' }) {
  return (
    <div style={{
      width, height, position: 'relative',
      background: '#000', borderRadius: 12, overflow: 'hidden',
      boxShadow: '0 30px 80px rgba(0,0,0,0.45), 0 0 0 1px rgba(255,255,255,0.04)',
    }}>
      {children}
      {/* tiny TV-corner status */}
      <div style={{
        position: 'absolute', top: 14, right: 18, display: 'flex', gap: 8, alignItems: 'center',
        fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textFaint, letterSpacing: '0.12em',
        textTransform: 'uppercase', pointerEvents: 'none', zIndex: 50,
      }}>
        <span style={{
          width: 6, height: 6, borderRadius: '50%', background: Cyber.accent,
          boxShadow: `0 0 8px ${Cyber.accent}`, animation: 'cyberStatusBlip 2s ease-in-out infinite',
        }} />
        {label}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// CyberPill — small status capsule
// ─────────────────────────────────────────────────────────────
function CyberPill({ children, tone = 'cyan', size = 'sm', style = {} }) {
  const toneMap = {
    cyan: { fg: Cyber.cyan, bg: 'rgba(0, 212, 255, 0.10)', bd: 'rgba(0, 212, 255, 0.45)' },
    green: { fg: Cyber.accent, bg: 'rgba(0, 255, 157, 0.10)', bd: 'rgba(0, 255, 157, 0.45)' },
    warn: { fg: Cyber.warn, bg: 'rgba(255, 184, 77, 0.10)', bd: 'rgba(255, 184, 77, 0.45)' },
    err: { fg: Cyber.err, bg: 'rgba(255, 71, 87, 0.10)', bd: 'rgba(255, 71, 87, 0.50)' },
    dim: { fg: Cyber.textDim, bg: 'rgba(230, 243, 255, 0.04)', bd: 'rgba(230, 243, 255, 0.12)' },
  };
  const t = toneMap[tone] || toneMap.cyan;
  const sz = size === 'lg'
    ? { padding: '6px 12px', fontSize: 12, gap: 8 }
    : { padding: '3px 9px', fontSize: 10, gap: 6 };
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: sz.gap,
      padding: sz.padding, fontSize: sz.fontSize,
      fontFamily: Cyber.mono, fontWeight: 500, letterSpacing: '0.1em',
      textTransform: 'uppercase', color: t.fg,
      background: t.bg, border: `1px solid ${t.bd}`, borderRadius: 2,
      ...style,
    }}>{children}</span>
  );
}

// ─────────────────────────────────────────────────────────────
// CornerBrackets — animated [   ] frame corners (HUD feel)
// ─────────────────────────────────────────────────────────────
function CornerBrackets({ color = Cyber.cyan, size = 14, thickness = 1.5, inset = 0, animate = false }) {
  const armStyle = (pos) => ({
    position: 'absolute', width: size, height: size,
    borderColor: color, borderStyle: 'solid', borderWidth: 0,
    animation: animate ? 'cyberPulse 2.4s ease-in-out infinite' : undefined,
    ...pos,
  });
  return (
    <>
      <span style={{ ...armStyle({ top: inset, left: inset, borderTopWidth: thickness, borderLeftWidth: thickness }) }} />
      <span style={{ ...armStyle({ top: inset, right: inset, borderTopWidth: thickness, borderRightWidth: thickness }) }} />
      <span style={{ ...armStyle({ bottom: inset, left: inset, borderBottomWidth: thickness, borderLeftWidth: thickness }) }} />
      <span style={{ ...armStyle({ bottom: inset, right: inset, borderBottomWidth: thickness, borderRightWidth: thickness }) }} />
    </>
  );
}

// ─────────────────────────────────────────────────────────────
// QRPlaceholder — stylized cyber QR code (purely visual)
// ─────────────────────────────────────────────────────────────
function QRPlaceholder({ size = 220, color = Cyber.text, bg = '#fff', seed = 7 }) {
  const cells = 21;
  const cell = size / cells;
  // Deterministic pseudo-random grid based on seed
  const dots = [];
  let s = seed;
  const rand = () => { s = (s * 9301 + 49297) % 233280; return s / 233280; };
  for (let y = 0; y < cells; y++) {
    for (let x = 0; x < cells; x++) {
      const isFinderArea =
        (x < 7 && y < 7) || (x >= cells - 7 && y < 7) || (x < 7 && y >= cells - 7);
      if (isFinderArea) continue;
      if (rand() > 0.55) dots.push({ x, y });
    }
  }
  const Finder = ({ x, y }) => (
    <g transform={`translate(${x * cell} ${y * cell})`}>
      <rect width={cell * 7} height={cell * 7} fill={color} />
      <rect x={cell} y={cell} width={cell * 5} height={cell * 5} fill={bg} />
      <rect x={cell * 2} y={cell * 2} width={cell * 3} height={cell * 3} fill={color} />
    </g>
  );
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}
      style={{ display: 'block', background: bg, borderRadius: 6 }}>
      {dots.map((d, i) => (
        <rect key={i} x={d.x * cell} y={d.y * cell} width={cell} height={cell} fill={color} />
      ))}
      <Finder x={0} y={0} />
      <Finder x={cells - 7} y={0} />
      <Finder x={0} y={cells - 7} />
    </svg>
  );
}

// ─────────────────────────────────────────────────────────────
// Glyph icons (SVG, mono-stroke)
// ─────────────────────────────────────────────────────────────
const Glyph = {
  shield: (p = {}) => (
    <svg viewBox="0 0 24 24" width={p.size || 16} height={p.size || 16} fill="none"
      stroke={p.color || 'currentColor'} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 2 4 5v6c0 5 3.5 9.5 8 11 4.5-1.5 8-6 8-11V5l-8-3Z" />
    </svg>
  ),
  power: (p = {}) => (
    <svg viewBox="0 0 24 24" width={p.size || 16} height={p.size || 16} fill="none"
      stroke={p.color || 'currentColor'} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3v9" /><path d="M5.5 7.5a8 8 0 1 0 13 0" />
    </svg>
  ),
  plus: (p = {}) => (
    <svg viewBox="0 0 24 24" width={p.size || 16} height={p.size || 16} fill="none"
      stroke={p.color || 'currentColor'} strokeWidth="1.5" strokeLinecap="round">
      <path d="M12 5v14M5 12h14" />
    </svg>
  ),
  qr: (p = {}) => (
    <svg viewBox="0 0 24 24" width={p.size || 16} height={p.size || 16} fill="none"
      stroke={p.color || 'currentColor'} strokeWidth="1.5">
      <rect x="3" y="3" width="7" height="7" /><rect x="14" y="3" width="7" height="7" />
      <rect x="3" y="14" width="7" height="7" />
      <path d="M14 14h3v3M20 14v3M14 20h3M20 20v.01" />
    </svg>
  ),
  arrowUp: (p = {}) => (
    <svg viewBox="0 0 24 24" width={p.size || 14} height={p.size || 14} fill="none"
      stroke={p.color || 'currentColor'} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 19V5M5 12l7-7 7 7" />
    </svg>
  ),
  arrowDown: (p = {}) => (
    <svg viewBox="0 0 24 24" width={p.size || 14} height={p.size || 14} fill="none"
      stroke={p.color || 'currentColor'} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 5v14M19 12l-7 7-7-7" />
    </svg>
  ),
  chevron: (p = {}) => (
    <svg viewBox="0 0 24 24" width={p.size || 16} height={p.size || 16} fill="none"
      stroke={p.color || 'currentColor'} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="m9 6 6 6-6 6" />
    </svg>
  ),
  globe: (p = {}) => (
    <svg viewBox="0 0 24 24" width={p.size || 16} height={p.size || 16} fill="none"
      stroke={p.color || 'currentColor'} strokeWidth="1.5">
      <circle cx="12" cy="12" r="9" />
      <path d="M3 12h18M12 3c2.8 3 4.2 6 4.2 9s-1.4 6-4.2 9c-2.8-3-4.2-6-4.2-9s1.4-6 4.2-9Z" />
    </svg>
  ),
  warn: (p = {}) => (
    <svg viewBox="0 0 24 24" width={p.size || 16} height={p.size || 16} fill="none"
      stroke={p.color || 'currentColor'} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3 2 21h20L12 3Z" /><path d="M12 10v5M12 18v.01" />
    </svg>
  ),
  gear: (p = {}) => (
    <svg viewBox="0 0 24 24" width={p.size || 16} height={p.size || 16} fill="none"
      stroke={p.color || 'currentColor'} strokeWidth="1.4">
      <circle cx="12" cy="12" r="3" />
      <path d="M19 12a7 7 0 0 0-.1-1.2l2-1.5-2-3.4-2.3.9a7 7 0 0 0-2.1-1.2L14 3h-4l-.5 2.6a7 7 0 0 0-2.1 1.2l-2.3-.9-2 3.4 2 1.5A7 7 0 0 0 5 12c0 .4 0 .8.1 1.2l-2 1.5 2 3.4 2.3-.9a7 7 0 0 0 2.1 1.2L10 21h4l.5-2.6a7 7 0 0 0 2.1-1.2l2.3.9 2-3.4-2-1.5c.1-.4.1-.8.1-1.2Z" />
    </svg>
  ),
};

Object.assign(window, {
  Cyber, CyberBackdrop, TunnelViz, ATVFrame, CyberPill, CornerBrackets,
  QRPlaceholder, Glyph,
});
