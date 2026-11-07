import Foundation
import SwiftUI

// MARK: - 对局记录
struct MoveRecord: Codable, Identifiable {
    var id = UUID()
    let index: Int
    let notation: String
    let from: Pos
    let to: Pos
    let color: PieceColor
}

struct SavedGame: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let title: String
    let result: String
    let moves: [MoveRecord]
    let difficulty: String

    var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}

final class GameStore: ObservableObject {
    @Published private(set) var savedGames: [SavedGame] = []
    private let key = "xiangqi.savedGames.v1"

    init() { load() }

    func save(game: SavedGame) {
        savedGames.insert(game, at: 0)
        persist()
    }

    func delete(at offsets: IndexSet) {
        savedGames.remove(atOffsets: offsets)
        persist()
    }

    func delete(_ game: SavedGame) {
        savedGames.removeAll { $0.id == game.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(savedGames) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let games = try? JSONDecoder().decode([SavedGame].self, from: data) else { return }
        savedGames = games
    }
}

// MARK: - 残局
struct PuzzlePiece: Codable {
    let type: PieceType
    let color: PieceColor
    let row: Int
    let col: Int
}

struct Puzzle: Identifiable, Codable {
    var id = UUID()
    let title: String
    let description: String
    let hint: String
    let pieces: [PuzzlePiece]
    let maxMoves: Int

    func initialBoard() -> Board {
        var grid = Array(repeating: Array(repeating: nil as Piece?, count: 9), count: 10)
        for p in pieces {
            grid[p.row][p.col] = Piece(type: p.type, color: p.color)
        }
        return Board(grid: grid)
    }
}

enum Puzzles {
    static let all: [Puzzle] = [
        Puzzle(title: "单车胜单士", description: "红方一车一仕，对黑方单士。车占要道，逐步逼宫取胜。", hint: "先把车走到黑将同一线附近，限制士的活动，再进车将军。", pieces: [
            PuzzlePiece(type: .general, color: .red, row: 9, col: 4),
            PuzzlePiece(type: .advisor, color: .red, row: 9, col: 3),
            PuzzlePiece(type: .chariot, color: .red, row: 6, col: 0),
            PuzzlePiece(type: .general, color: .black, row: 0, col: 4),
            PuzzlePiece(type: .advisor, color: .black, row: 1, col: 3),
        ], maxMoves: 20),
        Puzzle(title: "马炮胜单士", description: "马炮配合，马踩要害、炮架将军，单士难以兼顾。", hint: "马跳到士口附近控制宫心，炮在后方待机将军。", pieces: [
            PuzzlePiece(type: .general, color: .red, row: 9, col: 4),
            PuzzlePiece(type: .horse, color: .red, row: 7, col: 2),
            PuzzlePiece(type: .cannon, color: .red, row: 6, col: 4),
            PuzzlePiece(type: .general, color: .black, row: 0, col: 4),
            PuzzlePiece(type: .advisor, color: .black, row: 1, col: 5),
        ], maxMoves: 20),
        Puzzle(title: "车马胜单车", description: "红方车马联手，对黑方单车。注意别被黑车兑子。", hint: "用马保护车，车马轮流将军，黑车疲于应付。", pieces: [
            PuzzlePiece(type: .general, color: .red, row: 9, col: 5),
            PuzzlePiece(type: .advisor, color: .red, row: 9, col: 3),
            PuzzlePiece(type: .chariot, color: .red, row: 7, col: 0),
            PuzzlePiece(type: .horse, color: .red, row: 7, col: 1),
            PuzzlePiece(type: .general, color: .black, row: 0, col: 3),
            PuzzlePiece(type: .chariot, color: .black, row: 1, col: 8),
        ], maxMoves: 25),
        Puzzle(title: "双炮胜单象", description: "双炮隔子将军，单象守不住九宫。", hint: "双炮分占两线，一个当炮架、一个将军，轮流施压。", pieces: [
            PuzzlePiece(type: .general, color: .red, row: 9, col: 3),
            PuzzlePiece(type: .cannon, color: .red, row: 5, col: 3),
            PuzzlePiece(type: .cannon, color: .red, row: 5, col: 5),
            PuzzlePiece(type: .general, color: .black, row: 0, col: 4),
            PuzzlePiece(type: .elephant, color: .black, row: 2, col: 2),
        ], maxMoves: 20),
        Puzzle(title: "马兵胜单士", description: "马兵联手，兵过河后与马配合，步步紧逼。", hint: "兵先过河占中，马在旁策应，士只能守一侧。", pieces: [
            PuzzlePiece(type: .general, color: .red, row: 9, col: 4),
            PuzzlePiece(type: .horse, color: .red, row: 8, col: 2),
            PuzzlePiece(type: .soldier, color: .red, row: 6, col: 4),
            PuzzlePiece(type: .general, color: .black, row: 0, col: 4),
            PuzzlePiece(type: .advisor, color: .black, row: 2, col: 5),
        ], maxMoves: 25),
        Puzzle(title: "车炮胜双士", description: "车炮重火力，双士守宫仍难挡车底线将军。", hint: "车沉底将军逼士离位，炮随后跟进。", pieces: [
            PuzzlePiece(type: .general, color: .red, row: 9, col: 4),
            PuzzlePiece(type: .chariot, color: .red, row: 8, col: 8),
            PuzzlePiece(type: .cannon, color: .red, row: 7, col: 4),
            PuzzlePiece(type: .general, color: .black, row: 0, col: 4),
            PuzzlePiece(type: .advisor, color: .black, row: 0, col: 3),
            PuzzlePiece(type: .advisor, color: .black, row: 0, col: 5),
        ], maxMoves: 20),
        Puzzle(title: "单车胜双象", description: "单车对双象，车走长线调动双象，找机会捉死一象。", hint: "车先占中线，再横走捉象，双象顾此失彼。", pieces: [
            PuzzlePiece(type: .general, color: .red, row: 9, col: 5),
            PuzzlePiece(type: .chariot, color: .red, row: 4, col: 0),
            PuzzlePiece(type: .general, color: .black, row: 0, col: 3),
            PuzzlePiece(type: .elephant, color: .black, row: 2, col: 2),
            PuzzlePiece(type: .elephant, color: .black, row: 2, col: 6),
        ], maxMoves: 25),
        Puzzle(title: "双马胜单车", description: "双马灵活跳跃，单车一子难防两马。", hint: "双马互相保护，轮流踩车、将军，黑车迟早被捉。", pieces: [
            PuzzlePiece(type: .general, color: .red, row: 9, col: 4),
            PuzzlePiece(type: .horse, color: .red, row: 7, col: 1),
            PuzzlePiece(type: .horse, color: .red, row: 7, col: 7),
            PuzzlePiece(type: .general, color: .black, row: 0, col: 4),
            PuzzlePiece(type: .chariot, color: .black, row: 2, col: 0),
        ], maxMoves: 25),
    ]
}

// MARK: - 对局状态
enum GameStatus: Equatable {
    case playing
    case check(color: PieceColor) // 该方被将军
    case won(winner: PieceColor, reason: String)
    case draw(reason: String)

