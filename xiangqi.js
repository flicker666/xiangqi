'use strict';
/* 中国象棋网页版：引擎（规则）+ AI + 音频 + 界面
 * 棋盘坐标：row 0 在上（黑方底线），row 9 在下（红方底线）；col 0-8 从左到右。
 * 棋子类型：K 将/帅，A 士/仕，E 象/相，H 马，R 车，C 炮，P 卒/兵。
 * 纯静态，无后端。引擎部分可在 Node 下 require 做测试。 */

const ROWS = 10, COLS = 9;
const NAMES = {
  r: { K: '帅', A: '仕', E: '相', H: '马', R: '车', C: '炮', P: '兵' },
  b: { K: '将', A: '士', E: '象', H: '马', R: '车', C: '炮', P: '卒' }
};
const VALUES = { K: 10000, R: 600, C: 300, H: 270, A: 120, E: 120, P: 60 };
const RED_FILES = ['九', '八', '七', '六', '五', '四', '三', '二', '一'];
const CN_NUM = ['一', '二', '三', '四', '五', '六', '七', '八', '九'];
const opp = c => (c === 'r' ? 'b' : 'r');
const inBoard = (r, c) => r >= 0 && r < ROWS && c >= 0 && c < COLS;

function emptyBoard() { return Array.from({ length: ROWS }, () => Array(COLS).fill(null)); }
function initialBoard() {
  const g = emptyBoard();
  const back = ['R', 'H', 'E', 'A', 'K', 'A', 'E', 'H', 'R'];
  for (let c = 0; c < 9; c++) {
    g[0][c] = { t: back[c], c: 'b' };
    g[9][c] = { t: back[c], c: 'r' };
  }
  g[2][1] = { t: 'C', c: 'b' }; g[2][7] = { t: 'C', c: 'b' };
  g[7][1] = { t: 'C', c: 'r' }; g[7][7] = { t: 'C', c: 'r' };
  for (let c = 0; c <= 8; c += 2) { g[3][c] = { t: 'P', c: 'b' }; g[6][c] = { t: 'P', c: 'r' }; }
  return g;
}
function cloneBoard(b) { return b.map(row => row.map(p => (p ? { t: p.t, c: p.c } : null))); }
function pieceAt(b, r, c) { return inBoard(r, c) ? b[r][c] : null; }
function applyMove(b, m) {
  const nb = cloneBoard(b);
  nb[m.tr][m.tc] = nb[m.fr][m.fc];
  nb[m.fr][m.fc] = null;
  return nb;
}
function generalPos(b, color) {
  for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
    const p = b[r][c];
    if (p && p.t === 'K' && p.c === color) return { r, c };
  }
  return null;
}
function fingerprint(b) {
  let s = '';
  for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
    const p = b[r][c];
    if (p) s += r + '' + c + p.c + p.t;
  }
  return s;
}

