import Foundation

// MARK: - 棋子类型与颜色
enum PieceColor: String, Codable, CaseIterable {
    case red, black
    var isRed: Bool { self == .red }
    var opposite: PieceColor { self == .red ? .black : .red }
    /// 红方用汉字数字，黑方用阿拉伯数字（传统记谱）
    func fileName(for col: Int) -> String {
        if self == .red {
            return ["九","八","七","六","五","四","三","二","一"][col]
        } else {
            return "\(col + 1)"
        }
    }
}

enum PieceType: String, Codable, CaseIterable {
    case general, advisor, elephant, horse, chariot, cannon, soldier
    var redName: String {
        switch self {
        case .general: return "帅"
        case .advisor: return "仕"
        case .elephant: return "相"
        case .horse: return "马"
        case .chariot: return "车"
        case .cannon: return "炮"
        case .soldier: return "兵"
        }
    }
    var blackName: String {
        switch self {
        case .general: return "将"
        case .advisor: return "士"
        case .elephant: return "象"
        case .horse: return "马"
        case .chariot: return "车"
        case .cannon: return "炮"
        case .soldier: return "卒"
        }
    }
    func name(for color: PieceColor) -> String { color == .red ? redName : blackName }
    /// 基础子力（用于评估与记谱）
    var value: Int {
        switch self {
        case .general: return 10000
        case .chariot: return 600
        case .cannon: return 300
        case .horse: return 270
        case .advisor: return 120
        case .elephant: return 120
        case .soldier: return 60
        }
    }
}

struct Piece: Equatable, Codable {
    let type: PieceType
    let color: PieceColor
    var name: String { type.name(for: color) }
}

/// 棋盘坐标：row 0 为顶行（黑方底线），row 9 为底行（红方底线）；col 0-8 从左到右
struct Pos: Equatable, Hashable, Codable {
    let row: Int
    let col: Int
    var isValid: Bool { row >= 0 && row < 10 && col >= 0 && col < 9 }
    /// 红方视角的列号（用于记谱）：红从右往左数
    func fileString(for color: PieceColor) -> String { color.fileName(for: col) }
}

struct Move: Equatable, Hashable, Codable {
    let from: Pos
    let to: Pos
    var captured: PieceType? = nil
    var isCheck: Bool = false
    var isCapture: Bool { captured != nil }
}

// MARK: - 棋盘
struct Board: Equatable {
    /// grid[row][col]，row 0 在上（黑方），row 9 在下（红方）
    var grid: [[Piece?]] = Array(repeating: Array(repeating: nil, count: 9), count: 10)

    init() { setupInitial() }

    init(grid: [[Piece?]]) { self.grid = grid }

    mutating func setupInitial() {
        grid = Array(repeating: Array(repeating: nil, count: 9), count: 10)
        let back: [PieceType] = [.chariot, .horse, .elephant, .advisor, .general, .advisor, .elephant, .horse, .chariot]
        for col in 0..<9 {
            grid[0][col] = Piece(type: back[col], color: .black)
            grid[9][col] = Piece(type: back[col], color: .red)
        }
        grid[2][1] = Piece(type: .cannon, color: .black)
        grid[2][7] = Piece(type: .cannon, color: .black)
        grid[7][1] = Piece(type: .cannon, color: .red)
        grid[7][7] = Piece(type: .cannon, color: .red)
        for col in stride(from: 0, through: 8, by: 2) {
            grid[3][col] = Piece(type: .soldier, color: .black)
            grid[6][col] = Piece(type: .soldier, color: .red)
        }
    }

    func piece(at pos: Pos) -> Piece? {
        guard pos.isValid else { return nil }
        return grid[pos.row][pos.col]
    }

    func generalPos(of color: PieceColor) -> Pos? {
        for r in 0..<10 { for c in 0..<9 {
            if let p = grid[r][c], p.type == .general, p.color == color { return Pos(row: r, col: c) }
        }}
        return nil
    }

    /// 执行一步（不做合法性检查，调用方保证合法）
    func applying(_ move: Move) -> Board {
        var b = self
        let p = b.grid[move.from.row][move.from.col]
        b.grid[move.from.row][move.from.col] = nil
        b.grid[move.to.row][move.to.col] = p
        return b
    }