    var text: String {
        switch self {
        case .playing: return "对局进行中"
        case .check(let c): return c == .red ? "红方被将军" : "黑方被将军"
        case .won(let w, let r): return (w == .red ? "红方胜" : "黑方胜") + "（\(r)）"
        case .draw(let r): return "和棋（\(r)）"
        }
    }
}

final class GameViewModel: ObservableObject {
    @Published var board = Board()
    @Published var turn: PieceColor = .red
    @Published var selected: Pos?
    @Published var legalTargets: [Pos] = []
    @Published var history: [MoveRecord] = []
    @Published var status: GameStatus = .playing
    @Published var difficulty: Difficulty = .medium
    @Published var aiEnabled: Bool = true
    @Published var humanColor: PieceColor = .red
    @Published var isAIThinking: Bool = false
    @Published var lastMove: Move?
    @Published var moveCount: Int = 0

    private let ai = AIEngine()
    private var positionCounts: [String: Int] = [:]
    private var consecutiveChecksByRed = 0
    private var consecutiveChecksByBlack = 0
    private var aiTask: Task<Void, Never>?

    var isGameOver: Bool {
        if case .playing = status { return false }
        if case .check = status { return false }
        return true
    }

    init() {
        positionCounts[board.fingerprint()] = 1
    }

    // MARK: 走子
    func tap(pos: Pos) {
        guard !isGameOver, !isAIThinking else { return }
        if aiEnabled && turn != humanColor { return }
        if let sel = selected, legalTargets.contains(pos) {
            doMove(from: sel, to: pos)
            return
        }
        if let piece = board.piece(at: pos), piece.color == turn {
            selected = pos
            legalTargets = board.legalMoves(for: turn).filter { $0.from == pos }.map { $0.to }
            AudioManager.shared.playSelectSound()
        } else {
            selected = nil
            legalTargets = []
        }
    }