/* ---------- 走法生成 ---------- */
function cannonMoves(b, fr, fc, color) {
  const out = [];
  for (const [dr, dc] of [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
    let r = fr + dr, c = fc + dc, screen = false;
    while (inBoard(r, c)) {
      const t = b[r][c];
      if (t) {
        if (!screen) screen = true;
        else { if (t.c !== color) out.push({ fr, fc, tr: r, tc: c, captured: t.t }); break; }
      } else if (!screen) out.push({ fr, fc, tr: r, tc: c, captured: null });
      r += dr; c += dc;
    }
  }
  return out;
}

function pseudoMovesForPiece(b, fr, fc) {
  const p = b[fr][fc];
  if (!p) return [];
  const out = [];
  const add = (r, c) => {
    if (!inBoard(r, c)) return;
    const t = b[r][c];
    if (!t) out.push({ fr, fc, tr: r, tc: c, captured: null });
    else if (t.c !== p.c) out.push({ fr, fc, tr: r, tc: c, captured: t.t });
  };
  const slide = (dr, dc) => {
    let r = fr + dr, c = fc + dc;
    while (inBoard(r, c)) {
      const t = b[r][c];
      if (t) { if (t.c !== p.c) out.push({ fr, fc, tr: r, tc: c, captured: t.t }); break; }
      out.push({ fr, fc, tr: r, tc: c, captured: null });
      r += dr; c += dc;
    }
  };
  const palaceRows = p.c === 'r' ? [7, 8, 9] : [0, 1, 2];
  switch (p.t) {
    case 'K':
      for (const [dr, dc] of [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        const r = fr + dr, c = fc + dc;
        if (palaceRows.includes(r) && c >= 3 && c <= 5) add(r, c);
      }
      break;
    case 'A':
      for (const [dr, dc] of [[-1, -1], [-1, 1], [1, -1], [1, 1]]) {
        const r = fr + dr, c = fc + dc;
        if (palaceRows.includes(r) && c >= 3 && c <= 5) add(r, c);
      }
      break;
    case 'E':
      for (const [dr, dc] of [[-2, -2], [-2, 2], [2, -2], [2, 2]]) {
        const r = fr + dr, c = fc + dc;
        if (!inBoard(r, c)) continue;
        if (b[fr + dr / 2][fc + dc / 2]) continue; // 象眼
        if (p.c === 'r' && r < 5) continue;       // 象不过河
        if (p.c === 'b' && r > 4) continue;
        add(r, c);
      }
      break;
    case 'H': {
      const legs = [
        [-1, 0, [[-2, -1], [-2, 1]]],
        [1, 0, [[2, -1], [2, 1]]],
        [0, -1, [[-1, -2], [1, -2]]],
        [0, 1, [[-1, 2], [1, 2]]]
      ];
      for (const [ldr, ldc, targets] of legs) {
        if (pieceAt(b, fr + ldr, fc + ldc)) continue; // 蹩马腿
        for (const [tr, tc] of targets) add(fr + tr, fc + tc);
      }
      break;
    }
    case 'R':
      for (const [dr, dc] of [[-1, 0], [1, 0], [0, -1], [0, 1]]) slide(dr, dc);
      break;
    case 'C':
      out.push(...cannonMoves(b, fr, fc, p.c));
      break;
    case 'P': {
      const fwd = p.c === 'r' ? -1 : 1;
      add(fr + fwd, fc);
      const crossed = p.c === 'r' ? fr <= 4 : fr >= 5;
      if (crossed) { add(fr, fc - 1); add(fr, fc + 1); }
      break;
    }
  }
  return out;
}

function pseudoMoves(b, color) {
  const moves = [];
  for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
    const p = b[r][c];
    if (p && p.c === color) moves.push(...pseudoMovesForPiece(b, r, c));
  }
  return moves;
}

/* 某格是否被 color 一方攻击（含将帅照面） */
function isAttacked(b, r, c, color) {
  const g = generalPos(b, color);
  if (g && g.c === c) {
    let blocked = false;
    for (let rr = Math.min(g.r, r) + 1; rr < Math.max(g.r, r); rr++) {
      if (b[rr][c]) { blocked = true; break; }
    }
    if (!blocked) return true;
  }
  for (const m of pseudoMoves(b, color)) if (m.tr === r && m.tc === c) return true;
  return false;
}
function isInCheck(b, color) {
  const g = generalPos(b, color);
  return g ? isAttacked(b, g.r, g.c, opp(color)) : false;
}
/* 真正合法走法：走完后己方将不被将军，且不能直接吃将 */
function legalMoves(b, color) {
  const out = [];
  for (const m of pseudoMoves(b, color)) {
    const next = applyMove(b, m);
    if (!generalPos(next, opp(color))) continue;
    if (isInCheck(next, color)) continue;
    m.isCheck = isInCheck(next, opp(color));
    out.push(m);
  }
  return out;
}
function hasNoLegalMove(b, color) { return legalMoves(b, color).length === 0; }

/* ---------- 中文着法 ---------- */
function chineseNotation(b, m) {
  const p = b[m.fr][m.fc];
  if (!p) return '?';
  const color = p.c;
  const fromFile = color === 'r' ? RED_FILES[m.fc] : String(m.fc + 1);
  const toFile = color === 'r' ? RED_FILES[m.tc] : String(m.tc + 1);
  let prefix = '';
  const same = [];
  for (let r = 0; r < ROWS; r++) {
    const q = b[r][m.fc];
    if (q && q.t === p.t && q.c === color) same.push(r);
  }
  if (same.length > 1) {
    const sorted = same.sort((a, c2) => (color === 'r' ? c2 - a : a - c2));
    prefix = sorted[0] === m.fr ? '前' : '后';
  }
  const name = NAMES[color][p.t];
  if (m.fc === m.tc) {
    const steps = Math.abs(m.tr - m.fr);
    let dir;
    if (color === 'r') dir = m.tr < m.fr ? '进' : '退';
    else dir = m.tr > m.fr ? '进' : '退';
    const num = color === 'r' ? CN_NUM[steps - 1] : String(steps);
    return prefix + name + fromFile + dir + num;
  }
  return prefix + name + fromFile + '平' + toFile;
}

/* ---------- AI：Negamax + Alpha-Beta + 迭代加深 + 吃子杀棋搜索 ---------- */
const PST = {
  R: [
    [14, 14, 12, 18, 16, 18, 12, 14, 14],
    [16, 20, 18, 24, 26, 24, 18, 20, 16],
    [12, 12, 12, 18, 18, 18, 12, 12, 12],
    [12, 18, 16, 22, 22, 22, 16, 18, 12],
    [12, 14, 12, 18, 18, 18, 12, 14, 12],
    [12, 16, 14, 20, 20, 20, 14, 16, 12],
    [6, 10, 8, 14, 14, 14, 8, 10, 6],
    [4, 8, 6, 14, 12, 14, 6, 8, 4],
    [8, 4, 8, 16, 8, 16, 8, 4, 8],
    [6, 8, 6, 16, 12, 16, 6, 8, 6]
  ],
  H: [
    [4, 8, 16, 12, 4, 12, 16, 8, 4],
    [4, 10, 28, 16, 8, 16, 28, 10, 4],
    [12, 14, 16, 20, 18, 20, 16, 14, 12],
    [8, 24, 18, 24, 20, 24, 18, 24, 8],
    [6, 16, 14, 18, 16, 18, 14, 16, 6],
    [4, 12, 16, 14, 12, 14, 16, 12, 4],
    [4, 6, 10, 6, 10, 6, 10, 6, 4],
    [2, 6, 8, 6, 8, 6, 8, 6, 2],
    [4, 2, 8, 8, 4, 8, 8, 2, 4],
    [0, 2, 4, 4, -2, 4, 4, 2, 0]
  ],
  C: [
    [6, 4, 0, -10, -12, -10, 0, 4, 6],
    [2, 2, 0, -4, -6, -4, 0, 2, 2],
    [2, 2, 0, -4, -4, -4, 0, 2, 2],
    [0, 0, 0, -2, -4, -2, 0, 0, 0],
    [0, 0, 0, -2, 0, -2, 0, 0, 0],
    [-2, 0, 4, 0, 4, 0, 4, 0, -2],
    [0, 0, 0, 2, 4, 2, 0, 0, 0],
    [4, 0, 8, 0, 8, 0, 8, 0, 4],
    [0, 0, 0, 2, 4, 2, 0, 0, 0],
    [4, 0, 4, 0, 4, 0, 4, 0, 4]
  ],
  P: [
    [0, 3, 6, 9, 12, 9, 6, 3, 0],
    [18, 36, 36, 36, 36, 36, 36, 36, 18],
    [14, 26, 24, 26, 24, 26, 24, 26, 14],
    [8, 24, 20, 24, 20, 24, 20, 24, 8],
    [6, 20, 16, 20, 16, 20, 16, 20, 6],
    [2, 10, 8, 10, 8, 10, 8, 10, 2],
    [2, 6, 4, 6, 4, 6, 4, 6, 2],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0]
  ]
};
const DIFFICULTY = {
  easy: { title: '入门', depth: 2, timeLimit: 600 },
  medium: { title: '进阶', depth: 3, timeLimit: 1500 },
  master: { title: '大师', depth: 4, timeLimit: 3000 }
};

