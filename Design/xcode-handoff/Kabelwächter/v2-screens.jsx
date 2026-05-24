// v2-screens.jsx — Variant B: "Split HUD"
// Tunnel sits in a viewport on one side; a structured panel of data on the other.
// Feels like a control room / NOC.

// ─────────────────────────────────────────────────────────────
// V2 · Apple TV · Pairing
// ─────────────────────────────────────────────────────────────
function V2ATVPairing({ accent, vizVariant }) {
  return (
    <ATVFrame label="kabelwächter · pair">
      <div style={{ position: 'absolute', inset: 0, background: Cyber.bg0, display: 'flex' }}>
        {/* LEFT: Tunnel viewport */}
        <div style={{
          position: 'relative', flex: '0 0 55%',
          borderRight: `1px solid ${Cyber.lineDim}`,
        }}>
          <CyberBackdrop accent={accent}>
            <TunnelViz variant={vizVariant} state="idle" accent={accent}
              width={704} height={720} intensity={0.95} />
            {/* viewport HUD */}
            <div style={{
              position: 'absolute', top: 24, left: 24, right: 24,
              display: 'flex', justifyContent: 'space-between',
              fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textFaint,
              letterSpacing: '0.18em',
            }}>
              <span>◉ VIEWPORT · TUNNEL</span>
              <span>CH 04 · IDLE</span>
            </div>
            <div style={{
              position: 'absolute', bottom: 24, left: 24, right: 24,
              display: 'flex', justifyContent: 'space-between',
              fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textFaint,
              letterSpacing: '0.18em',
            }}>
              <span>WG · 51820/UDP</span>
              <span>AWAITING.HANDSHAKE</span>
            </div>
            <CornerBrackets color={accent} size={20} thickness={1.5} inset={16} animate />
          </CyberBackdrop>
        </div>

        {/* RIGHT: Pairing panel */}
        <div style={{
          flex: 1, position: 'relative', padding: '52px 64px',
          display: 'flex', flexDirection: 'column',
        }}>
          {/* header */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 44 }}>
            <KabelLogo accent={accent} />
            <div>
              <div style={{
                fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textFaint,
                letterSpacing: '0.22em',
              }}>KABELWÄCHTER.OS</div>
              <div style={{ fontFamily: Cyber.sans, fontSize: 15, color: Cyber.text, marginTop: 2 }}>
                Apple TV · Living Room
              </div>
            </div>
          </div>

          <div style={{
            fontFamily: Cyber.mono, fontSize: 11, color: accent,
            letterSpacing: '0.24em', marginBottom: 14,
          }}>// 01 · DEVICE PAIRING</div>

          <h1 style={{
            margin: 0, fontFamily: Cyber.sans, fontSize: 44, fontWeight: 700,
            lineHeight: 1.05, letterSpacing: '-0.025em', color: Cyber.text,
          }}>Pair iPhone<br />to transfer configs</h1>

          {/* QR + code */}
          <div style={{
            marginTop: 36, display: 'flex', gap: 28, alignItems: 'flex-start',
          }}>
            <div style={{ position: 'relative' }}>
              <CornerBrackets color={accent} size={14} thickness={1.5} inset={-7} />
              <QRPlaceholder size={180} color="#0a0f1a" bg="#e6f3ff" seed={29} />
            </div>
            <div style={{ flex: 1, paddingTop: 4 }}>
              <div style={{
                fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textFaint,
                letterSpacing: '0.2em', marginBottom: 12,
              }}>OR ENTER MANUALLY</div>
              <div style={{
                display: 'flex', gap: 6, marginBottom: 16,
              }}>
                {['4', 'F', '7', 'K', '9', 'Q'].map((c, i) => (
                  <div key={i} style={{
                    width: 32, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontFamily: Cyber.mono, fontSize: 22, fontWeight: 600, color: accent,
                    border: `1px solid ${accent}66`, background: `${accent}0d`,
                  }}>{c}</div>
                ))}
              </div>
              <div style={{
                fontFamily: Cyber.sans, fontSize: 12, color: Cyber.textDim, lineHeight: 1.5,
              }}>
                Code rotates every 5 minutes. Pairing creates a Curve25519 key
                exchange — your tunnel private keys never leave your iPhone.
              </div>
            </div>
          </div>

          {/* status row */}
          <div style={{ marginTop: 'auto', paddingTop: 28, display: 'flex', gap: 12, alignItems: 'center' }}>
            <span style={{
              width: 7, height: 7, borderRadius: '50%', background: accent,
              boxShadow: `0 0 8px ${accent}`,
              animation: 'cyberStatusBlip 1.4s ease-in-out infinite',
            }} />
            <span style={{
              fontFamily: Cyber.mono, fontSize: 11, color: Cyber.textDim,
              letterSpacing: '0.14em',
            }}>LISTENING ON 10.0.1.14 · BONJOUR _wgpair._tcp</span>
          </div>
        </div>
      </div>
    </ATVFrame>
  );
}