    /// 位置指纹（用于重复局面检测）
    func fingerprint() -> String {
        var s = ""
        for r in 0..<10 { for c in 0..<9 {
            if let p = grid[r][c] {
                s += "\(r)\(c)\(p.color == .red ? "R" : "B")\(p.type.rawValue.prefix(2))"
            }
        }}
        return s
    }

    // MARK: 走法生成
    /// 某一方所有伪合法走法（不含“走完后己方被将”的过滤）
    func pseudoMoves(for color: PieceColor) -> [Move] {
        var moves: [Move] = []
        for r in 0..<10 { for c in 0..<9 {
            guard let p = grid[r][c], p.color == color else { continue }
            let from = Pos(row: r, col: c)
            moves += pseudoMovesForPiece(p, at: from)
        }}
        return moves
    }

    func pseudoMovesForPiece(_ piece: Piece, at from: Pos) -> [Move] {
        var out: [Move] = []
        func add(_ to: Pos) {
            guard to.isValid else { return }
            if let t = piece(at: to) {
                if t.color != piece.color { out.append(Move(from: from, to: to, captured: t.type)) }
            } else {
                out.append(Move(from: from, to: to))
            }
        }
        func slide(_ dr: Int, _ dc: Int, captureNeedsScreen: Bool) {
            var r = from.row + dr, c = from.col + dc
            var screens = 0
            while r >= 0 && r < 10 && c >= 0 && c < 9 {
                let pos = Pos(row: r, col: c)
                if let t = piece(at: pos) {
                    if captureNeedsScreen {
                        if screens == 1 && t.color != piece.color {
                            out.append(Move(from: from, to: pos, captured: t.type))
                        }
                        break
                    } else {
                        if t.color != piece.color { out.append(Move(from: from, to: pos, captured: t.type)) }
                        break
                    }
                } else {
                    if captureNeedsScreen {
                        if screens == 0 { out.append(Move(from: from, to: pos)) }
                    } else {
                        out.append(Move(from: from, to: pos))
                    }
                }
                // 炮：遇到第一个子为炮架，继续找吃子目标
                if captureNeedsScreen, piece(at: pos) != nil { screens += 1 }
                r += dr; c += dc
            }
        }
        // 注意：上面 slide 对炮的炮架计数用 piece(at:) 在空格时为 nil；
        // 为避免歧义，炮的走法用下方专用实现重新计算（见 cannonMoves）。
        switch piece.type {
        case .general:
            let rows = piece.color == .red ? 7...9 : 0...2
            for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)] {
                let to = Pos(row: from.row + dr, col: from.col + dc)
                if rows.contains(to.row) && (3...5).contains(to.col) { add(to) }
            }
        case .advisor:
            for (dr, dc) in [(-1,-1),(-1,1),(1,-1),(1,1)] {
                let to = Pos(row: from.row + dr, col: from.col + dc)
                let rows = piece.color == .red ? 7...9 : 0...2
                if rows.contains(to.row) && (3...5).contains(to.col) { add(to) }
            }
        case .elephant:
            for (dr, dc) in [(-2,-2),(-2,2),(2,-2),(2,2)] {
                let to = Pos(row: from.row + dr, col: from.col + dc)
                guard to.isValid else { continue }
                // 象眼
                let eye = Pos(row: from.row + dr/2, col: from.col + dc/2)
                if piece(at: eye) != nil { continue }
                // 象不过河
                if piece.color == .red && to.row < 5 { continue }
                if piece.color == .black && to.row > 4 { continue }
                add(to)
            }
        case .horse:
            // 马腿：横/竖方向第一格有子则蹩马腿
            let legs: [(dr: Int, dc: Int, targets: [(Int, Int)])] = [
                (-1, 0, [(-2,-1),(-2,1)]),
                ( 1, 0, [( 2,-1),( 2,1)]),
                ( 0,-1, [(-1,-2),( 1,-2)]),
                ( 0, 1, [(-1, 2),( 1, 2)])
            ]
            for leg in legs {
                let legPos = Pos(row: from.row + leg.dr, col: from.col + leg.dc)
                if piece(at: legPos) != nil { continue }
                for t in leg.targets { add(Pos(row: from.row + t.0, col: from.col + t.1)) }
            }
        case .chariot:
            for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)] { slide(dr, dc, captureNeedsScreen: false) }
        case .cannon:
            out += cannonMoves(from: from, piece: piece)
        case .soldier:
            let fwd = piece.color == .red ? -1 : 1
            add(Pos(row: from.row + fwd, col: from.col))
            let crossed = piece.color == .red ? from.row <= 4 : from.row >= 5
            if crossed {
                add(Pos(row: from.row, col: from.col - 1))
                add(Pos(row: from.row, col: from.col + 1))
            }
        }
        return out
    }

    /// 炮的走法：不吃子时沿直线走到空格；吃子时中间恰好隔一个子
    private func cannonMoves(from: Pos, piece: Piece) -> [Move] {
        var out: [Move] = []
        for (dr, dc) in [(-1,0),(1,0),(0,-1),(0,1)] {
            var r = from.row + dr, c = from.col + dc
            var screenFound = false
            while r >= 0 && r < 10 && c >= 0 && c < 9 {
                let pos = Pos(row: r, col: c)
                if let t = piece(at: pos) {
                    if !screenFound {
                        screenFound = true
                    } else {
                        if t.color != piece.color { out.append(Move(from: from, to: pos, captured: t.type)) }
                        break
                    }
                } else if !screenFound {
                    out.append(Move(from: from, to: pos))
                }
                r += dr; c += dc
            }
        }
        return out
    }

    // MARK: 将军判定
    /// pos 是否被 color 一方攻击（含将帅照面）
    func isAttacked(_ pos: Pos, by color: PieceColor) -> Bool {
        // 将帅照面：对方将在同一列且中间无子
        if let opp = generalPos(of: color), opp.col == pos.col {
            var blocked = false
            for r in min(opp.row, pos.row)+1..<max(opp.row, pos.row) {
                if grid[r][pos.col] != nil { blocked = true; break }
            }
            if !blocked { return true }
        }
        // 其余子力：用伪走法反推（炮/马等已含蹩腿、炮架规则）
        for m in pseudoMoves(for: color) where m.to == pos { return true }
        return false
    }

    func isInCheck(_ color: PieceColor) -> Bool {
        guard let g = generalPos(of: color) else { return false }
        return isAttacked(g, by: color.opposite)
    }

    /// 真正合法走法：走完后己方将不在被将军状态
    func legalMoves(for color: PieceColor) -> [Move] {
        pseudoMoves(for: color).compactMap { m in
            let next = applying(m)
            // 吃掉对方将：不允许直接吃将，判为将死由调用方处理；
            // 这里把“吃将”排除（规则上将死发生在将军无应着时）
            if next.generalPos(of: color.opposite) == nil { return nil }
            if next.isInCheck(color) { return nil }
            var move = m
            move.isCheck = next.isInCheck(color.opposite)
            return move
        }
    }

    /// 某方是否已被将死或困毙（无合法走法）
    func hasNoLegalMove(_ color: PieceColor) -> Bool { legalMoves(for: color).isEmpty }

    func materialScore(for color: PieceColor) -> Int {
        var s = 0
        for r in 0..<10 { for c in 0..<9 {
            if let p = grid[r][c], p.color == color { s += p.type.value }
        }}
        return s
    }
}