function evaluate(b, color) {
  let score = 0;
  for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
    const p = b[r][c];
    if (!p) continue;
    let v = VALUES[p.t];
    const table = PST[p.t];
    if (table) v += table[p.c === 'r' ? r : 9 - r][c];
    if (p.t === 'P') {
      const crossed = p.c === 'r' ? r <= 4 : r >= 5;
      if (crossed) v += 30;
    }
    score += p.c === color ? v : -v;
  }
  return score;
}
function moveOrderScore(b, m) {
  let s = 0;
  if (m.captured) {
    const mover = b[m.fr][m.fc];
    s += 1000 + VALUES[m.captured] - (mover ? VALUES[mover.t] / 10 : 0);
  }
  if (m.isCheck) s += 500;
  return s;
}
function orderedMoves(b, moves) {
  return moves.slice().sort((a, c2) => moveOrderScore(b, c2) - moveOrderScore(b, a));
}

function makeSearcher(deadlineMs) {
  const st = { nodes: 0, stopped: false, deadline: Date.now() + deadlineMs };
  function negamax(b, color, depth, alpha, beta, ply) {
    st.nodes++;
    if (st.nodes % 1024 === 0 && Date.now() > st.deadline) { st.stopped = true; return 0; }
    if (st.stopped) return 0;
    const moves = legalMoves(b, color);
    if (moves.length === 0) return -100000 + ply * 10; // 将死/困毙
    if (depth <= 0) return quiescence(b, color, alpha, beta, ply);
    let a = alpha, best = -Infinity;
    for (const m of orderedMoves(b, moves)) {
      const s = -negamax(applyMove(b, m), opp(color), depth - 1, -beta, -a, ply + 1);
      if (st.stopped) return 0;
      if (s > best) best = s;
      if (s > a) a = s;
      if (a >= beta) break;
    }
    return best;
  }
  function quiescence(b, color, alpha, beta, ply) {
    st.nodes++;
    if (st.nodes % 1024 === 0 && Date.now() > st.deadline) { st.stopped = true; return 0; }
    if (st.stopped) return 0;
    const standPat = evaluate(b, color);
    if (standPat >= beta) return beta;
    let a = Math.max(alpha, standPat);
    if (ply > 12) return a;
    const caps = legalMoves(b, color).filter(m => m.captured);
    for (const m of orderedMoves(b, caps)) {
      const s = -quiescence(applyMove(b, m), opp(color), -beta, -a, ply + 1);
      if (st.stopped) return 0;
      if (s > a) a = s;
      if (a >= beta) break;
    }
    return a;
  }
  function searchRoot(b, color, depth) {
    const moves = orderedMoves(b, legalMoves(b, color));
    if (!moves.length) return null;
    let best = null, bestScore = -Infinity, alpha = -Infinity;
    for (const m of moves) {
      if (Date.now() > st.deadline) { st.stopped = true; return best; }
      const s = -negamax(applyMove(b, m), opp(color), depth - 1, -Infinity, Infinity, 1);
      if (st.stopped) return best;
      if (s > bestScore) { bestScore = s; best = m; }
      alpha = Math.max(alpha, s);
    }
    return best;
  }
  return { searchRoot, state: st };
}

/* 同步入口（测试用）。异步入口 bestMoveAsync 用 setTimeout 分层加深，避免一次卡死界面。 */
function bestMoveSync(b, color, diffKey) {
  const d = DIFFICULTY[diffKey] || DIFFICULTY.medium;
  const searcher = makeSearcher(d.timeLimit);
  let best = null;
  for (let depth = 1; depth <= d.depth; depth++) {
    if (Date.now() > searcher.state.deadline) break;
    const m = searcher.searchRoot(b, color, depth);
    if (m) best = m;
    if (searcher.state.stopped) break;
  }
  return best;
}
function bestMoveAsync(b, color, diffKey, onDone) {
  const d = DIFFICULTY[diffKey] || DIFFICULTY.medium;
  const searcher = makeSearcher(d.timeLimit);
  let best = null, depth = 1;
  const step = () => {
    if (depth > d.depth || Date.now() > searcher.state.deadline || searcher.state.stopped) { onDone(best); return; }
    const m = searcher.searchRoot(b, color, depth);
    if (m) best = m;
    depth++;
    setTimeout(step, 0);
  };
  setTimeout(step, 0);
}