// ─────────────────────────────────────────────────────────────
// V2 · Apple TV · Tunnel Overview
// ─────────────────────────────────────────────────────────────
function V2ATVTunnels({ accent, vizVariant }) {
  const [activeId, setActiveId] = React.useState('home');
  const [state, setState] = React.useState('connected');

  const tunnels = [
    { id: 'home', name: 'Home · Berlin', endpoint: 'vpn.home.dn', region: 'DE', peer: '10.8.0.1' },
    { id: 'work', name: 'Work · Frankfurt', endpoint: 'wg.acme.io', region: 'DE', peer: '10.10.0.1' },
    { id: 'us', name: 'US-East · Mullvad', endpoint: 'us-nyc.mlvd', region: 'US', peer: '10.66.7.5' },
    { id: 'jp', name: 'Tokyo Relay', endpoint: 'jp-tyo.relay', region: 'JP', peer: '10.99.2.8' },
  ];
  const active = tunnels.find((t) => t.id === activeId) || tunnels[0];

  const toggle = () => {
    if (state === 'connected') { setState('connecting'); setTimeout(() => setState('error'), 1100); return; }
    setState('connecting'); setTimeout(() => setState('connected'), 1400);
  };

  const statusFg = state === 'connected' ? Cyber.accent : state === 'connecting' ? Cyber.warn : Cyber.err;
  const statusLabel = state === 'connected' ? 'ACTIVE' : state === 'connecting' ? 'HANDSHAKE' : 'FAILED';
  const statusTone = state === 'connected' ? 'green' : state === 'connecting' ? 'warn' : 'err';

  return (
    <ATVFrame label={`kabelwächter · ${active.region.toLowerCase()}`}>
      <div style={{ position: 'absolute', inset: 0, background: Cyber.bg0, display: 'flex' }}>
        {/* LEFT: tunnel sidebar */}
        <div style={{
          flex: '0 0 320px', borderRight: `1px solid ${Cyber.lineDim}`,
          padding: '36px 24px', display: 'flex', flexDirection: 'column',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 32 }}>
            <KabelLogo accent={accent} size={22} />
            <span style={{
              fontFamily: Cyber.sans, fontSize: 15, fontWeight: 600, color: Cyber.text,
            }}>Kabelwächter</span>
          </div>
          <div style={{
            fontFamily: Cyber.mono, fontSize: 9, color: Cyber.textFaint,
            letterSpacing: '0.22em', marginBottom: 14,
          }}>TUNNELS · 04</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flex: 1 }}>
            {tunnels.map((t) => {
              const isActive = t.id === activeId;
              return (
                <button key={t.id} onClick={() => setActiveId(t.id)} style={{
                  display: 'flex', alignItems: 'center', gap: 12,
                  padding: '12px 14px', textAlign: 'left',
                  background: isActive ? `${accent}14` : 'transparent',
                  borderLeft: `2px solid ${isActive ? accent : 'transparent'}`,
                  border: '0', borderLeftWidth: 2, borderLeftStyle: 'solid',
                  borderLeftColor: isActive ? accent : 'transparent',
                  color: 'inherit', font: 'inherit', cursor: 'pointer',
                }}>
                  <span style={{
                    width: 8, height: 8, borderRadius: '50%',
                    background: isActive ? statusFg : Cyber.textFaint,
                    boxShadow: isActive ? `0 0 8px ${statusFg}` : 'none', flex: '0 0 auto',
                  }} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{
                      fontSize: 13, fontWeight: 600,
                      color: isActive ? Cyber.text : Cyber.textDim,
                      whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                    }}>{t.name}</div>
                    <div style={{
                      fontFamily: Cyber.mono, fontSize: 9, color: Cyber.textFaint,
                      letterSpacing: '0.1em', marginTop: 2,
                    }}>{t.region} · {t.peer}</div>
                  </div>
                </button>
              );
            })}
          </div>
          <div style={{
            marginTop: 16, paddingTop: 16, borderTop: `1px solid ${Cyber.lineDim}`,
            fontFamily: Cyber.mono, fontSize: 9, color: Cyber.textFaint,
            letterSpacing: '0.18em', display: 'flex', justifyContent: 'space-between',
          }}>
            <span>SYNCED IPHONE</span>
            <span>2m AGO</span>
          </div>
        </div>

        {/* CENTER: tunnel viewport */}
        <div style={{ flex: 1, position: 'relative' }}>
          <CyberBackdrop accent={accent}>
            <TunnelViz variant={vizVariant} state={state} accent={accent}
              width={960} height={720} intensity={1} />
            {/* corner brackets and HUD */}
            <CornerBrackets color={statusFg} size={22} thickness={1.5} inset={20} animate={state === 'connecting'} />

            {/* top HUD strip */}
            <div style={{
              position: 'absolute', top: 28, left: 36, right: 36,
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textDim,
              letterSpacing: '0.18em',
            }}>
              <div style={{ display: 'flex', gap: 24 }}>
                <span>◉ VIEWPORT</span>
                <span>WG · {active.endpoint.toUpperCase()}:51820</span>
              </div>
              <CyberPill tone={statusTone} size="sm">
                <span style={{
                  width: 6, height: 6, borderRadius: '50%', background: 'currentColor',
                  animation: 'cyberStatusBlip 1.2s ease-in-out infinite',
                }} />
                {statusLabel}
              </CyberPill>
            </div>

            {/* center text */}
            <div style={{
              position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)',
              textAlign: 'center', pointerEvents: 'none', width: '70%',
            }}>
              <div style={{
                fontFamily: Cyber.mono, fontSize: 11, color: statusFg,
                letterSpacing: '0.3em', marginBottom: 16,
              }}>{state === 'error' ? '⚠ HANDSHAKE FAILED' : state === 'connecting' ? 'NEGOTIATING…' : 'TUNNEL OPEN'}</div>
              <div style={{
                fontFamily: Cyber.sans, fontSize: 52, fontWeight: 700,
                color: Cyber.text, letterSpacing: '-0.025em', lineHeight: 1,
                textShadow: state === 'connected' ? `0 0 30px ${Cyber.accent}40` : 'none',
              }}>{active.name}</div>
              <div style={{
                marginTop: 14, fontFamily: Cyber.mono, fontSize: 12,
                color: Cyber.textDim, letterSpacing: '0.14em',
              }}>PEER · {active.peer}</div>
            </div>

            {/* bottom: action */}
            <div style={{
              position: 'absolute', bottom: 36, left: 0, right: 0,
              display: 'flex', justifyContent: 'center',
            }}>
              <button onClick={toggle} style={{
                position: 'relative',
                padding: '16px 36px',
                background: state === 'connected' ? 'transparent' : statusFg,
                color: state === 'connected' ? statusFg : '#04130c',
                border: `1px solid ${statusFg}`, borderRadius: 0,
                fontFamily: Cyber.mono, fontSize: 12, fontWeight: 600,
                letterSpacing: '0.24em', textTransform: 'uppercase', cursor: 'pointer',
                minWidth: 240,
              }}>
                {state === 'connected' ? '× DISCONNECT' : state === 'connecting' ? '◌ CONNECTING…' : '▶ RECONNECT'}
              </button>
            </div>

            {/* bottom HUD */}
            <div style={{
              position: 'absolute', bottom: 28, left: 36, right: 36,
              display: 'flex', justifyContent: 'space-between',
              fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textFaint,
              letterSpacing: '0.18em', pointerEvents: 'none',
            }}>
              <span>CURVE25519 · CHACHA20-POLY1305</span>
              <span>MTU 1420 · KEEPALIVE 25s</span>
            </div>
          </CyberBackdrop>
        </div>
      </div>
    </ATVFrame>
  );
}