    func doMove(from: Pos, to: Pos) {
        guard let piece = board.piece(at: from) else { return }
        let legal = board.legalMoves(for: turn)
        guard var move = legal.first(where: { $0.from == from && $0.to == to }) else { return }
        let notation = Notation.chinese(for: move, on: board)
        let wasCapture = move.isCapture
        board = board.applying(move)
        moveCount += 1
        lastMove = move
        history.append(MoveRecord(index: history.count + 1, notation: notation, from: from, to: to, color: piece.color))
        selected = nil
        legalTargets = []

        if wasCapture { AudioManager.shared.playCaptureSound() } else { AudioManager.shared.playMoveSound() }

        // 长打简化处理：同一方连续将军 3 次判负（避免无限长打）
        if move.isCheck {
            if turn == .red { consecutiveChecksByRed += 1; consecutiveChecksByBlack = 0 } else { consecutiveChecksByBlack += 1; consecutiveChecksByRed = 0 }
            if consecutiveChecksByRed >= 3 {
                status = .won(winner: .black, reason: "红方长打判负"); AudioManager.shared.playLoseSound(); return
            }
            if consecutiveChecksByBlack >= 3 {
                status = .won(winner: .red, reason: "黑方长打判负"); AudioManager.shared.playWinSound(); return
            }
        } else {
            consecutiveChecksByRed = 0; consecutiveChecksByBlack = 0
        }

        // 重复局面：同一局面出现 3 次判和
        let fp = board.fingerprint()
        positionCounts[fp, default: 0] += 1
        if positionCounts[fp]! >= 3 {
            status = .draw(reason: "三次重复局面"); return
        }

        let next = turn.opposite
        if board.hasNoLegalMove(next) {
            let reason = board.isInCheck(next) ? "将死" : "困毙"
            status = .won(winner: turn, reason: reason)
            if turn == humanColor { AudioManager.shared.playWinSound() } else { AudioManager.shared.playLoseSound() }
            return
        }
        turn = next
        status = board.isInCheck(next) ? .check(color: next) : .playing
        if case .check = status { AudioManager.shared.playCheckSound() }
        maybeTriggerAI()
    }

    private func maybeTriggerAI() {
        guard aiEnabled, !isGameOver, turn != humanColor else { return }
        isAIThinking = true
        let snapshot = board
        let color = turn
        let diff = difficulty
        aiTask?.cancel()
        aiTask = Task {
            let move = await Task.detached(priority: .userInitiated) {
                AIEngine().bestMove(board: snapshot, color: color, difficulty: diff)
            }.value
            await MainActor.run {
                self.isAIThinking = false
                guard !Task.isCancelled, let m = move, !self.isGameOver else { return }
                self.doMove(from: m.from, to: m.to)
            }
        }
    }

    // MARK: 操作
    func newGame() {
        aiTask?.cancel()
        board = Board()
        turn = .red
        selected = nil; legalTargets = []; history = []; lastMove = nil; moveCount = 0
        status = .playing; isAIThinking = false
        positionCounts = [board.fingerprint(): 1]
        consecutiveChecksByRed = 0; consecutiveChecksByBlack = 0
        if aiEnabled && humanColor == .black { maybeTriggerAI() }
    }

    func undo() {
        guard history.count >= 1, !isAIThinking else { return }
        aiTask?.cancel()
        isAIThinking = false
        // 悔棋：人机对局一次悔两步（回到己方回合），双人对局悔一步
        let steps = (aiEnabled && history.count >= 2) ? 2 : 1
        for _ in 0..<steps {
            guard !history.isEmpty else { break }
            history.removeLast()
            moveCount -= 1
        }
        rebuildBoardFromHistory()
        status = board.isInCheck(turn) ? .check(color: turn) : .playing
        selected = nil; legalTargets = []
    }

    private func rebuildBoardFromHistory() {
        var b = Board()
        var t: PieceColor = .red
        positionCounts = [b.fingerprint(): 1]
        for rec in history {
            b = b.applying(Move(from: rec.from, to: rec.to))
            positionCounts[b.fingerprint(), default: 0] += 1
            t = t.opposite
        }
        board = b
        turn = t
        lastMove = history.last.map { Move(from: $0.from, to: $0.to) }
    }

    func saveCurrentGame() -> SavedGame {
        let result: String
        switch status {
        case .won(let w, let r): result = (w == .red ? "红胜" : "黑胜") + "·\(r)"
        case .draw(let r): result = "和棋·\(r)"
        default: result = "未完·\(history.count) 手"
        }
        return SavedGame(date: Date(), title: "对局 \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))",
                         result: result, moves: history, difficulty: difficulty.title)
    }

    func exportText() -> String {
        var lines = ["中国象棋棋谱", "结果：\(status.text)", "难度：\(difficulty.title)", ""]
        for rec in history {
            lines.append("\(rec.index). \(rec.color == .red ? "红" : "黑") \(rec.notation)")
        }
        return lines.joined(separator: "\n")
    }
}
