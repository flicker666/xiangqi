'use strict';
const X = require('./xiangqi.js');
let pass = 0, fail = 0;
function check(name, cond) {
  if (cond) { pass++; console.log('PASS', name); }
  else { fail++; console.log('FAIL', name); }
}
function movesFrom(b, color, r, c) {
  return X.legalMoves(b, color).filter(m => m.fr === r && m.fc === c);
}
/* 测试局面都要避免将帅照面（非法局面），所以在 4 路放一个挡子 */
function boardWithBlocker() {
  const b = X.emptyBoard();
  b[9][4] = { t: 'K', c: 'r' }; b[0][4] = { t: 'K', c: 'b' };
  b[4][4] = { t: 'P', c: 'b' }; // 挡住将帅照面
  return b;
}
// 开局走法数：双方各 44
check('开局红方 44 步', X.legalMoves(X.initialBoard(), 'r').length === 44);
check('开局黑方 44 步', X.legalMoves(X.initialBoard(), 'b').length === 44);
// 马腿：红马 (9,1) 在角上可走 3 步（(7,0)(7,2)(8,3)）；蹩住向上马腿剩 1 步
{
  const b = boardWithBlocker();
  b[9][1] = { t: 'H', c: 'r' };
  check('马无蹩腿可走 3 步', movesFrom(b, 'r', 9, 1).length === 3);
  b[8][1] = { t: 'P', c: 'r' }; // 蹩住向上马腿
  check('马腿被蹩后剩 1 步', movesFrom(b, 'r', 9, 1).length === 1);
}
// 炮：无炮架不能吃，隔一子能吃，隔两子不能吃
{
  const b = boardWithBlocker();
  b[9][0] = { t: 'C', c: 'r' };
  b[5][0] = { t: 'P', c: 'b' };
  let ms = movesFrom(b, 'r', 9, 0);
  check('炮无炮架不能吃远子', !ms.some(m => m.tr === 5 && m.tc === 0));
  b[7][0] = { t: 'P', c: 'r' }; // 炮架
  ms = movesFrom(b, 'r', 9, 0);
  check('炮隔一子能吃', ms.some(m => m.tr === 5 && m.tc === 0 && m.captured === 'P'));
  b[6][0] = { t: 'P', c: 'b' }; // 第二个子挡住
  ms = movesFrom(b, 'r', 9, 0);
  check('炮隔两子不能吃', !ms.some(m => m.tr === 5 && m.tc === 0));
}
// 象：不过河、象眼
{
  const b = boardWithBlocker();
  b[9][2] = { t: 'E', c: 'r' };
  let ms = movesFrom(b, 'r', 9, 2);
  check('相能走 2 步（不过河）', ms.length === 2 && ms.every(m => m.tr >= 5));
  b[8][3] = { t: 'P', c: 'r' }; // 塞象眼
  ms = movesFrom(b, 'r', 9, 2);
  check('象眼被塞剩 1 步', ms.length === 1);
}
// 兵：未过河不能横走、不能后退；过河能横走
{
  const b = boardWithBlocker();
  b[6][4] = { t: 'P', c: 'r' };
  let ms = movesFrom(b, 'r', 6, 4);
  check('兵未过河只能前进', ms.length === 1 && ms[0].tr === 5);
  const b2 = X.emptyBoard();
  b2[9][4] = { t: 'K', c: 'r' }; b2[0][4] = { t: 'K', c: 'b' };
  b2[2][4] = { t: 'P', c: 'b' }; // 挡将帅照面（与过河兵不在同格）
  b2[4][4] = { t: 'P', c: 'r' };
  ms = movesFrom(b2, 'r', 4, 4);
  check('兵过河可横走共 3 步', ms.length === 3);
}
// 将帅照面：中间无子时，走开挡子不合法
{
  const b = X.emptyBoard();
  b[9][4] = { t: 'K', c: 'r' }; b[0][4] = { t: 'K', c: 'b' };
  b[5][4] = { t: 'R', c: 'r' }; // 红车挡在中间
  const ms = movesFrom(b, 'r', 5, 4);
  check('挡将帅照面的车不能横走', ms.length > 0 && ms.every(m => m.tc === 4));
  check('红方未被将军（有车挡着）', X.isInCheck(b, 'r') === false);
  check('黑将被红车照面攻击', X.isAttacked(b, 0, 4, 'r') === true);
}
// 将死判定：三车围将，黑将无路可逃
{
  const b = X.emptyBoard();
  b[9][4] = { t: 'K', c: 'r' };
  b[0][4] = { t: 'K', c: 'b' };
  b[1][4] = { t: 'R', c: 'r' };
  b[2][3] = { t: 'R', c: 'r' };
  b[1][5] = { t: 'R', c: 'r' };
  check('黑方被将军', X.isInCheck(b, 'b') === true);
  check('黑方无合法走法（将死）', X.hasNoLegalMove(b, 'b') === true);
}
// 中文着法
{
  const b = X.initialBoard();
  const n = X.chineseNotation(b, { fr: 7, fc: 1, tr: 7, tc: 4 });
  check('着法 炮八平五 = ' + n, n === '炮八平五');
  const n3 = X.chineseNotation(b, { fr: 7, fc: 7, tr: 7, tc: 4 });
  check('着法 炮二平五 = ' + n3, n3 === '炮二平五');
  const n2 = X.chineseNotation(b, { fr: 6, fc: 0, tr: 5, tc: 0 });
  check('着法 兵九进一 = ' + n2, n2 === '兵九进一');
}
// AI：开局能走出合法步
{
  const b = X.initialBoard();
  const m = X.bestMoveSync(b, 'b', 'easy');
  const legal = X.legalMoves(b, 'b');
  check('AI 入门能出合法步', !!m && legal.some(x => x.fr === m.fr && x.fc === m.fc && x.tr === m.tr && x.tc === m.tc));
  const m2 = X.bestMoveSync(b, 'r', 'medium');
  check('AI 进技能出合法步', !!m2 && X.legalMoves(b, 'r').some(x => x.fr === m2.fr && x.fc === m2.fc && x.tr === m2.tr && x.tc === m2.tc));
}
// 残局数据：8 个，红先行都有合法步，且开局不被将军
check('残局 8 个', X.PUZZLES.length === 8);
X.PUZZLES.forEach((p, i) => {
  const b = X.puzzleBoard(p);
  const redMoves = X.legalMoves(b, 'r').length;
  check('残局' + (i + 1) + ' ' + p.title + ' 红方有合法步(' + redMoves + ') 且未被将军', redMoves > 0 && !X.isInCheck(b, 'r'));
});
console.log('\n' + pass + ' passed, ' + fail + ' failed');
process.exit(fail ? 1 : 0);
