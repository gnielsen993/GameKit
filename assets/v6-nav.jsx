// V6 — Navigation explorations for the new (6+ game) home screen.
// Keeps the user's current aesthetic: warm cream bg + per-game accent color,
// rounded icon tile, single-color glyph. Only the navigation pattern changes.

const NAV_PAL = {
  bg:       '#F9F0E6',
  card:     '#FFFFFF',
  ink:      '#1A1410',
  ink2:     '#3A322A',
  mute:     '#9C9388',
  hairline: '#EBE2D4',
  upBg:     '#F3E9DE',
  upInk:    '#5A3F66',
};

const GAMES = [
  { id:'mine',   name:'Minesweeper', short:'Mines',  color:'#2F7BF6', glyph:'mine',  cat:'logic',  last:'2m ago',   meta:'010 mines',  best:'02:14' },
  { id:'merge',  name:'Merge',       short:'Merge',  color:'#29C254', glyph:'merge', cat:'logic',  last:'yesterday',meta:'best · 0',    best:'—'      },
  { id:'nono',   name:'Nonogram',    short:'Nono',   color:'#E84743', glyph:'nono',  cat:'logic',  last:'3d ago',   meta:'10 × 10',     best:'04:02'  },
  { id:'sudoku', name:'Sudoku',      short:'Sudoku', color:'#E89A1F', glyph:'sudoku',cat:'number', last:'1w ago',   meta:'medium',      best:'08:31'  },
  { id:'soli',   name:'Solitaire',   short:'Soli',   color:'#1AB4C2', glyph:'heart', cat:'cards',  last:'new',      meta:'klondike',    best:'—'      },
  { id:'free',   name:'FreeCell',    short:'Free',   color:'#A458EE', glyph:'spade', cat:'cards',  last:'new',      meta:'standard',    best:'—'      },
];

const NAV_MONO = '"SF Mono", ui-monospace, Menlo, monospace';
const NAV_FONT = '-apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif';

// Game glyphs — single color, mirror the screenshot icons.
function NavGlyph({ kind, size = 28, color }) {
  const s = size;
  switch (kind) {
    case 'mine': // 4×4 dot grid
      return (
        <div style={{ display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:s*0.08, width:s, height:s }}>
          {Array.from({length:16}).map((_,i)=>(
            <div key={i} style={{ background:color, borderRadius:s*0.06 }}/>
          ))}
        </div>
      );
    case 'merge': // stacked layers
      return (
        <div style={{ position:'relative', width:s, height:s }}>
          {[0,1,2].map(i => (
            <div key={i} style={{
              position:'absolute', left:s*0.07, right:s*0.07,
              top: s*0.18 + i*s*0.22, height: s*0.2,
              borderRadius: s*0.04, background: color, opacity: 1 - i*0.15,
              transform: 'skewX(-22deg)',
            }}/>
          ))}
        </div>
      );
    case 'nono': // ring + inner grid
      return (
        <div style={{
          width:s, height:s, border:`${Math.max(2,s*0.11)}px solid ${color}`, borderRadius:s*0.18,
          display:'grid', gridTemplateColumns:'repeat(3,1fr)', gap:s*0.05, padding:s*0.12, boxSizing:'border-box',
        }}>
          {[1,0,1,0,1,0,1,0,1].map((v,i)=>(
            <div key={i} style={{ background: v? color : 'transparent', borderRadius:s*0.04 }}/>
          ))}
        </div>
      );
    case 'sudoku':
      return (
        <div style={{ display:'grid', gridTemplateColumns:'repeat(3,1fr)', gap:s*0.1, width:s, height:s }}>
          {Array.from({length:9}).map((_,i)=>(
            <div key={i} style={{ background:color, borderRadius:s*0.07 }}/>
          ))}
        </div>
      );
    case 'heart':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24" fill={color}>
          <path d="M12 21s-7-4.35-9.5-9C1 8.5 3.5 4.5 7.5 4.5c2 0 3.5 1 4.5 2.5 1-1.5 2.5-2.5 4.5-2.5 4 0 6.5 4 5 7.5C19 16.65 12 21 12 21z"/>
        </svg>
      );
    case 'spade':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24" fill={color}>
          <path d="M12 2C7 7 3 10 3 14a4.5 4.5 0 0 0 7 3.7L9 22h6l-1-4.3A4.5 4.5 0 0 0 21 14c0-4-4-7-9-12z"/>
        </svg>
      );
    case 'sparkle':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24" fill={color}>
          <path d="M12 2 L13.5 9.5 L21 11 L13.5 12.5 L12 20 L10.5 12.5 L3 11 L10.5 9.5 Z"/>
          <circle cx="19" cy="5" r="1.4" opacity="0.7"/>
          <circle cx="5" cy="19" r="1.1" opacity="0.7"/>
        </svg>
      );
    default: return null;
  }
}