/* ---------- 残局（红先行，将死黑将过关） ---------- */
const PUZZLES = [
  { title: '单车胜单士', desc: '红方一车一仕，对黑方单士。车占要道，逐步逼宫取胜。', hint: '先把车走到黑将同一线附近，限制士的活动，再进车将军。', maxMoves: 20, pieces: [
    { t: 'K', color: 'r', r: 9, col: 4 }, { t: 'A', color: 'r', r: 9, col: 3 }, { t: 'R', color: 'r', r: 6, col: 0 },
    { t: 'K', color: 'b', r: 0, col: 5 }, { t: 'A', color: 'b', r: 1, col: 3 } ] },
  { title: '马炮胜单士', desc: '马炮配合，马踩要害、炮架将军，单士难以兼顾。', hint: '马跳到士口附近控制宫心，炮在后方待机将军。', maxMoves: 20, pieces: [
    { t: 'K', color: 'r', r: 9, col: 4 }, { t: 'H', color: 'r', r: 7, col: 2 }, { t: 'C', color: 'r', r: 6, col: 4 },
    { t: 'K', color: 'b', r: 0, col: 4 }, { t: 'A', color: 'b', r: 1, col: 5 } ] },
  { title: '车马胜单车', desc: '红方车马联手，对黑方单车。注意别被黑车兑子。', hint: '用马保护车，车马轮流将军，黑车疲于应付。', maxMoves: 25, pieces: [
    { t: 'K', color: 'r', r: 9, col: 5 }, { t: 'A', color: 'r', r: 9, col: 3 }, { t: 'R', color: 'r', r: 7, col: 0 }, { t: 'H', color: 'r', r: 7, col: 1 },
    { t: 'K', color: 'b', r: 0, col: 3 }, { t: 'R', color: 'b', r: 1, col: 8 } ] },
  { title: '双炮胜单象', desc: '双炮隔子将军，单象守不住九宫。', hint: '双炮分占两线，一个当炮架、一个将军，轮流施压。', maxMoves: 20, pieces: [
    { t: 'K', color: 'r', r: 9, col: 3 }, { t: 'C', color: 'r', r: 5, col: 3 }, { t: 'C', color: 'r', r: 5, col: 5 },
    { t: 'K', color: 'b', r: 0, col: 4 }, { t: 'E', color: 'b', r: 2, col: 2 } ] },
  { title: '马兵胜单士', desc: '马兵联手，兵过河后与马配合，步步紧逼。', hint: '兵先过河占中，马在旁策应，士只能守一侧。', maxMoves: 25, pieces: [
    { t: 'K', color: 'r', r: 9, col: 4 }, { t: 'H', color: 'r', r: 8, col: 2 }, { t: 'P', color: 'r', r: 6, col: 4 },
    { t: 'K', color: 'b', r: 0, col: 4 }, { t: 'A', color: 'b', r: 2, col: 5 } ] },
  { title: '车炮胜双士', desc: '车炮重火力，双士守宫仍难挡车底线将军。', hint: '车沉底将军逼士离位，炮随后跟进。', maxMoves: 20, pieces: [
    { t: 'K', color: 'r', r: 9, col: 4 }, { t: 'R', color: 'r', r: 8, col: 8 }, { t: 'C', color: 'r', r: 7, col: 4 },
    { t: 'K', color: 'b', r: 0, col: 4 }, { t: 'A', color: 'b', r: 0, col: 3 }, { t: 'A', color: 'b', r: 0, col: 5 } ] },
  { title: '单车胜双象', desc: '单车对双象，车走长线调动双象，找机会捉死一象。', hint: '车先占中线，再横走捉象，双象顾此失彼。', maxMoves: 25, pieces: [
    { t: 'K', color: 'r', r: 9, col: 5 }, { t: 'R', color: 'r', r: 4, col: 0 },
    { t: 'K', color: 'b', r: 0, col: 3 }, { t: 'E', color: 'b', r: 2, col: 2 }, { t: 'E', color: 'b', r: 2, col: 6 } ] },
  { title: '双马胜单车', desc: '双马灵活跳跃，单车一子难防两马。', hint: '双马互相保护，轮流踩车、将军，黑车迟早被捉。', maxMoves: 25, pieces: [
    { t: 'K', color: 'r', r: 9, col: 4 }, { t: 'H', color: 'r', r: 7, col: 1 }, { t: 'H', color: 'r', r: 7, col: 7 },
    { t: 'K', color: 'b', r: 0, col: 5 }, { t: 'R', color: 'b', r: 2, col: 0 } ] }
];
function puzzleBoard(p) {
  const g = emptyBoard();
  for (const pc of p.pieces) g[pc.r][pc.col] = { t: pc.t, c: pc.color };
  return g;
}

