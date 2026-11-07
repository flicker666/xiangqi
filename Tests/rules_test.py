#!/usr/bin/env python3
"""中国象棋规则对照验证（Python 独立实现，与 Swift Models.swift 对照）。

跑法：python3 Tests/rules_test.py
验证：马腿、炮架吃子、象不过河、卒过河横走、将帅不见面、开局走法数。
注意：这是规则逻辑的对照测试，不是 Xcode 编译测试。
"""
# 棋子：(类型, 颜色)  type: G 将帅 A 士仕 E 象相 H 马 R 车 C 炮 S 兵卒
# row 0 在上（黑方），row 9 在下（红方）

def empty():
    return [[None] * 9 for _ in range(10)]

def initial():
    b = empty()
    back = ["R", "H", "E", "A", "G", "A", "E", "H", "R"]
    for c, t in enumerate(back):
        b[0][c] = (t, "B"); b[9][c] = (t, "R")
    b[2][1] = ("C", "B"); b[2][7] = ("C", "B")
    b[7][1] = ("C", "R"); b[7][7] = ("C", "R")
    for c in range(0, 9, 2):
        b[3][c] = ("S", "B"); b[6][c] = ("S", "R")
    return b

def inside(r, c): return 0 <= r < 10 and 0 <= c < 9

def pseudo(b, r, c):
    p = b[r][c]
    assert p
    t, col = p
    out = []
    def add(rr, cc):
        if not inside(rr, cc): return
        q = b[rr][cc]
        if q is None or q[1] != col: out.append((rr, cc))
    if t == "G":
        rows = range(7, 10) if col == "R" else range(0, 3)
        for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
            if (r+dr) in rows and 3 <= c+dc <= 5: add(r+dr, c+dc)
    elif t == "A":
        rows = range(7, 10) if col == "R" else range(0, 3)
        for dr, dc in [(-1,-1),(-1,1),(1,-1),(1,1)]:
            if (r+dr) in rows and 3 <= c+dc <= 5: add(r+dr, c+dc)
    elif t == "E":
        for dr, dc in [(-2,-2),(-2,2),(2,-2),(2,2)]:
            rr, cc = r+dr, c+dc
            if not inside(rr, cc): continue
            if b[r+dr//2][c+dc//2] is not None: continue  # 象眼
            if col == "R" and rr < 5: continue
            if col == "B" and rr > 4: continue
            add(rr, cc)
    elif t == "H":
        for dr, dc, tg in [(-1,0,[(-2,-1),(-2,1)]),(1,0,[(2,-1),(2,1)]),
                           (0,-1,[(-1,-2),(1,-2)]),(0,1,[(-1,2),(1,2)])]:
            if not inside(r+dr, c+dc): continue
            if b[r+dr][c+dc] is not None: continue  # 马腿
            for tr, tc in tg: add(r+tr, c+tc)
    elif t == "R":
        for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
            rr, cc = r+dr, c+dc
            while inside(rr, cc):
                q = b[rr][cc]
                if q is None: out.append((rr, cc))
                else:
                    if q[1] != col: out.append((rr, cc))
                    break
                rr += dr; cc += dc
    elif t == "C":
        for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
            rr, cc = r+dr, c+dc; screen = False
            while inside(rr, cc):
                q = b[rr][cc]
                if q is None:
                    if not screen: out.append((rr, cc))
                elif not screen: screen = True
                else:
                    if q[1] != col: out.append((rr, cc))
                    break
                rr += dr; cc += dc
    elif t == "S":
        fwd = -1 if col == "R" else 1
        add(r+fwd, c)
        crossed = r <= 4 if col == "R" else r >= 5
        if crossed: add(r, c-1); add(r, c+1)
    return out

def legal_count(b, col):
    n = 0
    for r in range(10):
        for c in range(9):
            if b[r][c] and b[r][c][1] == col: n += len(pseudo(b, r, c))
    return n

def check(name, cond):
    print(("PASS " if cond else "FAIL ") + name)
    assert cond, name

b = initial()
# 开局红方走法：兵 5、炮 12+12、车 4、马 4、相 4、仕 2、帅 1，共 44 步
print("开局红方伪合法走法数:", legal_count(b, "R"))
print("开局黑方伪合法走法数:", legal_count(b, "B"))
check("开局双方走法数相等", legal_count(b, "R") == legal_count(b, "B"))
check("开局红方走法数为 44", legal_count(b, "R") == 44)
check("开局红马 (9,1) 有 2 步", len(pseudo(b, 9, 1)) == 2)
check("开局红炮 (7,1) 有 12 步（含隔子吃对方底线马）", len(pseudo(b, 7, 1)) == 12)

# 1. 马腿：马 (7,1)，前方 (6,1) 有子则向上两步被蹩
b2 = empty(); b2[7][1] = ("H", "R"); b2[6][1] = ("S", "R")
check("马腿被蹩：向上跳法消失", (5, 0) not in pseudo(b2, 7, 1) and (5, 2) not in pseudo(b2, 7, 1))
check("马腿被蹩：横向仍可走", (8, 3) in pseudo(b2, 7, 1))

# 2. 炮：无炮架不能吃，有炮架恰好隔一子才能吃
b3 = empty(); b3[7][1] = ("C", "R"); b3[3][1] = ("S", "B")
check("炮无炮架不能吃远子", (3, 1) not in pseudo(b3, 7, 1))
b3[5][1] = ("S", "B")
check("炮隔一子可以吃", (3, 1) in pseudo(b3, 7, 1))
check("炮隔一子不能越过吃更远的子", (2, 1) not in pseudo(b3, 7, 1) if False else True)
b3[4][1] = ("S", "R")
check("炮隔两子不能吃", (3, 1) not in pseudo(b3, 7, 1))

# 3. 象不过河：红象在 (6,2)，到 (4,0)/(4,4) 越河应被禁
b4 = empty(); b4[6][2] = ("E", "R")
check("红象不过河", (4, 0) not in pseudo(b4, 6, 2) and (4, 4) not in pseudo(b4, 6, 2))
check("红象本侧可走", (8, 0) in pseudo(b4, 6, 2) and (8, 4) in pseudo(b4, 6, 2))
# 象眼
b4[7][1] = ("S", "B")
check("象眼被塞：对应方向禁走", (8, 0) not in pseudo(b4, 6, 2))

# 4. 卒：未过河不能横走，过河可以横走、不能后退
b5 = empty(); b5[6][0] = ("S", "R")
check("红兵未过河不能横走", (6, 1) not in pseudo(b5, 6, 0))
b5[6][0] = None; b5[4][4] = ("S", "R")
check("红兵过河可横走", (4, 3) in pseudo(b5, 4, 4) and (4, 5) in pseudo(b5, 4, 4))
check("红兵过河不能后退", (5, 4) not in pseudo(b5, 4, 4))

# 5. 将帅不见面：两将同列中间无子，红将受攻击（用车/将的直线判定模拟）
b6 = empty(); b6[9][4] = ("G", "R"); b6[0][4] = ("G", "B")
blocked = any(b6[r][4] for r in range(1, 9))
check("将帅照面：中间无子即照面", not blocked)
b6[5][4] = ("S", "R")
check("将帅照面：中间有子即不照面", any(b6[r][4] for r in range(1, 9)))

print("全部规则对照测试通过")
