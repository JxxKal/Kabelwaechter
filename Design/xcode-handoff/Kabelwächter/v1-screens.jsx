// v1-screens.jsx — Variant A: "Centered Hub"
// Tunnel-as-hero, status overlaid on the visualization

// Helper: section heading with brackets
function V1Heading({ children, accent }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <span style={{
        fontFamily: Cyber.mono, fontSize: 10, color: accent, letterSpacing: '0.22em',
      }}>[ {children} ]</span>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// V1 · Apple TV · Pairing (QR)
// ─────────────────────────────────────────────────────────────
function V1ATVPairing({ accent, vizVariant }) {
  return (
    <ATVFrame label="kabelwächter · pair">
      <CyberBackdrop accent={accent}>
        {/* faint background tunnel */}
        <div style={{ position: 'absolute', inset: 0, opacity: 0.4 }}>
          <TunnelViz variant={vizVariant} state="idle" accent={accent}
            width={1280} height={720} intensity={0.7} />
        </div>

        {/* top bar */}
        <div style={{
          position: 'absolute', top: 36, left: 56, right: 56,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center', zIndex: 2,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <KabelLogo accent={accent} />
            <span style={{
              fontFamily: Cyber.sans, fontSize: 20, fontWeight: 600, color: Cyber.text,
              letterSpacing: '-0.01em',
            }}>Kabelwächter</span>
          </div>
          <CyberPill tone="cyan" size="sm">awaiting pair</CyberPill>
        </div>

        {/* center: QR + instructions side-by-side */}
        <div style={{
          position: 'absolute', inset: 0, display: 'flex',
          alignItems: 'center', justifyContent: 'center', gap: 72, zIndex: 2,
        }}>
          {/* QR card */}
          <div style={{
            position: 'relative', padding: 32,
            background: 'rgba(10, 15, 26, 0.85)',
            border: `1px solid ${Cyber.line}`,
            backdropFilter: 'blur(12px)',
          }}>
            <CornerBrackets color={accent} size={18} thickness={2} inset={-9} animate />
            <QRPlaceholder size={260} color="#0a0f1a" bg="#e6f3ff" seed={11} />
            <div style={{
              marginTop: 18, textAlign: 'center',
              fontFamily: Cyber.mono, fontSize: 11, color: Cyber.textDim, letterSpacing: '0.16em',
            }}>SCAN.WITH.IPHONE</div>
          </div>

          {/* instructions */}
          <div style={{ maxWidth: 380 }}>
            <V1Heading accent={accent}>SECURE PAIRING</V1Heading>
            <h1 style={{
              margin: '14px 0 18px', fontFamily: Cyber.sans, fontWeight: 700,
              fontSize: 42, lineHeight: 1.05, color: Cyber.text, letterSpacing: '-0.02em',
            }}>Link your iPhone<br />to this Apple&nbsp;TV</h1>
            <div style={{
              fontFamily: Cyber.sans, fontSize: 16, lineHeight: 1.55, color: Cyber.textDim,
              marginBottom: 28,
            }}>
              Open Kabelwächter on iPhone and tap the QR icon. Tunnel configs
              transfer over a one-time encrypted channel.
            </div>

            {/* steps */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {[
                ['01', 'Install Kabelwächter on iPhone'],
                ['02', 'Tap "Send to Apple TV" → "Scan code"'],
                ['03', 'Configs sync · this screen closes'],
              ].map(([n, t]) => (
                <div key={n} style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                  <span style={{
                    fontFamily: Cyber.mono, fontSize: 11, color: accent,
                    border: `1px solid ${accent}66`, padding: '3px 7px', letterSpacing: '0.1em',
                  }}>{n}</span>
                  <span style={{
                    fontFamily: Cyber.sans, fontSize: 14, color: Cyber.text,
                  }}>{t}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* bottom strip — fallback code */}
        <div style={{
          position: 'absolute', bottom: 32, left: 56, right: 56,
          display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', zIndex: 2,
        }}>
          <div>
            <div style={{
              fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textFaint,
              letterSpacing: '0.18em', marginBottom: 8,
            }}>OR ENTER CODE</div>
            <div style={{
              fontFamily: Cyber.mono, fontSize: 36, fontWeight: 600, color: accent,
              letterSpacing: '0.2em', textShadow: `0 0 16px ${accent}55`,
            }}>4F · 7K · 9Q</div>
          </div>
          <div style={{
            fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textFaint, letterSpacing: '0.14em',
            textAlign: 'right',
          }}>
            <div>HOST · 10.0.1.14:51820</div>
            <div style={{ marginTop: 4 }}>SESSION EXPIRES IN 04:58</div>
          </div>
        </div>
      </CyberBackdrop>
    </ATVFrame>
  );
}

// ─────────────────────────────────────────────────────────────
// V1 · Apple TV · Tunnel Overview
// ─────────────────────────────────────────────────────────────
function V1ATVTunnels({ accent, vizVariant }) {
  const [activeId, setActiveId] = React.useState('home');
  const [state, setState] = React.useState('connected'); // connected | connecting | error

  const tunnels = [
    { id: 'home', name: 'Home · Berlin', endpoint: 'vpn.home.dn', region: 'DE' },
    { id: 'work', name: 'Work · Frankfurt', endpoint: 'wg.acme.io', region: 'DE' },
    { id: 'us', name: 'US-East · Mullvad', endpoint: 'us-nyc.mlvd', region: 'US' },
    { id: 'jp', name: 'Tokyo Relay', endpoint: 'jp-tyo.relay', region: 'JP' },
  ];

  const active = tunnels.find((t) => t.id === activeId) || tunnels[0];
  const statusTone = state === 'connected' ? 'green' : state === 'connecting' ? 'warn' : 'err';
  const statusLabel = state === 'connected' ? 'TUNNEL ACTIVE' : state === 'connecting' ? 'HANDSHAKE…' : 'HANDSHAKE FAILED';

  const toggle = () => {
    if (state === 'connected') { setState('connecting'); setTimeout(() => setState('error'), 1100); return; }
    if (state === 'connecting') return;
    setState('connecting');
    setTimeout(() => setState('connected'), 1400);
  };

  return (
    <ATVFrame label={`kabelwächter · ${active.region.toLowerCase()}`}>
      <CyberBackdrop accent={accent}>
        {/* big tunnel viz centered */}
        <div style={{ position: 'absolute', inset: 0 }}>
          <TunnelViz variant={vizVariant} state={state} accent={accent}
            width={1280} height={720} intensity={1} />
        </div>

        {/* top header */}
        <div style={{
          position: 'absolute', top: 36, left: 56, right: 56, zIndex: 3,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            <KabelLogo accent={accent} />
            <div>
              <div style={{
                fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textFaint,
                letterSpacing: '0.2em',
              }}>KABELWÄCHTER · v1.0.2</div>
              <div style={{
                fontFamily: Cyber.sans, fontSize: 14, color: Cyber.textDim, marginTop: 2,
              }}>4 tunnels paired from iPhone</div>
            </div>
          </div>
          <CyberPill tone={statusTone} size="lg">
            <span style={{
              width: 7, height: 7, borderRadius: '50%',
              background: 'currentColor', animation: 'cyberStatusBlip 1.4s ease-in-out infinite',
            }} />
            {statusLabel}
          </CyberPill>
        </div>

        {/* center HUD — active tunnel info */}
        <div style={{
          position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
          zIndex: 3, textAlign: 'center', pointerEvents: 'none',
        }}>
          <div style={{
            fontFamily: Cyber.mono, fontSize: 11, color: accent,
            letterSpacing: '0.3em', marginBottom: 14,
          }}>{state === 'error' ? 'PEER UNREACHABLE' : 'ACTIVE PEER'}</div>
          <div style={{
            fontFamily: Cyber.sans, fontWeight: 700, fontSize: 56, color: Cyber.text,
            letterSpacing: '-0.02em', lineHeight: 1,
            textShadow: state === 'connected' ? `0 0 30px ${Cyber.accent}33` : 'none',
          }}>{active.name}</div>
          <div style={{
            marginTop: 16, fontFamily: Cyber.mono, fontSize: 14,
            color: Cyber.textDim, letterSpacing: '0.12em',
          }}>{active.endpoint.toUpperCase()} · :51820</div>
        </div>

        {/* bottom row — tunnel cards (focus-style) */}
        <div style={{
          position: 'absolute', bottom: 40, left: 56, right: 56, zIndex: 3,
          display: 'flex', gap: 14,
        }}>
          {tunnels.map((t) => {
            const isActive = t.id === activeId;
            return (
              <button key={t.id} onClick={() => setActiveId(t.id)}
                style={{
                  flex: 1, position: 'relative', cursor: 'pointer',
                  background: isActive ? `${accent}14` : 'rgba(10, 15, 26, 0.7)',
                  border: `1px solid ${isActive ? accent : Cyber.lineDim}`,
                  backdropFilter: 'blur(8px)',
                  padding: '16px 18px', textAlign: 'left',
                  color: 'inherit', font: 'inherit',
                  transition: 'all 0.18s',
                }}>
                {isActive && <CornerBrackets color={accent} size={10} thickness={1.5} inset={-5} />}
                <div style={{
                  display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                  marginBottom: 10,
                }}>
                  <span style={{
                    fontFamily: Cyber.mono, fontSize: 10, color: isActive ? accent : Cyber.textFaint,
                    letterSpacing: '0.18em',
                  }}>{t.region}</span>
                  <span style={{
                    width: 6, height: 6, borderRadius: '50%',
                    background: isActive ? (state === 'connected' ? Cyber.accent : state === 'connecting' ? Cyber.warn : Cyber.err) : Cyber.textFaint,
                    boxShadow: isActive ? `0 0 8px currentColor` : 'none',
                  }} />
                </div>
                <div style={{
                  fontFamily: Cyber.sans, fontSize: 16, fontWeight: 600,
                  color: isActive ? Cyber.text : Cyber.textDim, marginBottom: 4,
                }}>{t.name}</div>
                <div style={{
                  fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textFaint,
                  letterSpacing: '0.1em',
                }}>{t.endpoint}</div>
              </button>
            );
          })}
        </div>

        {/* big toggle button — bottom right */}
        <button onClick={toggle} style={{
          position: 'absolute', bottom: 40, right: 56, zIndex: 4,
          display: 'none',
        }} />
        <div style={{
          position: 'absolute', top: 36, right: 56, zIndex: 5,
          // sits as a CTA in header area — keeping minimal: clicking pill toggles
        }} />

        {/* invisible click region — clicking the center connects/disconnects */}
        <button onClick={toggle} style={{
          position: 'absolute', top: '40%', left: '50%', transform: 'translateX(-50%)',
          width: 520, height: 200, background: 'transparent', border: 0, cursor: 'pointer',
          zIndex: 4,
        }} aria-label="Toggle tunnel" />
      </CyberBackdrop>
    </ATVFrame>
  );
}

// ─────────────────────────────────────────────────────────────
// V1 · iOS · Tunnel List
// ─────────────────────────────────────────────────────────────
function V1IOSTunnels({ accent, vizVariant }) {
  const [activeId, setActiveId] = React.useState('home');
  const [states, setStates] = React.useState({ home: 'connected', work: 'idle', us: 'idle', jp: 'idle' });

  const tunnels = [
    { id: 'home', name: 'Home · Berlin', endpoint: 'vpn.home.dn:51820', region: 'DE' },
    { id: 'work', name: 'Work · Frankfurt', endpoint: 'wg.acme.io:51820', region: 'DE' },
    { id: 'us', name: 'US-East · Mullvad', endpoint: 'us-nyc.mlvd:51820', region: 'US' },
    { id: 'jp', name: 'Tokyo Relay', endpoint: 'jp-tyo.relay:51820', region: 'JP' },
  ];

  const toggle = (id) => {
    setStates((s) => {
      const cur = s[id];
      const next = cur === 'connected' ? 'idle' : 'connecting';
      const out = {};
      // Single-tunnel model: turn off everything else when starting one
      Object.keys(s).forEach((k) => out[k] = k === id ? next : 'idle');
      return out;
    });
    if (states[id] !== 'connected') {
      setTimeout(() => {
        setStates((s) => ({ ...s, [id]: 'connected' }));
      }, 1100);
    }
    setActiveId(id);
  };

  return (
    <IOSDevice width={390} height={844} dark title="ios">
      <div style={{
        position: 'absolute', inset: 0,
        background: Cyber.bg0,
        color: Cyber.text,
        fontFamily: Cyber.sans,
        overflow: 'hidden',
      }}>
        {/* faint tunnel backdrop */}
        <div style={{ position: 'absolute', top: -100, left: 0, right: 0, height: 460, opacity: 0.45 }}>
          <TunnelViz variant={vizVariant} state={states[activeId] || 'idle'} accent={accent}
            width={390} height={460} intensity={0.8} />
        </div>
        <div style={{
          position: 'absolute', top: 0, left: 0, right: 0, height: 460,
          background: `linear-gradient(to bottom, transparent 60%, ${Cyber.bg0})`,
          pointerEvents: 'none',
        }} />

        {/* status bar spacer */}
        <div style={{ height: 60 }} />

        {/* header */}
        <div style={{ padding: '8px 24px 0', position: 'relative', zIndex: 2 }}>
          <div style={{
            fontFamily: Cyber.mono, fontSize: 10, color: accent,
            letterSpacing: '0.22em',
          }}>[ KABELWÄCHTER ]</div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 12 }}>
            <h1 style={{
              margin: 0, fontFamily: Cyber.sans, fontSize: 30, fontWeight: 700,
              letterSpacing: '-0.02em',
            }}>Tunnels</h1>
            <div style={{ display: 'flex', gap: 8 }}>
              <IconBtn accent={accent}><Glyph.qr size={16} color={accent} /></IconBtn>
              <IconBtn accent={accent}><Glyph.plus size={18} color={accent} /></IconBtn>
            </div>
          </div>
        </div>

        {/* active tunnel hero (the one that's connected, or first) */}
        <div style={{ padding: '24px 24px 0', position: 'relative', zIndex: 2 }}>
          {(() => {
            const a = tunnels.find((t) => t.id === activeId) || tunnels[0];
            const st = states[a.id];
            const tone = st === 'connected' ? 'green' : st === 'connecting' ? 'warn' : 'dim';
            const label = st === 'connected' ? 'TUNNEL UP' : st === 'connecting' ? 'HANDSHAKE…' : 'STANDBY';
            return (
              <div style={{
                position: 'relative', padding: '22px 20px',
                background: 'rgba(15, 24, 37, 0.7)',
                border: `1px solid ${st === 'connected' ? accent : Cyber.lineDim}`,
                backdropFilter: 'blur(10px)',
              }}>
                <CornerBrackets color={st === 'connected' ? Cyber.accent : accent}
                  size={10} thickness={1.5} inset={-5} animate={st === 'connecting'} />
                <CyberPill tone={tone} size="sm">{label}</CyberPill>
                <div style={{
                  marginTop: 12, fontSize: 24, fontWeight: 700, letterSpacing: '-0.01em',
                }}>{a.name}</div>
                <div style={{
                  marginTop: 4, fontFamily: Cyber.mono, fontSize: 11,
                  color: Cyber.textDim, letterSpacing: '0.08em',
                }}>{a.endpoint}</div>
                <button onClick={() => toggle(a.id)} style={{
                  marginTop: 16, width: '100%', padding: '14px',
                  background: st === 'connected' ? 'transparent' : Cyber.accent,
                  color: st === 'connected' ? Cyber.accent : '#04130c',
                  border: `1px solid ${Cyber.accent}`, borderRadius: 0,
                  fontFamily: Cyber.mono, fontSize: 12, fontWeight: 600,
                  letterSpacing: '0.18em', textTransform: 'uppercase', cursor: 'pointer',
                }}>
                  {st === 'connected' ? '× Disconnect' : st === 'connecting' ? 'Connecting…' : '▶ Connect'}
                </button>
              </div>
            );
          })()}
        </div>

        {/* tunnel list — secondary */}
        <div style={{ padding: '24px 24px 0', position: 'relative', zIndex: 2 }}>
          <div style={{
            fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textFaint,
            letterSpacing: '0.2em', marginBottom: 10,
          }}>ALL TUNNELS · 4</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {tunnels.map((t) => {
              const st = states[t.id];
              const isActive = t.id === activeId;
              return (
                <button key={t.id} onClick={() => setActiveId(t.id)} style={{
                  display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                  padding: '12px 14px', textAlign: 'left',
                  background: isActive ? `${accent}0d` : 'rgba(15, 24, 37, 0.5)',
                  border: `1px solid ${isActive ? `${accent}55` : Cyber.lineDim}`,
                  color: 'inherit', font: 'inherit', cursor: 'pointer',
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <span style={{
                      width: 8, height: 8, borderRadius: '50%',
                      background: st === 'connected' ? Cyber.accent : st === 'connecting' ? Cyber.warn : Cyber.textFaint,
                      boxShadow: st === 'connected' ? `0 0 8px ${Cyber.accent}` : 'none',
                    }} />
                    <div>
                      <div style={{ fontSize: 14, fontWeight: 600 }}>{t.name}</div>
                      <div style={{
                        fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textFaint,
                        letterSpacing: '0.08em', marginTop: 2,
                      }}>{t.region} · {t.endpoint}</div>
                    </div>
                  </div>
                  <Glyph.chevron size={14} color={Cyber.textFaint} />
                </button>
              );
            })}
          </div>
        </div>

        {/* send-to-ATV strip */}
        <div style={{
          position: 'absolute', bottom: 36, left: 24, right: 24, zIndex: 2,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          padding: '12px 16px',
          background: 'rgba(0, 212, 255, 0.06)',
          border: `1px solid ${accent}44`,
        }}>
          <div>
            <div style={{
              fontFamily: Cyber.mono, fontSize: 9, color: accent, letterSpacing: '0.2em',
            }}>PAIRED · 1 DEVICE</div>
            <div style={{ fontSize: 13, fontWeight: 600, marginTop: 2 }}>Apple TV · Living Room</div>
          </div>
          <Glyph.arrowUp size={16} color={accent} />
        </div>
      </div>
    </IOSDevice>
  );
}

// shared helpers
function IconBtn({ children, accent }) {
  return (
    <button style={{
      width: 36, height: 36,
      background: 'rgba(0, 212, 255, 0.08)',
      border: `1px solid ${Cyber.lineDim}`,
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      cursor: 'pointer', color: accent,
    }}>{children}</button>
  );
}

function KabelLogo({ accent, size = 28 }) {
  return (
    <div style={{
      width: size, height: size, position: 'relative',
      border: `1.5px solid ${accent}`, transform: 'rotate(45deg)',
    }}>
      <div style={{
        position: 'absolute', inset: 4, border: `1px solid ${accent}88`,
      }} />
      <div style={{
        position: 'absolute', top: '50%', left: '50%', width: 4, height: 4,
        background: accent, transform: 'translate(-50%, -50%)',
        boxShadow: `0 0 6px ${accent}`,
      }} />
    </div>
  );
}

Object.assign(window, { V1ATVPairing, V1ATVTunnels, V1IOSTunnels, IconBtn, KabelLogo });