// Status-bar wrapper used by every variant.
function NavFrame({ children, time='8:38', bg=NAV_PAL.bg }) {
  return (
    <IOSDevice width={390} height={844} time={time}>
      <div style={{
        background: bg, minHeight: '100%', width: '100%',
        fontFamily: NAV_FONT, color: NAV_PAL.ink, paddingTop: 54,
      }}>
        {children}
      </div>
    </IOSDevice>
  );
}

function Avatar() {
  return (
    <div style={{
      width:36, height:36, borderRadius:18, background:'#FBF6E8',
      border:`1px solid ${NAV_PAL.hairline}`, display:'flex',
      alignItems:'center', justifyContent:'center',
    }}>
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="9" r="3.4" stroke={NAV_PAL.ink} strokeWidth="1.7"/>
        <path d="M5 20c1.5-3.6 4.2-5.2 7-5.2s5.5 1.6 7 5.2" stroke={NAV_PAL.ink} strokeWidth="1.7" strokeLinecap="round"/>
      </svg>
    </div>
  );
}

// Icon tile — colored rounded square w/ glyph, used by several variants.
function IconTile({ color, glyph, size = 56, radius }) {
  const r = radius ?? size * 0.26;
  // light tinted bg for the icon, color glyph — matches user's screenshot.
  return (
    <div style={{
      width: size, height: size, borderRadius: r,
      background: '#FFFFFF',
      boxShadow: `inset 0 0 0 1px ${NAV_PAL.hairline}`,
      display:'flex', alignItems:'center', justifyContent:'center',
    }}>
      <NavGlyph kind={glyph} size={size*0.55} color={color}/>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════
// NAV-A · COMPACT 2-COLUMN GRID
// All 6 games visible w/o scroll. Color is in the icon tile only,
// not the whole bar — feels calmer than the current screen.
// ════════════════════════════════════════════════════════════════
function NavA_Grid() {
  const Tile = ({ g }) => (
    <button style={{
      border:'none', cursor:'pointer', textAlign:'left',
      background: NAV_PAL.card, borderRadius: 20, padding: 14,
      boxShadow:'0 1px 2px rgba(76,38,20,0.05), 0 8px 18px -14px rgba(76,38,20,0.18)',
      display:'flex', flexDirection:'column', gap: 12,
      minHeight: 138,
    }}>
      <div style={{
        width:54, height:54, borderRadius:14,
        background: g.color,
        display:'flex', alignItems:'center', justifyContent:'center',
        boxShadow: `0 4px 12px -4px ${g.color}66`,
      }}>
        <NavGlyph kind={g.glyph} size={30} color="#FFFFFF"/>
      </div>
      <div style={{ marginTop:'auto' }}>
        <div style={{ fontWeight:700, fontSize:16, letterSpacing:-0.2 }}>{g.name}</div>
        <div style={{ fontSize:11.5, fontFamily:NAV_MONO, color:NAV_PAL.mute, letterSpacing:0.6, marginTop:2, textTransform:'uppercase' }}>
          {g.last}
        </div>
      </div>
    </button>
  );
  return (
    <NavFrame>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'10px 22px 4px' }}>
        <div>
          <div style={{ fontFamily:NAV_MONO, fontSize:10.5, color:NAV_PAL.mute, letterSpacing:1.6 }}>6 GAMES</div>
          <div style={{ fontWeight:800, fontSize:34, letterSpacing:-1.1, marginTop:2 }}>The Drawer</div>
        </div>
        <Avatar/>
      </div>

      <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:12, padding:'16px 18px 0' }}>
        {GAMES.map(g => <Tile key={g.id} g={g}/>)}
      </div>

      {/* upcoming as a wide low-emphasis card */}
      <button style={{
        margin: '12px 18px 0', width:'calc(100% - 36px)',
        border:`1.5px dashed ${NAV_PAL.hairline}`, background:'transparent',
        borderRadius:18, padding:'14px 18px', cursor:'pointer',
        display:'flex', alignItems:'center', justifyContent:'space-between',
        color: NAV_PAL.upInk,
      }}>
        <div style={{ display:'flex', alignItems:'center', gap:12 }}>
          <NavGlyph kind="sparkle" size={22} color={NAV_PAL.upInk}/>
          <div style={{ textAlign:'left' }}>
            <div style={{ fontWeight:700, fontSize:14.5 }}>Upcoming</div>
            <div style={{ fontFamily:NAV_MONO, fontSize:10.5, letterSpacing:0.8, color:NAV_PAL.mute, marginTop:2 }}>
              5 GAMES COMING
            </div>
          </div>
        </div>
        <div style={{ color: NAV_PAL.mute }}>›</div>
      </button>
    </NavFrame>
  );
}