/* ---------- 音频：WebAudio 程序合成，无音频文件 ---------- */
const AudioEngine = {
  ctx: null, bgmOn: false, sfxOn: true, bgmVol: 0.5, bgmTimer: null, bgmStep: 0, nextTime: 0,
  ensure() {
    if (!this.ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return false;
      this.ctx = new AC();
    }
    if (this.ctx.state === 'suspended') this.ctx.resume();
    return true;
  },
  tone(freq, dur, type, vol, when, slideTo) {
    if (!this.ensure()) return;
    const t0 = when || this.ctx.currentTime;
    const o = this.ctx.createOscillator(), g = this.ctx.createGain();
    o.type = type || 'sine'; o.frequency.setValueAtTime(freq, t0);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t0 + dur);
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(vol || 0.2, t0 + 0.015);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.connect(g); g.connect(this.ctx.destination);
    o.start(t0); o.stop(t0 + dur + 0.05);
  },
  playSelect() { if (this.sfxOn) this.tone(700, 0.06, 'triangle', 0.12); },
  playMove() { if (this.sfxOn) { this.tone(520, 0.09, 'triangle', 0.25, 0, 240); } },
  playCapture() { if (this.sfxOn) { this.tone(300, 0.16, 'square', 0.2, 0, 120); this.tone(180, 0.2, 'sine', 0.25); } },
  playCheck() { if (this.sfxOn) { this.tone(880, 0.12, 'sine', 0.22); this.tone(1174, 0.18, 'sine', 0.22, this.ctx ? this.ctx.currentTime + 0.12 : 0); } },
  playWin() { if (this.sfxOn) { [523, 659, 784, 1046].forEach((f, i) => this.tone(f, 0.25, 'sine', 0.2, this.ctx ? this.ctx.currentTime + i * 0.14 : 0)); } },
  playLose() { if (this.sfxOn) { [392, 330, 262, 196].forEach((f, i) => this.tone(f, 0.3, 'sine', 0.18, this.ctx ? this.ctx.currentTime + i * 0.16 : 0)); } },
  /* 古风五声音阶（宫商角徵羽）原创循环旋律，C 大调五声：C D E G A */
  MELODY: [
    [72, 1], [76, 1], [79, 1], [81, 2], [79, 1], [76, 1], [74, 2], [0, 1],
    [72, 1], [74, 1], [76, 2], [79, 1], [81, 1], [79, 2], [76, 2], [0, 1],
    [81, 1], [79, 1], [76, 1], [74, 2], [72, 2], [74, 1], [76, 1], [0, 1],
    [69, 2], [72, 1], [74, 1], [76, 2], [79, 2], [76, 1], [74, 2], [0, 2]
  ],
  midiToFreq(m) { return 440 * Math.pow(2, (m - 69) / 12); },
  startBgm() {
    if (!this.ensure() || this.bgmOn) return;
    this.bgmOn = true; this.bgmStep = 0; this.nextTime = this.ctx.currentTime + 0.1;
    this.bgmTimer = setInterval(() => this.scheduleBgm(), 400);
  },
  stopBgm() { this.bgmOn = false; if (this.bgmTimer) { clearInterval(this.bgmTimer); this.bgmTimer = null; } },
  scheduleBgm() {
    if (!this.bgmOn || !this.ctx) return;
    const beat = 0.42;
    while (this.nextTime < this.ctx.currentTime + 1.0) {
      const [midi, len] = this.MELODY[this.bgmStep % this.MELODY.length];
      if (midi) {
        const f = this.midiToFreq(midi);
        this.tone(f, beat * len * 0.95, 'sine', 0.10 * this.bgmVol + 0.02, this.nextTime);
        this.tone(f / 2, beat * len * 0.95, 'triangle', 0.05 * this.bgmVol + 0.01, this.nextTime);
      }
      this.nextTime += beat * len;
      this.bgmStep++;
    }
  }
};

/* ---------- 对局控制与界面（仅浏览器环境） ---------- */
const Game = {
  board: initialBoard(), turn: 'r', selected: null, targets: [],
  history: [], mode: 'ai', humanColor: 'r', difficulty: 'medium',
  aiThinking: false, aiToken: 0, puzzle: null, puzzleMoves: 0,
  over: false, statusText: '红方走棋', lastMove: null,
  positionCounts: {}, checks: { r: 0, b: 0 },
  replay: null // { game, index }
};
const SAVE_KEY = 'xiangqi.savedGames.v1';

function baseBoard() { return Game.puzzle ? puzzleBoard(Game.puzzle) : initialBoard(); }
function setStatus(t) { Game.statusText = t; const el = document.getElementById('status'); if (el) el.textContent = t; }

function rebuildFromHistory() {
  let b = baseBoard();
  const counts = {};
  counts[fingerprint(b)] = 1;
  for (const rec of Game.history) {
    b = applyMove(b, { fr: rec.from.r, fc: rec.from.c, tr: rec.to.r, tc: rec.to.c });
    const fp = fingerprint(b);
    counts[fp] = (counts[fp] || 0) + 1;
  }
  Game.board = b;
  Game.turn = Game.history.length % 2 === 0 ? 'r' : 'b';
  Game.positionCounts = counts;
  Game.lastMove = Game.history.length ? Game.history[Game.history.length - 1] : null;
}

