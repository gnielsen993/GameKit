// v8-icons.jsx — Icon refinement pass.
// Goal: each glyph signals the SPECIFIC game (not just "dots in a grid").
// Constraints: single color, geometric shapes, readable at 28px and 78px,
// consistent stroke weight across the family.

// ─────────────────────────────────────────────────────────────────
// New glyph set — one canonical shape per game.
// ─────────────────────────────────────────────────────────────────
function GameIcon({ kind, size = 40, color = '#FFFFFF' }) {
  const s = size;
  const stroke = Math.max(1.8, s * 0.075);
  switch (kind) {

    // MINESWEEPER → a flag stuck in a mine-grid base.
    // The flag is THE minesweeper signature; the dotted base anchors it
    // to a grid so it reads as the game, not generic "flag".
    case 'mine': return (
      <svg width={s} height={s} viewBox="0 0 40 40" fill="none">
        {/* tiny grid base */}
        <g fill={color} opacity="0.45">
          <rect x="6"  y="32" width="4" height="4" rx="0.8"/>
          <rect x="12" y="32" width="4" height="4" rx="0.8"/>
          <rect x="18" y="32" width="4" height="4" rx="0.8"/>
          <rect x="24" y="32" width="4" height="4" rx="0.8"/>
          <rect x="30" y="32" width="4" height="4" rx="0.8"/>
        </g>
        {/* pole */}
        <path d="M14 32 V8" stroke={color} strokeWidth={stroke} strokeLinecap="round"/>
        {/* flag */}
        <path d="M14 8 L28 12 L14 16 Z" fill={color}/>
      </svg>
    );

    // MERGE → two rounded tiles overlapping into one. Reads as "combine".
    case 'merge': return (
      <svg width={s} height={s} viewBox="0 0 40 40" fill="none">
        <rect x="6"  y="6"  width="18" height="18" rx="3.5" fill={color} opacity="0.42"/>
        <rect x="16" y="16" width="18" height="18" rx="3.5" fill={color}/>
      </svg>
    );

    // NONOGRAM (Picross) → the picture that emerges. A 5×5 pixel
    // heart, with empty cells faintly visible so the "grid" is still
    // present. This is the satisfying reveal at the end of a puzzle.
    case 'nono': return (
      <svg width={s} height={s} viewBox="0 0 40 40" fill="none">
        {(() => {
          const HEART = [
            [0,1,0,1,0],
            [1,1,1,1,1],
            [1,1,1,1,1],
            [0,1,1,1,0],
            [0,0,1,0,0],
          ];
          const cell = 5.6, gap = 0.6, ox = 6, oy = 7;
          const tiles = [];
          for (let r = 0; r < 5; r++) for (let c = 0; c < 5; c++) {
            tiles.push(
              <rect key={`${r}-${c}`}
                    x={ox + c*(cell+gap)} y={oy + r*(cell+gap)}
                    width={cell} height={cell} rx="0.8"
                    fill={color} opacity={HEART[r][c] ? 1 : 0.18}/>
            );
          }
          return tiles;
        })()}
      </svg>
    );

    // SUDOKU → 3×3 grid (the box) with one numeral filled in.
    // "9" in particular says "sudoku" more than any other digit.
    case 'sudoku': return (
      <svg width={s} height={s} viewBox="0 0 40 40" fill="none">
        <rect x="4" y="4" width="32" height="32" rx="3" stroke={color} strokeWidth={stroke}/>
        <path d="M14.7 4 V36 M25.3 4 V36 M4 14.7 H36 M4 25.3 H36"
              stroke={color} strokeWidth={stroke*0.5} opacity="0.55"/>
        {/* a bold "9" in the center cell */}
        <text x="20" y="27" textAnchor="middle"
              fontFamily='-apple-system, "SF Pro Rounded", system-ui'
              fontSize="11" fontWeight="800" fill={color}>9</text>
      </svg>
    );

    // SOLITAIRE → 3 fanned cards, the front one shows a suit corner.
    // Most universally-readable "cards" icon.
    case 'soli': return (
      <svg width={s} height={s} viewBox="0 0 40 40" fill="none">
        {/* back card (tilted left) */}
        <g transform="rotate(-14 20 22)">
          <rect x="9" y="11" width="14" height="20" rx="2" fill={color} opacity="0.4"/>
        </g>
        {/* middle card */}
        <g transform="rotate(4 20 22)">
          <rect x="12" y="9" width="14" height="20" rx="2" fill={color} opacity="0.65"/>
        </g>
        {/* front card */}
        <g transform="rotate(18 20 22)">
          <rect x="14" y="8" width="14" height="20" rx="2" fill={color}/>
          {/* heart corner */}
          <path d="M17.5 12.5 c-0.7 -1.1 -2.3 -1.1 -2.7 0.2 c -0.3 1 0.8 2.2 2.2 3.1 c 1.4 -0.9 2.5 -2.1 2.2 -3.1 c -0.4 -1.3 -2 -1.3 -1.7 -0.2 Z" fill="#FFFFFF" opacity="0.92"/>
        </g>
      </svg>
    );

    // FREECELL → 4 free cells (row of 4 squares) with a card emerging.
    // The "4 cells" is the literal game name/mechanic.
    case 'free': return (
      <svg width={s} height={s} viewBox="0 0 40 40" fill="none">
        {/* 4 free cells on top */}
        <g stroke={color} strokeWidth={stroke*0.85} fill="none">
          <rect x="4"  y="5" width="7" height="9" rx="1.4"/>
          <rect x="13" y="5" width="7" height="9" rx="1.4"/>
          <rect x="22" y="5" width="7" height="9" rx="1.4"/>
          <rect x="31" y="5" width="5" height="9" rx="1.4"/>
        </g>
        {/* one cell is occupied */}
        <rect x="13" y="5" width="7" height="9" rx="1.4" fill={color}/>
        {/* a fan of cards below */}
        <g transform="translate(20 28)">
          <rect x="-13" y="-6" width="10" height="14" rx="1.6" fill={color} opacity="0.4" transform="rotate(-12)"/>
          <rect x="-5"  y="-6" width="10" height="14" rx="1.6" fill={color} opacity="0.7"/>
          <rect x="3"   y="-6" width="10" height="14" rx="1.6" fill={color} transform="rotate(12)"/>
        </g>
      </svg>
    );

    // UPCOMING — sparkle (kept from before, tightened)
    case 'sparkle': return (
      <svg width={s} height={s} viewBox="0 0 40 40" fill={color}>
        <path d="M20 4 L22 17 L34 20 L22 23 L20 36 L18 23 L6 20 L18 17 Z"/>
        <path d="M31 7 L32 11 L36 12 L32 13 L31 17 L30 13 L26 12 L30 11 Z" opacity="0.65"/>
      </svg>
    );
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────
// Icon Lab — comparison artboard
// ─────────────────────────────────────────────────────────────────
function IconLab() {
  const rows = [
    { id:'mine',   name:'Minesweeper', color:'#2F7BF6', note:'flag in a mine grid' },
    { id:'merge',  name:'Merge',       color:'#29C254', note:'two tiles becoming one' },
    { id:'nono',   name:'Nonogram',    color:'#E84743', note:'grid + edge hints + partial fill' },
    { id:'sudoku', name:'Sudoku',      color:'#E89A1F', note:'3×3 box with a "9"' },
    { id:'soli',   name:'Solitaire',   color:'#1AB4C2', note:'fanned cards w/ heart corner' },
    { id:'free',   name:'FreeCell',    color:'#A458EE', note:'4 free cells + card fan' },
  ];

  const MONO = '"SF Mono", ui-monospace, Menlo, monospace';

  return (
    <div style={{
      background: '#F9F0E6', padding: '28px 24px', fontFamily: NAV_FONT,
      color: '#1A1410', minWidth: 760,
    }}>
      <div style={{ fontFamily: MONO, fontSize: 11, color:'#9C9388', letterSpacing: 1.8 }}>ICON LAB</div>
      <div style={{ fontWeight: 800, fontSize: 26, letterSpacing: -0.6, marginTop: 4 }}>
        Each glyph now signals the game itself.
      </div>
      <div style={{ fontSize: 13.5, color:'#5A4F44', marginTop: 6, maxWidth: 540, lineHeight: 1.45 }}>
        Old icons (left) were generic grids and suit symbols. New icons (center, three sizes) lean on the game's signature mechanic — a flag for Minesweeper, hint marks for Nonogram, fanned cards for Solitaire. Same single-color palette, same visual weight.
      </div>

      {/* column headers */}
      <div style={{
        display:'grid', gridTemplateColumns: '160px 80px 1fr 70px 50px 36px',
        gap: 16, padding: '24px 16px 8px',
        fontFamily: MONO, fontSize: 10, color:'#9C9388', letterSpacing: 1.4,
      }}>
        <div>GAME</div>
        <div>BEFORE</div>
        <div>AFTER · 78 / 56 / 36 PX</div>
        <div style={{ gridColumn:'span 3' }}>SIGNAL</div>
      </div>

      {rows.map(g => (
        <div key={g.id} style={{
          display:'grid', gridTemplateColumns: '160px 80px 1fr',
          gap: 16, alignItems:'center', padding: '12px 16px',
          background:'#FFFFFF', borderRadius: 16, marginBottom: 8,
          boxShadow:'0 1px 2px rgba(76,38,20,0.04)',
        }}>
          <div>
            <div style={{ fontWeight: 700, fontSize: 16, letterSpacing: -0.2 }}>{g.name}</div>
            <div style={{
              fontFamily: MONO, fontSize: 10.5, color:'#9C9388',
              letterSpacing: 0.6, marginTop: 2, textTransform: 'uppercase',
            }}>{g.note}</div>
          </div>

          {/* before */}
          <div style={{
            width: 56, height: 56, borderRadius: 14,
            background: g.color,
            display:'flex', alignItems:'center', justifyContent:'center',
            boxShadow:`0 6px 12px -6px ${g.color}99`,
          }}>
            <NavGlyph
              kind={g.id === 'mine' ? 'mine' : g.id === 'merge' ? 'merge' : g.id === 'nono' ? 'nono' : g.id === 'sudoku' ? 'sudoku' : g.id === 'soli' ? 'heart' : 'spade'}
              size={32} color="#FFFFFF"
            />
          </div>

          {/* after — 3 sizes */}
          <div style={{ display:'flex', alignItems:'center', gap: 18 }}>
            {[78, 56, 36].map(sz => (
              <div key={sz} style={{
                width: sz, height: sz, borderRadius: sz * 0.26,
                background: g.color,
                display:'flex', alignItems:'center', justifyContent:'center',
                boxShadow:`0 ${sz/10}px ${sz/4}px -${sz/8}px ${g.color}99`,
              }}>
                <GameIcon kind={g.id} size={sz * 0.62} color="#FFFFFF"/>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────────
// SpringTile v2 — uses new GameIcon glyphs
// ─────────────────────────────────────────────────────────────────
function SpringTileV2({ g, onTap, dim = false, highlight = false, badge = false, size = 78 }) {
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
        <GameIcon kind={g.id} size={size * 0.62} color="#FFFFFF"/>
        {badge && (
          <div style={{
            position:'absolute', top:-4, right:-4,
            width:18, height:18, borderRadius:9,
            background:'#FFFFFF', color: g.color,
            fontFamily:'"SF Mono", monospace', fontSize:9.5, fontWeight:700,
            display:'flex', alignItems:'center', justifyContent:'center',
            boxShadow:'0 2px 4px rgba(0,0,0,0.15)',
          }}>!</div>
        )}
      </div>
      <div style={{ fontWeight:600, fontSize:13, letterSpacing:-0.1, color: NAV_PAL.ink }}>{g.name}</div>
    </button>
  );
}

// ─────────────────────────────────────────────────────────────────
// SpringExpand v2 — committed D3 with new icons
// (Re-implements the same expand-in-place interaction using SpringTileV2)
// ─────────────────────────────────────────────────────────────────
function SpringExpandV2() {
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
                <SpringTileV2
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

Object.assign(window, { GameIcon, IconLab, SpringTileV2, SpringExpandV2 });