// ════════════════════════════════════════════════════════════════
// NAV-B · CONTINUE + LIBRARY
// Surfaces the one thing you're most likely to do (continue last)
// as a hero card; everything else collapses into a tidy 3-col grid.
// ════════════════════════════════════════════════════════════════
function NavB_Hero() {
  const hero = GAMES[0];
  const rest = GAMES.slice(1);

  return (
    <NavFrame>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'10px 22px 4px' }}>
        <div style={{ fontWeight:800, fontSize:30, letterSpacing:-1 }}>The Drawer</div>
        <Avatar/>
      </div>

      {/* hero — continue */}
      <div style={{ padding:'14px 18px 0' }}>
        <div style={{ fontFamily:NAV_MONO, fontSize:10, color:NAV_PAL.mute, letterSpacing:1.8, marginBottom:8 }}>CONTINUE</div>
        <button style={{
          width:'100%', border:'none', cursor:'pointer', textAlign:'left',
          background: hero.color, borderRadius: 22, padding: 18, color: '#FFFFFF',
          boxShadow:`0 14px 28px -14px ${hero.color}99`,
          display:'grid', gridTemplateColumns:'auto 1fr auto', alignItems:'center', gap: 16,
        }}>
          <div style={{
            width:64, height:64, borderRadius:16,
            background:'rgba(255,255,255,0.18)',
            display:'flex', alignItems:'center', justifyContent:'center',
            backdropFilter:'blur(10px)',
          }}>
            <NavGlyph kind={hero.glyph} size={36} color="#FFFFFF"/>
          </div>
          <div>
            <div style={{ fontWeight:700, fontSize:20, letterSpacing:-0.3 }}>{hero.name}</div>
            <div style={{ fontSize:12.5, opacity:0.85, marginTop:4, fontFamily:NAV_MONO, letterSpacing:0.6 }}>
              IN PROGRESS · 38 CLEARED
            </div>
            {/* mini progress bar */}
            <div style={{
              marginTop:10, height:5, borderRadius:3,
              background:'rgba(255,255,255,0.25)', overflow:'hidden',
            }}>
              <div style={{ width:'52%', height:'100%', background:'#FFFFFF' }}/>
            </div>
          </div>
          <div style={{
            width:44, height:44, borderRadius:22, background:'rgba(255,255,255,0.18)',
            display:'flex', alignItems:'center', justifyContent:'center',
          }}>
            <svg width="14" height="16" viewBox="0 0 14 16" fill="#FFFFFF"><path d="M2 1l11 7-11 7V1z"/></svg>
          </div>
        </button>
      </div>

      {/* library — 3-col mini grid */}
      <div style={{ padding:'22px 18px 0' }}>
        <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:10 }}>
          <div style={{ fontFamily:NAV_MONO, fontSize:10, color:NAV_PAL.mute, letterSpacing:1.8 }}>LIBRARY</div>
          <div style={{ fontFamily:NAV_MONO, fontSize:10, color:NAV_PAL.mute, letterSpacing:1.4 }}>5 GAMES</div>
        </div>
        <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:10 }}>
          {rest.map(g => (
            <button key={g.id} style={{
              border:'none', cursor:'pointer', padding:'14px 8px 12px',
              background: NAV_PAL.card, borderRadius:18,
              boxShadow:'0 1px 2px rgba(76,38,20,0.05)',
              display:'flex', flexDirection:'column', alignItems:'center', gap:8,
            }}>
              <div style={{
                width:48, height:48, borderRadius:12,
                background:g.color,
                display:'flex', alignItems:'center', justifyContent:'center',
                boxShadow:`0 4px 10px -4px ${g.color}66`,
              }}>
                <NavGlyph kind={g.glyph} size={28} color="#FFFFFF"/>
              </div>
              <div style={{ fontWeight:600, fontSize:12.5, letterSpacing:-0.1 }}>{g.short}</div>
            </button>
          ))}
        </div>
      </div>

      {/* daily challenge strip */}
      <div style={{ padding:'18px 18px 0' }}>
        <div style={{
          display:'flex', alignItems:'center', justifyContent:'space-between',
          padding:'12px 16px', borderRadius:14, background:NAV_PAL.card,
          boxShadow:'inset 0 0 0 1px ' + NAV_PAL.hairline,
        }}>
          <div style={{ display:'flex', alignItems:'center', gap:12 }}>
            <NavGlyph kind="sparkle" size={20} color="#BC3D2E"/>
            <div>
              <div style={{ fontWeight:700, fontSize:14 }}>Daily challenge</div>
              <div style={{ fontSize:11.5, color:NAV_PAL.mute, fontFamily:NAV_MONO, letterSpacing:0.5, marginTop:1 }}>
                NEW IN 06H 22M
              </div>
            </div>
          </div>
          <div style={{ color:NAV_PAL.mute }}>›</div>
        </div>
      </div>
    </NavFrame>
  );
}