// ─────────────────────────────────────────────────────────────
// V2 · iOS · Tunnel List (control-room phone)
// ─────────────────────────────────────────────────────────────
function V2IOSTunnels({ accent, vizVariant }) {
  const [activeId, setActiveId] = React.useState('home');
  const [states, setStates] = React.useState({ home: 'connected', work: 'idle', us: 'idle', jp: 'idle' });

  const tunnels = [
    { id: 'home', name: 'Home · Berlin', endpoint: 'vpn.home.dn:51820', region: 'DE', peer: '10.8.0.1' },
    { id: 'work', name: 'Work · Frankfurt', endpoint: 'wg.acme.io:51820', region: 'DE', peer: '10.10.0.1' },
    { id: 'us', name: 'US-East · Mullvad', endpoint: 'us-nyc.mlvd:51820', region: 'US', peer: '10.66.7.5' },
    { id: 'jp', name: 'Tokyo Relay', endpoint: 'jp-tyo.relay:51820', region: 'JP', peer: '10.99.2.8' },
  ];

  const toggle = (id) => {
    const cur = states[id];
    const next = cur === 'connected' ? 'idle' : 'connecting';
    setStates((s) => {
      const out = {};
      Object.keys(s).forEach((k) => out[k] = k === id ? next : 'idle');
      return out;
    });
    setActiveId(id);
    if (cur !== 'connected') setTimeout(() => setStates((s) => ({ ...s, [id]: 'connected' })), 1200);
  };

  return (
    <IOSDevice width={390} height={844} dark title="ios">
      <div style={{
        position: 'absolute', inset: 0,
        background: Cyber.bg0, color: Cyber.text,
        fontFamily: Cyber.sans,
        overflow: 'hidden',
      }}>
        <div style={{ height: 60 }} />

        {/* HUD top */}
        <div style={{
          padding: '8px 20px 16px',
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          borderBottom: `1px solid ${Cyber.lineDim}`,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <KabelLogo accent={accent} size={22} />
            <span style={{ fontSize: 15, fontWeight: 600 }}>Kabelwächter</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{
              width: 7, height: 7, borderRadius: '50%', background: Cyber.accent,
              boxShadow: `0 0 6px ${Cyber.accent}`,
            }} />
            <span style={{
              fontFamily: Cyber.mono, fontSize: 9, color: accent,
              letterSpacing: '0.2em',
            }}>ATV LINKED</span>
          </div>
        </div>

        {/* hero tunnel viewport */}
        <div style={{
          position: 'relative', height: 240,
          borderBottom: `1px solid ${Cyber.lineDim}`,
        }}>
          <CyberBackdrop accent={accent} showScan={false}>
            <TunnelViz variant={vizVariant} state={states[activeId] || 'idle'}
              accent={accent} width={390} height={240} intensity={0.9} />
            <CornerBrackets color={accent} size={12} thickness={1} inset={10} />
            <div style={{
              position: 'absolute', top: 12, left: 16, right: 16,
              display: 'flex', justifyContent: 'space-between',
              fontFamily: Cyber.mono, fontSize: 9, color: Cyber.textFaint,
              letterSpacing: '0.18em',
            }}>
              <span>◉ VIEWPORT</span>
              <span>CH 04</span>
            </div>
            <div style={{
              position: 'absolute', bottom: 14, left: 0, right: 0,
              textAlign: 'center', pointerEvents: 'none',
            }}>
              {(() => {
                const a = tunnels.find((t) => t.id === activeId) || tunnels[0];
                const st = states[a.id];
                const fg = st === 'connected' ? Cyber.accent : st === 'connecting' ? Cyber.warn : Cyber.cyan;
                return (
                  <>
                    <div style={{
                      fontFamily: Cyber.mono, fontSize: 9, color: fg,
                      letterSpacing: '0.28em', marginBottom: 6,
                    }}>{st === 'connected' ? 'TUNNEL UP' : st === 'connecting' ? 'NEGOTIATING…' : 'STANDBY'}</div>
                    <div style={{
                      fontSize: 22, fontWeight: 700, letterSpacing: '-0.01em',
                    }}>{a.name}</div>
                  </>
                );
              })()}
            </div>
          </CyberBackdrop>
        </div>

        {/* tunnel rows */}
        <div style={{
          padding: '14px 20px 8px',
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>
          <div style={{
            fontFamily: Cyber.mono, fontSize: 9, color: Cyber.textFaint,
            letterSpacing: '0.22em',
          }}>TUNNELS · 04</div>
          <div style={{ display: 'flex', gap: 8 }}>
            <IconBtn accent={accent}><Glyph.qr size={14} color={accent} /></IconBtn>
            <IconBtn accent={accent}><Glyph.plus size={16} color={accent} /></IconBtn>
          </div>
        </div>
        <div style={{
          padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 6,
        }}>
          {tunnels.map((t) => {
            const st = states[t.id];
            const isActive = t.id === activeId;
            const fg = st === 'connected' ? Cyber.accent : st === 'connecting' ? Cyber.warn : Cyber.textFaint;
            return (
              <div key={t.id} onClick={() => setActiveId(t.id)} style={{
                display: 'flex', alignItems: 'center', gap: 12,
                padding: '12px 14px',
                background: isActive ? `${accent}10` : 'rgba(15, 24, 37, 0.5)',
                borderLeft: `2px solid ${isActive ? accent : 'transparent'}`,
                cursor: 'pointer',
              }}>
                <span style={{
                  width: 8, height: 8, borderRadius: '50%', background: fg,
                  boxShadow: st !== 'idle' ? `0 0 6px ${fg}` : 'none', flex: '0 0 auto',
                }} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{
                    fontSize: 13, fontWeight: 600, color: isActive ? Cyber.text : Cyber.textDim,
                  }}>{t.name}</div>
                  <div style={{
                    fontFamily: Cyber.mono, fontSize: 9, color: Cyber.textFaint,
                    letterSpacing: '0.08em', marginTop: 2,
                  }}>{t.region} · {t.peer}</div>
                </div>
                {/* toggle switch */}
                <div onClick={(e) => { e.stopPropagation(); toggle(t.id); }} style={{
                  width: 42, height: 22, position: 'relative', cursor: 'pointer',
                  background: st === 'connected' ? Cyber.accent : 'rgba(230, 243, 255, 0.08)',
                  border: `1px solid ${st === 'connected' ? Cyber.accent : Cyber.lineDim}`,
                  boxShadow: st === 'connected' ? `0 0 10px ${Cyber.accent}66` : 'none',
                  transition: 'all 0.2s',
                }}>
                  <div style={{
                    position: 'absolute', top: 2, left: st === 'connected' ? 22 : 2,
                    width: 16, height: 16,
                    background: st === 'connected' ? '#04130c' : Cyber.textDim,
                    transition: 'left 0.2s',
                  }} />
                </div>
              </div>
            );
          })}
        </div>

        {/* paired ATV strip */}
        <div style={{
          position: 'absolute', bottom: 36, left: 16, right: 16,
          padding: '12px 16px',
          background: 'rgba(0, 212, 255, 0.05)',
          border: `1px solid ${accent}33`,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <Glyph.arrowUp size={14} color={accent} />
            <div>
              <div style={{
                fontFamily: Cyber.mono, fontSize: 9, color: accent,
                letterSpacing: '0.2em',
              }}>PUSH TO ATV</div>
              <div style={{ fontSize: 12, fontWeight: 600, marginTop: 2 }}>Living Room</div>
            </div>
          </div>
          <div style={{
            fontFamily: Cyber.mono, fontSize: 10, color: Cyber.textDim,
            letterSpacing: '0.1em',
          }}>4 configs</div>
        </div>
      </div>
    </IOSDevice>
  );
}

Object.assign(window, { V2ATVPairing, V2ATVTunnels, V2IOSTunnels });
