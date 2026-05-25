// v7-spring.jsx — Expanded Springboard: 3 different tap-to-open patterns.
// Built on the NAV_PAL + GAMES from v6-nav.jsx. Each variant is a full,
// interactive iPhone artboard you can poke at.

const SPRING_MONO = '"SF Mono", ui-monospace, Menlo, monospace';

// Per-game modes shown when a tile is "opened".
const MODES = {
  mine:   { kind:'difficulty', items:[['Easy','9 × 9 · 10'],['Medium','16 × 16 · 40'],['Hard','24 × 24 · 99']] },
  merge:  { kind:'mode',       items:[['Win','reach 2048'],['Infinite','no cap'],['Timed','60 sec']] },
  nono:   { kind:'difficulty', items:[['5 × 5','warmup'],['10 × 10','classic'],['15 × 15','expert']] },
  sudoku: { kind:'difficulty', items:[['Easy','—'],['Medium','—'],['Hard','—']] },
  soli:   { kind:'variant',    items:[['Klondike','classic'],['Spider','2 suit'],['Yukon','open']] },
  free:   { kind:'difficulty', items:[['Standard','—'],['Hard','no undo'],['Daily','seed']] },
};

const PROGRESS = {
  mine:   { resume: '02:14', cleared: 38 }, // in-progress
  merge:  null,
  nono:   { resume: '00:48', cleared: 12 },
  sudoku: null,
  soli:   null,
  free:   null,
};

// ─── Springboard tile (shared) ─────────────────────────────────
function SpringTile({ g, onTap, dim = false, highlight = false, badge = false, size = 78 }) {
  return (
    <button onClick={onTap} style={{
      border:'none', background:'transparent', cursor:'pointer', padding:0,
      display:'flex', flexDirection:'column', alignItems:'center', gap:8,
      opacity: dim ? 0.35 : 1,
      transform: highlight ? 'scale(1.06)' : 'scale(1)',
      filter: dim ? 'blur(1.5px)' : 'none',
      transition: 'transform .25s cubic-bezier(.2,.7,.3,1), opacity .2s, filter .2s',
    }}>
      <div style={{
        width: size, height: size, borderRadius: size * 0.26,
        background: g.color, position: 'relative',
        display:'flex', alignItems:'center', justifyContent:'center',
        boxShadow: highlight
          ? `0 18px 36px -10px ${g.color}aa, inset 0 1px 0 rgba(255,255,255,0.35)`
          : `0 8px 20px -8px ${g.color}99, inset 0 1px 0 rgba(255,255,255,0.3)`,
        transition: 'box-shadow .25s',
      }}>
        <NavGlyph kind={g.glyph} size={size * 0.54} color="#FFFFFF"/>
        {badge && (
          <div style={{
            position:'absolute', top:-4, right:-4,
            width:18, height:18, borderRadius:9,
            background:'#FFFFFF', color: g.color,
            fontFamily:SPRING_MONO, fontSize:9.5, fontWeight:700,
            display:'flex', alignItems:'center', justifyContent:'center',
            boxShadow:'0 2px 4px rgba(0,0,0,0.15)',
          }}>!</div>
        )}
      </div>
      <div style={{ fontWeight:600, fontSize:13, letterSpacing:-0.1, color: NAV_PAL.ink }}>{g.name}</div>
    </button>
  );
}

function SpringHeader() {
  return (
    <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'10px 22px 4px' }}>
      <div>
        <div style={{ fontFamily:SPRING_MONO, fontSize:10.5, color:NAV_PAL.mute, letterSpacing:1.6 }}>WED · MAY 23</div>
        <div style={{ fontWeight:800, fontSize:32, letterSpacing:-1.1, marginTop:2, color: NAV_PAL.ink }}>The Drawer</div>
      </div>
      <Avatar/>
    </div>
  );
}