function renderBoard() {
  const layer = document.getElementById('pieces');
  const dots = document.getElementById('dots');
  if (!layer) return;
  layer.innerHTML = ''; dots.innerHTML = '';
  for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
    const p = Game.board[r][c];
    if (!p) continue;
    const d = document.createElement('div');
    d.className = 'piece ' + (p.c === 'r' ? 'red' : 'black');
    d.textContent = NAMES[p.c][p.t];
    d.style.left = (c / 8 * 100) + '%';
    d.style.top = (r / 9 * 100) + '%';
    d.dataset.r = r; d.dataset.c = c;
    if (Game.selected && Game.selected.r === r && Game.selected.c === c) d.classList.add('selected');
    if (Game.lastMove && ((Game.lastMove.to.r === r && Game.lastMove.to.c === c) || (Game.lastMove.from.r === r && Game.lastMove.from.c === c))) d.classList.add('lastmove');
    layer.appendChild(d);
  }
  for (const t of Game.targets) {
    const dot = document.createElement('div');
    dot.className = 'dot' + (Game.board[t.r][t.c] ? ' capture' : '');
    dot.style.left = (t.c / 8 * 100) + '%';
    dot.style.top = (t.r / 9 * 100) + '%';
    dot.dataset.r = t.r; dot.dataset.c = t.c;
    dots.appendChild(dot);
  }
}
function renderMoves() {
  const ol = document.getElementById('movesList');
  if (!ol) return;
  ol.innerHTML = '';
  Game.history.forEach((rec, i) => {
    const li = document.createElement('li');
    li.textContent = (i + 1) + '. ' + (rec.color === 'r' ? '红 ' : '黑 ') + rec.notation;
    ol.appendChild(li);
  });
  ol.scrollTop = ol.scrollHeight;
}
function renderAll() { renderBoard(); renderMoves(); }

function afterMoveChecks(mover, move) {
  const next = opp(mover);
  if (move.isCheck) {
    Game.checks[mover]++;
    Game.checks[next] = 0;
    if (Game.checks[mover] >= 3) { endGame(mover === 'r' ? 'b' : 'r', (mover === 'r' ? '红方' : '黑方') + '长打判负'); return false; }
  } else { Game.checks = { r: 0, b: 0 }; }
  const fp = fingerprint(Game.board);
  Game.positionCounts[fp] = (Game.positionCounts[fp] || 0) + 1;
  if (Game.positionCounts[fp] >= 3) { endGame(null, '三次重复局面，和棋'); return false; }
  if (hasNoLegalMove(Game.board, next)) {
    const reason = isInCheck(Game.board, next) ? '将死' : '困毙';
    endGame(mover, reason);
    return false;
  }
  Game.turn = next;
  if (isInCheck(Game.board, next)) {
    setStatus((next === 'r' ? '红方' : '黑方') + '被将军！轮到' + (next === 'r' ? '红方' : '黑方') + '走棋');
    AudioEngine.playCheck();
  } else {
    setStatus('轮到' + (next === 'r' ? '红方' : '黑方') + '走棋');
  }
  return true;
}

function endGame(winner, reason) {
  Game.over = true;
  Game.aiToken++;
  if (Game.puzzle) {
    if (winner === 'r') { setStatus('🎉 残局破解！' + reason); AudioEngine.playWin(); }
    else { setStatus('残局失败：' + reason + '，再试一次吧'); AudioEngine.playLose(); }
    renderAll();
    return;
  }
  if (winner === null) { setStatus('和棋（' + reason + '）'); }
  else {
    setStatus((winner === 'r' ? '红方胜' : '黑方胜') + '（' + reason + '）');
    if (Game.mode === 'ai') { if (winner === Game.humanColor) AudioEngine.playWin(); else AudioEngine.playLose(); }
    else AudioEngine.playWin();
  }
  renderAll();
}

function doMove(from, to) {
  const piece = Game.board[from.r][from.c];
  if (!piece) return false;
  const legal = legalMoves(Game.board, Game.turn);
  const move = legal.find(m => m.fr === from.r && m.fc === from.c && m.tr === to.r && m.tc === to.c);
  if (!move) return false;
  const notation = chineseNotation(Game.board, move);
  const wasCapture = !!move.captured;
  Game.board = applyMove(Game.board, move);
  Game.history.push({ notation, from: { r: from.r, c: from.c }, to: { r: to.r, c: to.c }, color: piece.c });
  Game.lastMove = Game.history[Game.history.length - 1];
  Game.selected = null; Game.targets = [];
  if (wasCapture) AudioEngine.playCapture(); else AudioEngine.playMove();
  if (Game.puzzle && piece.c === 'r') {
    Game.puzzleMoves++;
    const pi = document.getElementById('puzzleInfo');
    if (pi) pi.textContent = '已走 ' + Game.puzzleMoves + ' 手 / 限 ' + Game.puzzle.maxMoves + ' 手';
    if (Game.puzzleMoves > Game.puzzle.maxMoves) { endGame('b', '超过限步'); renderAll(); return true; }
  }
  renderAll();
  if (!afterMoveChecks(piece.c, move)) return true;
  if (Game.puzzle) { puzzleBlackReply(); return true; }
  maybeTriggerAI();
  return true;
}

function maybeTriggerAI() {
  if (Game.mode !== 'ai' || Game.over || Game.turn === Game.humanColor) return;
  Game.aiThinking = true;
  setStatus('AI 思考中…（' + DIFFICULTY[Game.difficulty].title + '）');
  const token = Game.aiToken;
  const boardSnap = cloneBoard(Game.board), color = Game.turn;
  bestMoveAsync(boardSnap, color, Game.difficulty, m => {
    Game.aiThinking = false;
    if (token !== Game.aiToken || Game.over) return;
    if (!m) { endGame(opp(color), '对方无棋可走'); return; }
    doMove({ r: m.fr, c: m.fc }, { r: m.tr, c: m.tc });
  });
}
function puzzleBlackReply() {
  if (Game.over) return;
  Game.aiThinking = true;
  const token = Game.aiToken;
  const boardSnap = cloneBoard(Game.board);
  bestMoveAsync(boardSnap, 'b', 'easy', m => {
    Game.aiThinking = false;
    if (token !== Game.aiToken || Game.over) return;
    if (!m) { endGame('r', '将死'); return; }
    doMove({ r: m.fr, c: m.fc }, { r: m.tr, c: m.tc });
  });
}