// MARK: - 中文着法
enum Notation {
    static func chinese(for move: Move, on board: Board) -> String {
        guard let piece = board.piece(at: move.from) else { return "?" }
        let color = piece.color
        let fromFile = color.fileName(for: move.from.col)
        let toFile = color.fileName(for: move.to.col)
        // 同列同种棋子：前/后区分
        var prefix = ""
        var sameFile: [Pos] = []
        for r in 0..<10 {
            let pos = Pos(row: r, col: move.from.col)
            if let p = board.piece(at: pos), p.type == piece.type, p.color == color { sameFile.append(pos) }
        }
        if sameFile.count > 1 {
            // 红方在前者行号大，黑方在前者行号小
            let sorted = sameFile.sorted { color == .red ? $0.row > $1.row : $0.row < $1.row }
            prefix = (sorted.first == move.from) ? "前" : "后"
        }
        let name = piece.name
        if move.from.col == move.to.col {
            // 纵向：进/退 + 格数
            let steps = abs(move.to.row - move.from.row)
            let dir: String
            if color == .red { dir = move.to.row < move.from.row ? "进" : "退" }
            else { dir = move.to.row > move.from.row ? "进" : "退" }
            let num = color == .red ? ["一","二","三","四","五","六","七","八","九"][steps - 1] : "\(steps)"
            return "\(prefix)\(name)\(fromFile)\(dir)\(num)"
        } else {
            // 横向：平 + 目标列
            return "\(prefix)\(name)\(fromFile)平\(toFile)"
        }
    }
}
