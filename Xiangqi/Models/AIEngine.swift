import Foundation

// MARK: - 难度
enum Difficulty: String, CaseIterable, Codable {
    case easy, medium, master
    var title: String {
        switch self {
        case .easy: return "入门"
        case .medium: return "进阶"
        case .master: return "大师"
        }
    }
    var depth: Int {
        switch self {
        case .easy: return 2
        case .medium: return 3
        case .master: return 4
        }
    }
    /// 思考时间上限（秒），超时即停止加深
    var timeLimit: TimeInterval {
        switch self {
        case .easy: return 0.6
        case .medium: return 1.5
        case .master: return 3.0
        }
    }
    var description: String {
        switch self {
        case .easy: return "搜索深度 2，适合新手练手"
        case .medium: return "搜索深度 3，带杀棋搜索"
        case .master: return "搜索深度 4，迭代加深 + 杀棋搜索"
        }
    }
}

// MARK: - 位置分表（红方视角，行 0 在上；黑方使用镜像行）
// 数值单位约为“分”，卒过河后另有加分。
enum PST {
    static let chariot: [[Int]] = [
        [14,14,12,18,16,18,12,14,14],
        [16,20,18,24,26,24,18,20,16],
        [12,12,12,18,18,18,12,12,12],
        [12,18,16,22,22,22,16,18,12],
        [12,14,12,18,18,18,12,14,12],
        [12,16,14,20,20,20,14,16,12],
        [ 6,10, 8,14,14,14, 8,10, 6],
        [ 4, 8, 6,14,12,14, 6, 8, 4],
        [ 8, 4, 8,16, 8,16, 8, 4, 8],
        [ 6, 8, 6,16,12,16, 6, 8, 6],
    ]
    static let horse: [[Int]] = [
        [ 4, 8,16,12, 4,12,16, 8, 4],
        [ 4,10,28,16, 8,16,28,10, 4],
        [12,14,16,20,18,20,16,14,12],
        [ 8,24,18,24,20,24,18,24, 8],
        [ 6,16,14,18,16,18,14,16, 6],
        [ 4,12,16,14,12,14,16,12, 4],
        [ 4, 6,10, 6,10, 6,10, 6, 4],
        [ 2, 6, 8, 6, 8, 6, 8, 6, 2],
        [ 4, 2, 8, 8, 4, 8, 8, 2, 4],
        [ 0, 2, 4, 4,-2, 4, 4, 2, 0],
    ]
    static let cannon: [[Int]] = [
        [ 6, 4, 0,-10,-12,-10, 0, 4, 6],
        [ 2, 2, 0, -4, -6, -4, 0, 2, 2],
        [ 2, 2, 0, -4, -4, -4, 0, 2, 2],
        [ 0, 0, 0, -2, -4, -2, 0, 0, 0],
        [ 0, 0, 0, -2,  0, -2, 0, 0, 0],
        [-2, 0, 4,  0,  4,  0, 4, 0,-2],
        [ 0, 0, 0,  2,  4,  2, 0, 0, 0],
        [ 4, 0, 8,  0,  8,  0, 8, 0, 4],
        [ 0, 0, 0,  2,  4,  2, 0, 0, 0],
        [ 4, 0, 4,  0,  4,  0, 4, 0, 4],
    ]
    static let soldier: [[Int]] = [
        [ 0, 3, 6, 9,12, 9, 6, 3, 0],
        [18,36,36,36,36,36,36,36,18],
        [14,26,24,26,24,26,24,26,14],
        [ 8,24,20,24,20,24,20,24, 8],
        [ 6,20,16,20,16,20,16,20, 6],
        [ 2,10, 8,10, 8,10, 8,10, 2],
        [ 2, 6, 4, 6, 4, 6, 4, 6, 2],
        [ 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [ 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [ 0, 0, 0, 0, 0, 0, 0, 0, 0],
    ]
    static func table(for type: PieceType) -> [[Int]]? {
        switch type {
        case .chariot: return chariot
        case .horse: return horse
        case .cannon: return cannon
        case .soldier: return soldier
        default: return nil
        }
    }
}

// MARK: - AI 引擎：Negamax + Alpha-Beta + 迭代加深 + 杀棋（吃子）搜索
final class AIEngine {
    private var stopTime: Date = Date()
    private var nodes: Int = 0
    private var stopped: Bool = false

    /// 静态评估：从 color 视角看的局面分（正数有利）
    func evaluate(_ board: Board, for color: PieceColor) -> Int {
        var score = 0
        for r in 0..<10 { for c in 0..<9 {
            guard let p = board.grid[r][c] else { continue }
            var v = p.type.value
            if let table = PST.table(for: p.type) {
                // 红方直接查表；黑方镜像行（表是红方视角）
                let row = p.color == .red ? r : 9 - r
                v += table[row][c]
            }
            if p.type == .soldier {
                let crossed = p.color == .red ? r <= 4 : r >= 5
                if crossed { v += 30 }
            }
            score += (p.color == color) ? v : -v
        }}
        return score
    }

    /// 对外入口：在后台线程调用，返回最佳走法
    func bestMove(board: Board, color: PieceColor, difficulty: Difficulty) -> Move? {
        stopTime = Date().addingTimeInterval(difficulty.timeLimit)
        stopped = false
        nodes = 0
        var best: Move? = nil
        // 迭代加深：从 1 层加到目标深度，超时则保留上一层的结果
        for depth in 1...difficulty.depth {
            if Date() > stopTime { break }
            if let m = searchRoot(board: board, color: color, depth: depth) {
                best = m
            }
            if stopped { break }
        }
        return best
    }

    private func searchRoot(board: Board, color: PieceColor, depth: Int) -> Move? {
        let moves = orderedMoves(board.legalMoves(for: color), on: board)
        guard !moves.isEmpty else { return nil }
        var bestMove: Move? = nil
        var bestScore = Int.min
        var alpha = Int.min + 1
        for m in moves {
            let next = board.applying(m)
            let score = -negamax(board: next, color: color.opposite, depth: depth - 1, alpha: Int.min + 1, beta: Int.max, ply: 1)
            if stopped { return bestMove }
            if score > bestScore { bestScore = score; bestMove = m }
            alpha = max(alpha, score)
        }
        return bestMove
    }

    private func negamax(board: Board, color: PieceColor, depth: Int, alpha: Int, beta: Int, ply: Int) -> Int {
        nodes += 1
        if nodes % 2048 == 0, Date() > stopTime { stopped = true; return 0 }
        if stopped { return 0 }
        // 对方无合法走法 = 将死/困毙，越快将死越好
        let moves = board.legalMoves(for: color)
        if moves.isEmpty {
            // 己方被将死（或困毙）：负分，按层数折扣以偏好快胜
            return -100000 + ply * 10
        }
        if depth <= 0 {
            return quiescence(board: board, color: color, alpha: alpha, beta: beta, ply: ply)
        }
        var a = alpha
        var best = Int.min
        for m in orderedMoves(moves, on: board) {
            let next = board.applying(m)
            let score = -negamax(board: next, color: color.opposite, depth: depth - 1, alpha: -beta, beta: -a, ply: ply + 1)
            if stopped { return 0 }
            if score > best { best = score }
            if score > a { a = score }
            if a >= beta { break }
        }
        return best
    }

    /// 杀棋搜索：只看吃子走法，避免“地平线效应”
    private func quiescence(board: Board, color: PieceColor, alpha: Int, beta: Int, ply: Int) -> Int {
        let standPat = evaluate(board, for: color)
        if standPat >= beta { return beta }
        var a = max(alpha, standPat)
        if ply > 12 { return a }
        let captures = board.legalMoves(for: color).filter { $0.isCapture }
        for m in orderedMoves(captures, on: board) {
            let next = board.applying(m)
            let score = -quiescence(board: next, color: color.opposite, alpha: -beta, beta: -a, ply: ply + 1)
            if stopped { return 0 }
            if score > a { a = score }
            if a >= beta { break }
        }
        return a
    }

    /// 走法排序：吃子优先（MVV-LVA），将军其次
    private func orderedMoves(_ moves: [Move], on board: Board) -> [Move] {
        moves.sorted { a, b in score(of: a, on: board) > score(of: b, on: board) }
    }

    private func score(of move: Move, on board: Board) -> Int {
        var s = 0
        if let captured = move.captured, let mover = board.piece(at: move.from) {
            s += 1000 + captured.value - mover.type.value / 10
        }
        if move.isCheck { s += 500 }
        return s
    }
}