function handleTap(r, c) {
  if (Game.over || Game.aiThinking || Game.replay) return;
  if (Game.mode === 'ai' && Game.turn !== Game.humanColor) return;
  if (Game.selected && Game.targets.some(t => t.r === r && t.c === c)) {
    doMove(Game.selected, { r, c });
    return;
  }
  const p = Game.board[r][c];
  if (p && p.c === Game.turn) {
    Game.selected = { r, c };
    Game.targets = legalMoves(Game.board, Game.turn)
      .filter(m => m.fr === r && m.fc === c)
      .map(m => ({ r: m.tr, c: m.tc }));
    AudioEngine.playSelect();
  } else { Game.selected = null; Game.targets = []; }
  renderBoard();
}

function newGame() {
  Game.aiToken++;
  Game.board = baseBoard();
  Game.turn = 'r'; Game.selected = null; Game.targets = [];
  Game.history = []; Game.lastMove = null; Game.aiThinking = false;
  Game.over = false; Game.puzzleMoves = 0; Game.replay = null;
  Game.positionCounts = {}; Game.positionCounts[fingerprint(Game.board)] = 1;
  Game.checks = { r: 0, b: 0 };
  setStatus(Game.puzzle ? '残局：' + Game.puzzle.title + '，红先行' : '红方走棋');
  const pi = document.getElementById('puzzleInfo');
  if (pi) pi.textContent = Game.puzzle ? Game.puzzle.desc + '（限 ' + Game.puzzle.maxMoves + ' 手）' : '';
  const rb = document.getElementById('replayBar');
  if (rb) rb.style.display = 'none';
  renderAll();
  if (Game.puzzle) return;
  if (Game.mode === 'ai' && Game.humanColor === 'b') maybeTriggerAI();
}
function undo() {
  if (Game.aiThinking || Game.replay) return;
  if (!Game.history.length) return;
  Game.aiToken++;
  Game.aiThinking = false;
  const steps = (Game.mode === 'ai' && !Game.puzzle && Game.history.length >= 2) ? 2 : 1;
  for (let i = 0; i < steps && Game.history.length; i++) {
    Game.history.pop();
    if (Game.puzzle) Game.puzzleMoves = Math.max(0, Game.puzzleMoves - 1);
  }
  Game.over = false;
  Game.selected = null; Game.targets = [];
  rebuildFromHistory();
  setStatus('轮到' + (Game.turn === 'r' ? '红方' : '黑方') + '走棋');
  renderAll();
}

/* ---------- 棋谱保存 / 复盘 ---------- */
function loadSaved() {
  try { return JSON.parse(localStorage.getItem(SAVE_KEY) || '[]'); } catch (e) { return []; }
}
function saveGame() {
  if (!Game.history.length) { setStatus('还没有走棋，无法保存'); return; }
  const games = loadSaved();
  const result = Game.over ? Game.statusText : '未完·' + Game.history.length + ' 手';
  games.unshift({
    id: Date.now(), date: new Date().toLocaleString('zh-CN'),
    title: '对局 ' + new Date().toLocaleString('zh-CN'),
    result, moves: Game.history, difficulty: DIFFICULTY[Game.difficulty].title
  });
  localStorage.setItem(SAVE_KEY, JSON.stringify(games.slice(0, 50)));
  renderSaved();
  setStatus('棋谱已保存（' + Game.history.length + ' 手）');
}
function renderSaved() {
  const ul = document.getElementById('savedList');
  if (!ul) return;
  const games = loadSaved();
  ul.innerHTML = '';
  if (!games.length) { ul.innerHTML = '<li class="empty">暂无保存的棋谱</li>'; return; }
  games.forEach(g => {
    const li = document.createElement('li');
    const b1 = document.createElement('button');
    b1.textContent = '▶ 复盘';
    b1.onclick = () => startReplay(g);
    const b2 = document.createElement('button');
    b2.textContent = '删除';
    b2.onclick = () => {
      localStorage.setItem(SAVE_KEY, JSON.stringify(loadSaved().filter(x => x.id !== g.id)));
      renderSaved();
    };
    const span = document.createElement('span');
    span.textContent = g.title + ' · ' + g.result + ' · ' + g.moves.length + ' 手 ';
    li.appendChild(span); li.appendChild(b1); li.appendChild(b2);
    ul.appendChild(li);
  });
}
function startReplay(g) {
  Game.aiToken++;
  Game.replay = { game: g, index: 0 };
  Game.puzzle = null;
  Game.history = [];
  Game.board = initialBoard();
  Game.over = true; // 复盘期间禁止走子
  Game.selected = null; Game.targets = [];
  const rb = document.getElementById('replayBar');
  if (rb) rb.style.display = 'flex';
  updateReplay();
}
function updateReplay() {
  const rp = Game.replay;
  if (!rp) return;
  let b = initialBoard();
  for (let i = 0; i < rp.index; i++) {
    const m = rp.game.moves[i];
    b = applyMove(b, { fr: m.from.r, fc: m.from.c, tr: m.to.r, tc: m.to.c });
  }
  Game.board = b;
  Game.history = rp.game.moves.slice(0, rp.index);
  Game.lastMove = Game.history.length ? Game.history[Game.history.length - 1] : null;
  setStatus('复盘：' + rp.game.title + '（' + rp.index + ' / ' + rp.game.moves.length + ' 手）');
  const ri = document.getElementById('replayInfo');
  if (ri) ri.textContent = rp.index + ' / ' + rp.game.moves.length + ' 手';
  renderAll();
}
function exportGame() {
  const lines = ['中国象棋棋谱', '结果：' + Game.statusText, '难度：' + DIFFICULTY[Game.difficulty].title, ''];
  Game.history.forEach((rec, i) => lines.push((i + 1) + '. ' + (rec.color === 'r' ? '红 ' : '黑 ') + rec.notation));
  const text = lines.join('\n');
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).then(() => setStatus('棋谱已复制到剪贴板'));
  } else {
    const ta = document.createElement('textarea');
    ta.value = text; document.body.appendChild(ta); ta.select();
    document.execCommand('copy'); document.body.removeChild(ta);
    setStatus('棋谱已复制到剪贴板');
  }
}

