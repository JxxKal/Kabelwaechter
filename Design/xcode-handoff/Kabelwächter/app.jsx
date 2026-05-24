// app.jsx — Kabelwächter design canvas host

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "viz": "rings",
  "accent": "#00d4ff"
}/*EDITMODE-END*/;

const ACCENT_OPTIONS = [
  '#00d4ff', // cyan (default)
  '#7c5cff', // violet
  '#00ff9d', // neon green
  '#ff4757', // red-rebel
  '#ffb84d', // amber
];

function KabelApp() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const accent = t.accent;
  const viz = t.viz;

  return (
    <>
      <DesignCanvas>
        <DCPostIt x={60} y={20} w={420}>
          <b>Kabelwächter · Hi-Fi</b><br/>
          Two directions for the Apple TV WireGuard companion. Click any artboard's expand icon to focus.
          Use the Tweaks panel (bottom-right) to swap the tunnel visualisation or recolour the system.
        </DCPostIt>

        <DCSection id="v1" title="Variant A · Centered Hub"
          subtitle="Tunnel-as-hero. Status overlaid on the visualisation, minimal chrome.">
          <DCArtboard id="v1-atv-pair" label="ATV · Pair" width={1280} height={720}>
            <V1ATVPairing accent={accent} vizVariant={viz} />
          </DCArtboard>
          <DCArtboard id="v1-atv-tunnels" label="ATV · Tunnels (interactive)" width={1280} height={720}>
            <V1ATVTunnels accent={accent} vizVariant={viz} />
          </DCArtboard>
          <DCArtboard id="v1-ios-tunnels" label="iOS · Tunnels (interactive)" width={390} height={844}>
            <V1IOSTunnels accent={accent} vizVariant={viz} />
          </DCArtboard>
        </DCSection>

        <DCSection id="v2" title="Variant B · Split HUD"
          subtitle="Control-room layout. Tunnel viewport + structured data panel.">
          <DCArtboard id="v2-atv-pair" label="ATV · Pair" width={1280} height={720}>
            <V2ATVPairing accent={accent} vizVariant={viz} />
          </DCArtboard>
          <DCArtboard id="v2-atv-tunnels" label="ATV · Tunnels (interactive)" width={1280} height={720}>
            <V2ATVTunnels accent={accent} vizVariant={viz} />
          </DCArtboard>
          <DCArtboard id="v2-ios-tunnels" label="iOS · Tunnels (interactive)" width={390} height={844}>
            <V2IOSTunnels accent={accent} vizVariant={viz} />
          </DCArtboard>
        </DCSection>
      </DesignCanvas>

      <TweaksPanel title="Tweaks">
        <TweakSection label="Tunnel visualisation" />
        <TweakRadio label="Style" value={viz}
          options={[
            { value: 'rings', label: 'Rings' },
            { value: 'grid',  label: 'Wire-Grid' },
            { value: 'particles', label: 'Particles' },
          ]}
          onChange={(v) => setTweak('viz', v)} />
        <TweakSection label="Accent" />
        <TweakColor label="Color" value={accent}
          options={ACCENT_OPTIONS}
          onChange={(v) => setTweak('accent', v)} />
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<KabelApp />);