// ════════════════════════════════════════════════════════════════
// NAV-C · CATEGORIZED SECTIONS
// Group by genre. Scales as the library grows.
// ════════════════════════════════════════════════════════════════
function NavC_Cats() {
  const cats = [
    { key:'logic',  label:'Logic',  hint:'sweep, merge, fill' },
    { key:'number', label:'Number', hint:'numeric reasoning' },
    { key:'cards',  label:'Cards',  hint:'patience & klondike' },
  ];

  const Row = ({ g }) => (
    <button style={{
      display:'flex', alignItems:'center', gap:14, width:'100%', textAlign:'left',
      border:'none', background:'transparent', cursor:'pointer',
      padding:'10px 0',
    }}>
      <div style={{
        width:48, height:48, borderRadius:12, background: g.color,
        display:'flex', alignItems:'center', justifyContent:'center',
        boxShadow:`0 4px 10px -4px ${g.color}66`,
      }}>
        <NavGlyph kind={g.glyph} size={26} color="#FFFFFF"/>
      </div>
      <div style={{ flex:1, minWidth:0 }}>
        <div style={{ fontWeight:600, fontSize:16, letterSpacing:-0.2 }}>{g.name}</div>
        <div style={{ fontSize:12, color:NAV_PAL.mute, fontFamily:NAV_MONO, letterSpacing:0.5, marginTop:2, textTransform:'uppercase' }}>
          {g.meta} · {g.last}
        </div>
      </div>
      <div style={{ fontFamily:NAV_MONO, fontSize:11, color:NAV_PAL.mute, letterSpacing:0.6, paddingRight:4 }}>
        {g.best}
      </div>
    </button>
  );

  return (
    <NavFrame>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'10px 22px 4px' }}>
        <div style={{ fontWeight:800, fontSize:30, letterSpacing:-1 }}>The Drawer</div>
        <Avatar/>
      </div>

      {/* search */}
      <div style={{ padding:'10px 22px 0' }}>
        <div style={{
          display:'flex', alignItems:'center', gap:10,
          padding:'10px 14px', borderRadius:12,
          background:NAV_PAL.card, boxShadow:'inset 0 0 0 1px ' + NAV_PAL.hairline,
        }}>
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke={NAV_PAL.mute} strokeWidth="2.2">
            <circle cx="11" cy="11" r="7"/><path d="M21 21l-4.5-4.5"/>
          </svg>
          <span style={{ color:NAV_PAL.mute, fontSize:14 }}>Search games</span>
        </div>
      </div>

      <div style={{ padding:'16px 22px 0' }}>
        {cats.map((c, ci) => {
          const games = GAMES.filter(g => g.cat === c.key);
          return (
            <div key={c.key} style={{ marginTop: ci === 0 ? 0 : 18 }}>
              <div style={{
                display:'flex', alignItems:'baseline', justifyContent:'space-between',
                marginBottom: 4,
              }}>
                <div style={{ fontWeight:700, fontSize:14, letterSpacing:0.4, textTransform:'uppercase', color:NAV_PAL.ink2 }}>
                  {c.label}
                </div>
                <div style={{ fontSize:11, color:NAV_PAL.mute, fontFamily:NAV_MONO, letterSpacing:0.6, textTransform:'uppercase' }}>
                  {c.hint}
                </div>
              </div>
              <div style={{
                background:NAV_PAL.card, borderRadius:16, padding:'2px 14px',
                boxShadow:'0 1px 2px rgba(76,38,20,0.04)',
              }}>
                {games.map((g, i) => (
                  <div key={g.id} style={{
                    borderTop: i === 0 ? 'none' : `1px solid ${NAV_PAL.hairline}`,
                  }}>
                    <Row g={g}/>
                  </div>
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </NavFrame>
  );
}

// ════════════════════════════════════════════════════════════════
// NAV-D · SPRINGBOARD
// iOS-home-screen-style 3-col icon grid. Color lives in the icon only.
// Quietest of the four; lets the icons do the navigating.
// ════════════════════════════════════════════════════════════════
function NavD_Spring() {
  const Tile = ({ g, faded }) => (
    <button style={{
      border:'none', background:'transparent', cursor:'pointer',
      display:'flex', flexDirection:'column', alignItems:'center', gap:8,
      padding:0,
      opacity: faded ? 0.5 : 1,
    }}>
      <div style={{
        width: 78, height: 78, borderRadius: 20,
        background: g.color,
        display:'flex', alignItems:'center', justifyContent:'center',
        boxShadow:`0 8px 20px -8px ${g.color}99, inset 0 1px 0 rgba(255,255,255,0.3)`,
        position:'relative',
      }}>
        <NavGlyph kind={g.glyph} size={42} color="#FFFFFF"/>
        {g.last === 'new' && (
          <div style={{
            position:'absolute', top:-4, right:-4,
            width:18, height:18, borderRadius:9,
            background:'#FFFFFF', color:g.color,
            fontFamily:NAV_MONO, fontSize:9.5, fontWeight:700,
            display:'flex', alignItems:'center', justifyContent:'center',
            boxShadow:'0 2px 4px rgba(0,0,0,0.15)',
          }}>!</div>
        )}
      </div>
      <div style={{ fontWeight:600, fontSize:13, letterSpacing:-0.1 }}>{g.name}</div>
      <div style={{
        fontFamily:NAV_MONO, fontSize:9.5, letterSpacing:0.6, color:NAV_PAL.mute,
        textTransform:'uppercase', marginTop:-4,
      }}>{g.last}</div>
    </button>
  );

  // Upcoming as a 3-icon stub at end
  const upcoming = { id:'up', name:'More', short:'More', color:'#C2A7B8', glyph:'sparkle', last:'soon' };

  return (
    <NavFrame>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'10px 22px 4px' }}>
        <div>
          <div style={{ fontFamily:NAV_MONO, fontSize:10.5, color:NAV_PAL.mute, letterSpacing:1.6 }}>WED · MAY 23</div>
          <div style={{ fontWeight:800, fontSize:32, letterSpacing:-1.1, marginTop:2 }}>The Drawer</div>
        </div>
        <Avatar/>
      </div>

      {/* search pill */}
      <div style={{ padding:'14px 60px 0' }}>
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

      <div style={{
        display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:'26px 14px',
        padding:'28px 26px 0',
      }}>
        {GAMES.map(g => <Tile key={g.id} g={g}/>)}
        <Tile g={upcoming} faded/>
      </div>

      {/* page dots */}
      <div style={{
        display:'flex', justifyContent:'center', gap:6, marginTop:34,
      }}>
        <div style={{ width:7, height:7, borderRadius:4, background:NAV_PAL.ink }}/>
        <div style={{ width:7, height:7, borderRadius:4, background:'rgba(0,0,0,0.18)' }}/>
      </div>
    </NavFrame>
  );
}

Object.assign(window, { NavA_Grid, NavB_Hero, NavC_Cats, NavD_Spring });