/* ---------- 残局 ---------- */
function renderPuzzles() {
  const ul = document.getElementById('puzzleList');
  if (!ul) return;
  ul.innerHTML = '';
  PUZZLES.forEach((p, i) => {
    const li = document.createElement('li');
    const b = document.createElement('button');
    b.textContent = (i + 1) + '. ' + p.title;
    b.onclick = () => startPuzzle(i);
    li.appendChild(b);
    ul.appendChild(li);
  });
}
function startPuzzle(i) {
  Game.puzzle = PUZZLES[i];
  Game.mode = 'ai';
  const ms = document.getElementById('modeSel');
  if (ms) ms.value = 'ai';
  newGame();
  setStatus('残局：' + Game.puzzle.title + '，红先行，限 ' + Game.puzzle.maxMoves + ' 手');
}

/* ---------- 初始化 ---------- */
function init() {
  const boardEl = document.getElementById('board');
  if (boardEl) {
    // 按点击坐标换算行列（棋子、落点、空格子都走同一条路）
    boardEl.addEventListener('click', e => {
      const layer = document.getElementById('dots');
      if (!layer) return;
      const rect = layer.getBoundingClientRect();
      const c = Math.round((e.clientX - rect.left) / rect.width * 8);
      const r = Math.round((e.clientY - rect.top) / rect.height * 9);
      if (r >= 0 && r < 10 && c >= 0 && c < 9) handleTap(r, c);
    });
  }
  const bind = (id, fn) => { const el = document.getElementById(id); if (el) el.addEventListener('click', fn); };
  bind('btnNew', () => { Game.puzzle = null; newGame(); });
  bind('btnUndo', undo);
  bind('btnSave', saveGame);
  bind('btnExport', exportGame);
  bind('btnHint', () => {
    if (Game.puzzle) setStatus('提示：' + Game.puzzle.hint);
    else setStatus('当前不是残局。去下方“残局”选一局试试。');
  });
  bind('btnExitPuzzle', () => { Game.puzzle = null; newGame(); });
  bind('btnReplayPrev', () => { if (Game.replay && Game.replay.index > 0) { Game.replay.index--; updateReplay(); } });
  bind('btnReplayNext', () => { if (Game.replay && Game.replay.index < Game.replay.game.moves.length) { Game.replay.index++; updateReplay(); } });
  bind('btnReplayExit', () => { Game.replay = null; Game.puzzle = null; newGame(); });
  const modeSel = document.getElementById('modeSel');
  if (modeSel) modeSel.addEventListener('change', () => { Game.mode = modeSel.value; Game.puzzle = null; newGame(); });
  const diffSel = document.getElementById('diffSel');
  if (diffSel) diffSel.addEventListener('change', () => { Game.difficulty = diffSel.value; });
  const colorSel = document.getElementById('colorSel');
  if (colorSel) colorSel.addEventListener('change', () => { Game.humanColor = colorSel.value; Game.puzzle = null; newGame(); });
  const sfx = document.getElementById('sfxToggle');
  if (sfx) sfx.addEventListener('change', () => { AudioEngine.sfxOn = sfx.checked; });
  const bgm = document.getElementById('bgmToggle');
  if (bgm) bgm.addEventListener('change', () => {
    AudioEngine.ensure();
    if (bgm.checked) AudioEngine.startBgm(); else AudioEngine.stopBgm();
  });
  const vol = document.getElementById('bgmVol');
  if (vol) vol.addEventListener('input', () => { AudioEngine.bgmVol = parseFloat(vol.value); });
  document.addEventListener('pointerdown', () => AudioEngine.ensure(), { once: true });
  Game.positionCounts[fingerprint(Game.board)] = 1;
  renderPuzzles();
  renderSaved();
  renderAll();
  setStatus('红方走棋');
}
if (typeof document !== 'undefined') {
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
}
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    initialBoard, emptyBoard, cloneBoard, applyMove, legalMoves, pseudoMoves,
    isInCheck, isAttacked, hasNoLegalMove, chineseNotation, evaluate,
    bestMoveSync, bestMoveAsync, DIFFICULTY, PUZZLES, puzzleBoard, fingerprint
  };
}