function SpringSearch({ dim = false }) {
  return (
    <div style={{ padding:'14px 60px 0', opacity: dim ? 0.4 : 1, transition: 'opacity .2s' }}>
      <div style={{
        display:'flex', alignItems:'center', gap:8, justifyContent:'center',
        padding:'8px 16px', borderRadius:999,
        background:'rgba(0,0,0,0.05)',
      }}>
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={NAV_PAL.mute} strokeWidth="2.4">
          <circle cx="11" cy="11" r="7"/><path d="M21 21l-4.5-4.5"/>
        </svg>
        <span style={{ color:NAV_PAL.mute, fontSize:13 }}>Search</span>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// D1 · QUICK ACTIONS POPOVER
// iOS-Home-Screen-long-press feel. Tile pops, dark menu appears.
// ════════════════════════════════════════════════════════════════
function SpringQuickActions() {
  const { useState } = React;
  const [open, setOpen] = useState(null); // index or null

  return (
    <IOSDevice width={390} height={844} time="8:38">
      <div style={{
        position:'relative', minHeight:'100%', width:'100%',
        background: NAV_PAL.bg, fontFamily: NAV_FONT, color: NAV_PAL.ink, paddingTop: 54,
        overflow:'hidden',
      }}>
        {/* dim backdrop */}
        <div onClick={() => setOpen(null)} style={{
          position:'absolute', inset:0,
          background: open !== null ? 'rgba(20,12,6,0.32)' : 'transparent',
          backdropFilter: open !== null ? 'blur(2px)' : 'none',
          pointerEvents: open !== null ? 'auto' : 'none',
          transition: 'background .25s, backdrop-filter .25s',
          zIndex: 5,
        }}/>

        <div style={{ position:'relative', zIndex: 1 }}>
          <SpringHeader/>
          <SpringSearch dim={open !== null}/>
        </div>

        <div style={{
          position:'relative', zIndex: 2,
          display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:'26px 14px',
          padding:'28px 26px 0',
        }}>
          {GAMES.map((g, i) => (
            <div key={g.id} style={{ position:'relative', display:'flex', justifyContent:'center', zIndex: open === i ? 10 : 1 }}>
              <SpringTile
                g={g}
                onTap={() => setOpen(open === i ? null : i)}
                dim={open !== null && open !== i}
                highlight={open === i}
                badge={PROGRESS[g.id] == null && (g.last === 'new')}
              />

              {/* Popover menu */}
              {open === i && (
                <QuickMenu g={g} onClose={() => setOpen(null)}/>
              )}
            </div>
          ))}
        </div>

        {/* page dots */}
        <div style={{ display:'flex', justifyContent:'center', gap:6, marginTop:34, opacity: open !== null ? 0.3 : 1, transition:'opacity .2s' }}>
          <div style={{ width:7, height:7, borderRadius:4, background:NAV_PAL.ink }}/>
          <div style={{ width:7, height:7, borderRadius:4, background:'rgba(0,0,0,0.18)' }}/>
        </div>

        {/* footer hint */}
        <div style={{
          position:'absolute', left:0, right:0, bottom: 50,
          textAlign:'center', fontFamily:SPRING_MONO, fontSize:10, color: NAV_PAL.mute, letterSpacing:1.6,
          opacity: open === null ? 1 : 0, transition:'opacity .2s',
        }}>
          TAP A GAME FOR QUICK ACTIONS
        </div>
      </div>
    </IOSDevice>
  );
}

function QuickMenu({ g, onClose }) {
  const prog = PROGRESS[g.id];
  const modes = MODES[g.id];
  const items = [
    prog && { icon:'play',     label:'Continue',          hint:`${prog.resume} · ${prog.cleared} cleared`, primary:true },
    { icon:'new',  label:'New game',         hint: modes.items[1][0] },
    { icon:'daily',label:'Daily challenge',  hint:'today\u2019s seed' },
    { icon:'stats',label:'Stats & history',  hint: prog ? 'best 02:14' : 'never played' },
  ].filter(Boolean);

  return (
    <div style={{
      position:'absolute', top:'calc(100% + 10px)', left:'50%',
      transform:'translateX(-50%)',
      minWidth: 200, maxWidth: 220,
      background: 'rgba(28,22,18,0.92)',
      backdropFilter: 'blur(20px)',
      borderRadius: 14, padding: 4,
      boxShadow: '0 20px 40px rgba(0,0,0,0.35), 0 0 0 0.5px rgba(255,255,255,0.06)',
      animation: 'springMenuIn .18s cubic-bezier(.2,.7,.3,1) both',
    }}>
      {/* caret */}
      <div style={{
        position:'absolute', top:-6, left:'50%', transform:'translateX(-50%) rotate(45deg)',
        width:12, height:12, background:'rgba(28,22,18,0.92)',
        borderRadius:2,
      }}/>
      {items.map((it, idx) => (
        <button key={idx} onClick={(e) => { e.stopPropagation(); onClose(); }} style={{
          width:'100%', textAlign:'left', border:'none', cursor:'pointer',
          background: it.primary ? g.color : 'transparent',
          color: '#FBF6E8', borderRadius: 10, padding: '10px 12px',
          display:'flex', alignItems:'center', gap:10,
          marginBottom: idx === items.length - 1 ? 0 : 1,
        }}>
          <div style={{
            width:26, height:26, borderRadius:7,
            background: it.primary ? 'rgba(255,255,255,0.2)' : 'rgba(255,255,255,0.08)',
            display:'flex', alignItems:'center', justifyContent:'center', flexShrink: 0,
          }}>
            <QuickIcon kind={it.icon}/>
          </div>
          <div style={{ flex:1, minWidth: 0 }}>
            <div style={{ fontSize: 13.5, fontWeight: it.primary ? 700 : 500 }}>{it.label}</div>
            <div style={{ fontSize: 10.5, fontFamily: SPRING_MONO, letterSpacing: 0.4, opacity: 0.7, marginTop: 1 }}>
              {it.hint.toUpperCase()}
            </div>
          </div>
          {it.primary && <div style={{ color:'#FBF6E8', opacity:0.8 }}>›</div>}
        </button>
      ))}
    </div>
  );
}

function QuickIcon({ kind }) {
  const c = '#FBF6E8';
  switch (kind) {
    case 'play':  return <svg width="11" height="13" viewBox="0 0 14 16" fill={c}><path d="M2 1l11 7-11 7V1z"/></svg>;
    case 'new':   return <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2.4" strokeLinecap="round"><path d="M12 5v14M5 12h14"/></svg>;
    case 'daily': return <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="2.1"><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>;
    case 'stats': return <svg width="13" height="13" viewBox="0 0 24 24" fill={c}><rect x="3" y="13" width="4" height="8" rx="1"/><rect x="10" y="8" width="4" height="13" rx="1"/><rect x="17" y="3" width="4" height="18" rx="1"/></svg>;
  }
}

// ════════════════════════════════════════════════════════════════
// D2 · BOTTOM SHEET
// Apple-Music-style sheet rises from the bottom with full detail.
// Most room for content; best if you have lots to show per game.
// ════════════════════════════════════════════════════════════════
function SpringBottomSheet() {
  const { useState } = React;
  const [open, setOpen] = useState(null);
  const g = open !== null ? GAMES[open] : null;

  return (
    <IOSDevice width={390} height={844} time="8:38">
      <div style={{
        position:'relative', minHeight:'100%', width:'100%',
        background: NAV_PAL.bg, fontFamily: NAV_FONT, color: NAV_PAL.ink, paddingTop: 54,
        overflow:'hidden',
      }}>
        <SpringHeader/>
        <SpringSearch dim={open !== null}/>

        <div style={{
          display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:'26px 14px',
          padding:'28px 26px 0',
          opacity: open !== null ? 0.4 : 1, filter: open !== null ? 'blur(1.5px)' : 'none',
          transition: 'opacity .25s, filter .25s',
          pointerEvents: open !== null ? 'none' : 'auto',
        }}>
          {GAMES.map((g, i) => (
            <div key={g.id} style={{ display:'flex', justifyContent:'center' }}>
              <SpringTile g={g} onTap={() => setOpen(i)} badge={!PROGRESS[g.id] && g.last === 'new'}/>
            </div>
          ))}
        </div>

        <div style={{ display:'flex', justifyContent:'center', gap:6, marginTop:34, opacity: open !== null ? 0.2 : 1, transition: 'opacity .25s' }}>
          <div style={{ width:7, height:7, borderRadius:4, background:NAV_PAL.ink }}/>
          <div style={{ width:7, height:7, borderRadius:4, background:'rgba(0,0,0,0.18)' }}/>
        </div>

        {/* dim */}
        <div onClick={() => setOpen(null)} style={{
          position:'absolute', inset:0,
          background: open !== null ? 'rgba(20,12,6,0.4)' : 'transparent',
          pointerEvents: open !== null ? 'auto' : 'none',
          transition: 'background .25s',
          zIndex: 10,
        }}/>

        {/* sheet */}
        <div style={{
          position:'absolute', left: 0, right: 0, bottom: 0,
          height: '74%',
          transform: open !== null ? 'translateY(0)' : 'translateY(100%)',
          transition: 'transform .35s cubic-bezier(.2,.7,.3,1)',
          background: NAV_PAL.bg,
          borderTopLeftRadius: 26, borderTopRightRadius: 26,
          boxShadow: '0 -20px 40px rgba(0,0,0,0.25)',
          zIndex: 11,
          display:'flex', flexDirection:'column',
        }}>
          {g && <SheetBody g={g} onClose={() => setOpen(null)}/>}
        </div>
      </div>
    </IOSDevice>
  );
}

function SheetBody({ g, onClose }) {
  const prog = PROGRESS[g.id];
  const modes = MODES[g.id];
  return (
    <>
      {/* grabber */}
      <div style={{ display:'flex', justifyContent:'center', padding:'8px 0 0' }}>
        <div style={{ width:36, height:5, borderRadius:3, background:'rgba(0,0,0,0.18)' }}/>
      </div>

      <div style={{ padding:'10px 22px 0', display:'flex', alignItems:'center', gap:14 }}>
        <div style={{
          width:72, height:72, borderRadius:18, background: g.color,
          display:'flex', alignItems:'center', justifyContent:'center',
          boxShadow:`0 12px 24px -10px ${g.color}aa, inset 0 1px 0 rgba(255,255,255,0.3)`,
        }}>
          <NavGlyph kind={g.glyph} size={40} color="#FFFFFF"/>
        </div>
        <div style={{ flex:1, minWidth:0 }}>
          <div style={{ fontWeight:800, fontSize:24, letterSpacing:-0.6 }}>{g.name}</div>
          <div style={{ fontFamily:SPRING_MONO, fontSize:11, color:NAV_PAL.mute, letterSpacing:0.8, marginTop:4, textTransform:'uppercase' }}>
            {g.meta} · last played {g.last}
          </div>
        </div>
        <button onClick={onClose} style={{
          width:30, height:30, borderRadius:15, border:'none', cursor:'pointer',
          background:'rgba(0,0,0,0.06)', color: NAV_PAL.ink2,
          display:'flex', alignItems:'center', justifyContent:'center', fontSize:14,
        }}>✕</button>
      </div>

      <div style={{ padding:'16px 18px 0', overflow:'auto' }}>
        {prog && (
          <button style={{
            width:'100%', border:'none', cursor:'pointer', textAlign:'left',
            background: g.color, color:'#FFFFFF', borderRadius:18, padding:'14px 16px',
            display:'grid', gridTemplateColumns:'1fr auto', alignItems:'center', gap:12,
            boxShadow:`0 12px 24px -14px ${g.color}aa`,
          }}>
            <div>
              <div style={{ fontFamily:SPRING_MONO, fontSize:10, letterSpacing:1.4, opacity:0.85 }}>CONTINUE</div>
              <div style={{ fontWeight:700, fontSize:17, marginTop:2 }}>{prog.resume} elapsed</div>
              <div style={{
                marginTop:8, height:4, borderRadius:2,
                background:'rgba(255,255,255,0.25)', width:'100%', overflow:'hidden',
              }}>
                <div style={{ height:'100%', width:`${Math.min(prog.cleared * 2, 100)}%`, background:'#FFFFFF' }}/>
              </div>
            </div>
            <div style={{
              width:44, height:44, borderRadius:22, background:'rgba(255,255,255,0.2)',
              display:'flex', alignItems:'center', justifyContent:'center',
            }}>
              <svg width="14" height="16" viewBox="0 0 14 16" fill="#FFFFFF"><path d="M2 1l11 7-11 7V1z"/></svg>
            </div>
          </button>
        )}

        <div style={{ marginTop: 18 }}>
          <div style={{ fontFamily:SPRING_MONO, fontSize:10, color:NAV_PAL.mute, letterSpacing:1.6, marginBottom:8 }}>
            {modes.kind.toUpperCase()}
          </div>
          <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:8 }}>
            {modes.items.map(([label, hint], i) => (
              <button key={i} style={{
                border:`1.5px solid ${i === 1 ? g.color : NAV_PAL.hairline}`,
                cursor:'pointer', borderRadius:12, padding:'12px 10px',
                background: i === 1 ? `${g.color}12` : NAV_PAL.card,
                display:'flex', flexDirection:'column', alignItems:'flex-start', gap:4,
                color: NAV_PAL.ink,
              }}>
                <div style={{ fontWeight:700, fontSize:13 }}>{label}</div>
                <div style={{ fontFamily:SPRING_MONO, fontSize:10, letterSpacing:0.5, color:NAV_PAL.mute, textTransform:'uppercase' }}>{hint}</div>
              </button>
            ))}
          </div>
        </div>

        <div style={{
          marginTop: 18, padding:'12px 14px', borderRadius:12,
          background: NAV_PAL.card, boxShadow:`inset 0 0 0 1px ${NAV_PAL.hairline}`,
          display:'flex', alignItems:'center', justifyContent:'space-between',
        }}>
          <div style={{ display:'flex', alignItems:'center', gap:10 }}>
            <NavGlyph kind="sparkle" size={18} color={g.color}/>
            <div>
              <div style={{ fontWeight:700, fontSize:13.5 }}>Daily challenge</div>
              <div style={{ fontFamily:SPRING_MONO, fontSize:10, color:NAV_PAL.mute, letterSpacing:0.6, marginTop:1 }}>
                NEW IN 06H 22M
              </div>
            </div>
          </div>
          <div style={{ color: NAV_PAL.mute }}>›</div>
        </div>

        <div style={{ marginTop: 14, display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:8 }}>
          {[['BEST', g.best || '—'],['PLAYED','142'],['STREAK','4 d']].map(([k,v]) => (
            <div key={k} style={{
              padding:'12px 10px', borderRadius:12,
              background: NAV_PAL.card, boxShadow:`inset 0 0 0 1px ${NAV_PAL.hairline}`,
            }}>
              <div style={{ fontFamily:SPRING_MONO, fontSize:9.5, color:NAV_PAL.mute, letterSpacing:1.4 }}>{k}</div>
              <div style={{ fontWeight:700, fontSize:15, marginTop:2 }}>{v}</div>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}

// ════════════════════════════════════════════════════════════════
// D3 · EXPAND-IN-PLACE
// Tile blooms inline: other tiles fade out, tapped tile floats up
// and reveals modes below it on the same surface. No new "screen".
// ════════════════════════════════════════════════════════════════
function SpringExpand() {
  const { useState } = React;
  const [open, setOpen] = useState(null);

  return (
    <IOSDevice width={390} height={844} time="8:38">
      <div style={{
        position:'relative', minHeight:'100%', width:'100%',
        background: NAV_PAL.bg, fontFamily: NAV_FONT, color: NAV_PAL.ink, paddingTop: 54,
        overflow:'hidden',
      }}>
        <SpringHeader/>
        <SpringSearch dim={open !== null}/>

        {/* grid morphs: when one is open, others collapse to a tight strip at top */}
        <div style={{
          padding:'22px 26px 0',
          display:'grid',
          gridTemplateColumns: open === null ? '1fr 1fr 1fr' : 'repeat(6, 1fr)',
          gap: open === null ? '26px 14px' : '8px',
          transition: 'grid-template-columns .35s cubic-bezier(.2,.7,.3,1), gap .35s',
        }}>
          {GAMES.map((g, i) => {
            const isOpen = open === i;
            const isOther = open !== null && !isOpen;
            return (
              <div key={g.id} style={{ display:'flex', justifyContent:'center', alignItems:'center', minHeight: isOther ? 50 : 'auto' }}>
                <SpringTile
                  g={g}
                  onTap={() => setOpen(isOpen ? null : i)}
                  size={isOther ? 44 : (isOpen ? 96 : 78)}
                  highlight={isOpen}
                  badge={!PROGRESS[g.id] && g.last === 'new' && !isOther}
                />
              </div>
            );
          })}
        </div>

        {/* expanded detail below */}
        <div style={{
          margin:'18px 22px 0',
          maxHeight: open !== null ? 480 : 0,
          opacity: open !== null ? 1 : 0,
          overflow: 'hidden',
          transition: 'max-height .35s cubic-bezier(.2,.7,.3,1), opacity .25s .05s',
        }}>
          {open !== null && <ExpandDetail g={GAMES[open]} onClose={() => setOpen(null)}/>}
        </div>

        <div style={{ display:'flex', justifyContent:'center', gap:6, marginTop: open === null ? 34 : 12, transition:'margin .35s' }}>
          <div style={{ width:7, height:7, borderRadius:4, background:NAV_PAL.ink }}/>
          <div style={{ width:7, height:7, borderRadius:4, background:'rgba(0,0,0,0.18)' }}/>
        </div>
      </div>
    </IOSDevice>
  );
}

function ExpandDetail({ g, onClose }) {
  const prog = PROGRESS[g.id];
  const modes = MODES[g.id];
  return (
    <div style={{
      background: NAV_PAL.card, borderRadius: 22, padding: 18,
      boxShadow: '0 12px 28px -16px rgba(76,38,20,0.25)',
    }}>
      <div style={{ display:'flex', alignItems:'baseline', justifyContent:'space-between' }}>
        <div>
          <div style={{ fontWeight:800, fontSize:22, letterSpacing:-0.5 }}>{g.name}</div>
          <div style={{ fontFamily:SPRING_MONO, fontSize:10.5, color:NAV_PAL.mute, letterSpacing:0.8, marginTop:2, textTransform:'uppercase' }}>
            {g.meta} · last {g.last}
          </div>
        </div>
        <button onClick={onClose} style={{
          background:'transparent', border:'none', cursor:'pointer',
          fontFamily: SPRING_MONO, fontSize: 11, color: NAV_PAL.mute, letterSpacing: 1.2,
        }}>CLOSE ✕</button>
      </div>

      {prog && (
        <button style={{
          marginTop: 14, width:'100%', border:'none', cursor:'pointer', textAlign:'left',
          background: g.color, color:'#FFFFFF', borderRadius:14, padding:'12px 14px',
          display:'grid', gridTemplateColumns:'1fr auto', alignItems:'center', gap:12,
        }}>
          <div>
            <div style={{ fontFamily:SPRING_MONO, fontSize:10, letterSpacing:1.4, opacity:0.85 }}>CONTINUE</div>
            <div style={{ fontWeight:700, fontSize:15, marginTop:2 }}>{prog.resume} · {prog.cleared} cleared</div>
          </div>
          <div style={{
            width:36, height:36, borderRadius:18, background:'rgba(255,255,255,0.2)',
            display:'flex', alignItems:'center', justifyContent:'center',
          }}>
            <svg width="11" height="13" viewBox="0 0 14 16" fill="#FFFFFF"><path d="M2 1l11 7-11 7V1z"/></svg>
          </div>
        </button>
      )}

      <div style={{ marginTop: prog ? 14 : 14 }}>
        <div style={{ fontFamily:SPRING_MONO, fontSize:10, color:NAV_PAL.mute, letterSpacing:1.6, marginBottom:8 }}>
          {modes.kind.toUpperCase()}
        </div>
        <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:8 }}>
          {modes.items.map(([label, hint], i) => (
            <button key={i} style={{
              border:`1.5px solid ${i === 1 ? g.color : NAV_PAL.hairline}`,
              cursor:'pointer', borderRadius:12, padding:'10px 8px',
              background: i === 1 ? `${g.color}12` : '#FBFAF5',
              display:'flex', flexDirection:'column', alignItems:'flex-start', gap:3,
              color: NAV_PAL.ink, minHeight: 56,
            }}>
              <div style={{ fontWeight:700, fontSize:12.5 }}>{label}</div>
              <div style={{ fontFamily:SPRING_MONO, fontSize:9.5, letterSpacing:0.5, color:NAV_PAL.mute, textTransform:'uppercase' }}>{hint}</div>
            </button>
          ))}
        </div>
      </div>

      <div style={{ marginTop:12, display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:6 }}>
        {[['BEST', g.best || '—'],['PLAYED','142'],['DAILY','06h']].map(([k,v]) => (
          <div key={k} style={{
            padding:'10px 12px', borderRadius:10,
            background:'#FBFAF5', boxShadow:`inset 0 0 0 1px ${NAV_PAL.hairline}`,
          }}>
            <div style={{ fontFamily:SPRING_MONO, fontSize:9, color:NAV_PAL.mute, letterSpacing:1.3 }}>{k}</div>
            <div style={{ fontWeight:700, fontSize:13.5, marginTop:1 }}>{v}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

// inject keyframes once
if (typeof document !== 'undefined' && !document.getElementById('spring-keyframes')) {
  const s = document.createElement('style');
  s.id = 'spring-keyframes';
  s.textContent = '@keyframes springMenuIn { from { opacity:0; transform: translateX(-50%) scale(0.92) translateY(-6px); } to { opacity:1; transform: translateX(-50%) scale(1) translateY(0); } }';
  document.head.appendChild(s);
}

Object.assign(window, { SpringQuickActions, SpringBottomSheet, SpringExpand });
