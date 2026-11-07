import SwiftUI

// MARK: - 棋盘绘制
struct BoardLinesView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let cell = w / 8.0
            let h = cell * 9.0
            Path { p in
                // 横线 10 条
                for r in 0..<10 {
                    let y = Double(r) * cell
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: w, y: y))
                }
                // 竖线：外侧两条通长，中间 7 条分两段（河界断开）
                for c in 0..<9 {
                    let x = Double(c) * cell
                    if c == 0 || c == 8 {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h))
                    } else {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: cell * 4))
                        p.move(to: CGPoint(x: x, y: cell * 5))
                        p.addLine(to: CGPoint(x: x, y: h))
                    }
                }
                // 九宫斜线（上下各一个 X）
                p.move(to: CGPoint(x: cell * 3, y: 0)); p.addLine(to: CGPoint(x: cell * 5, y: cell * 2))
                p.move(to: CGPoint(x: cell * 5, y: 0)); p.addLine(to: CGPoint(x: cell * 3, y: cell * 2))
                p.move(to: CGPoint(x: cell * 3, y: cell * 7)); p.addLine(to: CGPoint(x: cell * 5, y: cell * 9))
                p.move(to: CGPoint(x: cell * 5, y: cell * 7)); p.addLine(to: CGPoint(x: cell * 3, y: cell * 9))
            }
            .stroke(Color.brown.opacity(0.85), lineWidth: 1.2)
        }
    }
}

/// 炮位 / 兵位的小角标记
struct PositionMarksView: View {
    var body: some View {
        GeometryReader { geo in
            let cell = geo.size.width / 8.0
            let points: [Pos] = [
                Pos(row: 2, col: 1), Pos(row: 2, col: 7), Pos(row: 7, col: 1), Pos(row: 7, col: 7),
                Pos(row: 3, col: 0), Pos(row: 3, col: 2), Pos(row: 3, col: 4), Pos(row: 3, col: 6), Pos(row: 3, col: 8),
                Pos(row: 6, col: 0), Pos(row: 6, col: 2), Pos(row: 6, col: 4), Pos(row: 6, col: 6), Pos(row: 6, col: 8),
            ]
            ForEach(points, id: \.self) { pos in
                let cx = Double(pos.col) * cell
                let cy = Double(pos.row) * cell
                let g = cell * 0.09, l = cell * 0.14
                Path { p in
                    // 四个角各画一小段折线，靠边的角只画内侧
                    let dirs: [(Double, Double)] = [(-1,-1),(1,-1),(-1,1),(1,1)]
                    for (dx, dy) in dirs {
                        if pos.col == 0 && dx < 0 { continue }
                        if pos.col == 8 && dx > 0 { continue }
                        p.move(to: CGPoint(x: cx + dx * (g + l), y: cy + dy * g))
                        p.addLine(to: CGPoint(x: cx + dx * g, y: cy + dy * g))
                        p.addLine(to: CGPoint(x: cx + dx * g, y: cy + dy * (g + l)))
                    }
                }
                .stroke(Color.brown.opacity(0.8), lineWidth: 1.2)
            }
        }
    }
}

struct PieceView: View {
    let piece: Piece
    let diameter: CGFloat
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.98, green: 0.92, blue: 0.78))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            Circle()
                .stroke(piece.color == .red ? Color.red : Color.black, lineWidth: 1.5)
                .padding(3)
            Text(piece.name)
                .font(.system(size: diameter * 0.52, weight: .bold))
                .foregroundColor(piece.color == .red ? .red : .black)
        }
        .frame(width: diameter, height: diameter)
    }
}

struct BoardView: View {
    let board: Board
    let selected: Pos?
    let legalTargets: [Pos]
    let lastMove: Move?
    let onTap: (Pos) -> Void

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let cell = width / 8.0
            let height = cell * 9.0
            let pieceD = cell * 0.88
            ZStack {
                // 木纹底色
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.93, green: 0.82, blue: 0.62))
                Text("楚 河          汉 界")
                    .font(.system(size: cell * 0.32, weight: .bold))
                    .foregroundColor(.brown.opacity(0.7))
                    .position(x: width / 2, y: cell * 4.5)
                BoardLinesView()
                    .frame(width: width, height: height)
                PositionMarksView()
                    .frame(width: width, height: height)
                // 上一步高亮
                if let lm = lastMove {
                    ForEach([lm.from, lm.to], id: \.self) { pos in
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: pieceD, height: pieceD)
                            .position(x: Double(pos.col) * cell, y: Double(pos.row) * cell)
                    }
                }
                // 合法落点提示
                ForEach(legalTargets, id: \.self) { pos in
                    Circle()
                        .fill(Color.green.opacity(0.55))
                        .frame(width: cell * 0.32, height: cell * 0.32)
                        .position(x: Double(pos.col) * cell, y: Double(pos.row) * cell)
                }
                // 选中高亮
                if let sel = selected {
                    Circle()
                        .stroke(Color.blue, lineWidth: 2.5)
                        .frame(width: pieceD + 4, height: pieceD + 4)
                        .position(x: Double(sel.col) * cell, y: Double(sel.row) * cell)
                }
                // 棋子
                ForEach(0..<10, id: \.self) { r in
                    ForEach(0..<9, id: \.self) { c in
                        if let piece = board.grid[r][c] {
                            PieceView(piece: piece, diameter: pieceD)
                                .position(x: Double(c) * cell, y: Double(r) * cell)
                        }
                    }
                }
                // 点按层：9x10 透明按钮
                ForEach(0..<10, id: \.self) { r in
                    ForEach(0..<9, id: \.self) { c in
                        Button(action: { onTap(Pos(row: r, col: c)) }) {
                            Color.clear.frame(width: cell, height: cell)
                        }
                        .position(x: Double(c) * cell, y: Double(r) * cell)
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: width, height: height)
            .padding(cell * 0.55)
            .background(Color(red: 0.85, green: 0.68, blue: 0.42))
            .cornerRadius(10)
        }
        .aspectRatio(8.0 / 10.1, contentMode: .fit)
    }
}

// MARK: - 对局页
struct GameView: View {
    @StateObject private var vm = GameViewModel()
    @StateObject private var audio = AudioManager.shared
    @StateObject private var store = GameStore()
    @State private var showSaveAlert = false
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        Text(vm.status.text)
                            .font(.headline)
                            .foregroundColor(vm.status.text.contains("将军") ? .red : .primary)
                        Spacer()
                        if vm.isAIThinking { ProgressView().scaleEffect(0.8); Text("AI 思考中…").font(.caption) }
                        Text(vm.turn == .red ? "红方行棋" : "黑方行棋").font(.subheadline)
                    }
                    BoardView(board: vm.board, selected: vm.selected, legalTargets: vm.legalTargets, lastMove: vm.lastMove, onTap: { vm.tap(pos: $0) })
                    HStack(spacing: 10) {
                        Button("新局") { vm.newGame() }
                            .buttonStyle(.borderedProminent)
                        Button("悔棋") { vm.undo() }.buttonStyle(.bordered)
                            .disabled(vm.history.isEmpty || vm.isAIThinking)
                        Button("保存棋谱") { store.save(game: vm.saveCurrentGame()); showSaveAlert = true }.buttonStyle(.bordered)
                        Button("设置") { showSettings = true }.buttonStyle(.bordered)
                    }
                    Picker("难度", selection: $vm.difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { d in Text(d.title).tag(d) }
                    }
                    .pickerStyle(.segmented)
                    Text(vm.difficulty.description).font(.caption).foregroundColor(.secondary)
                    Toggle("人机对战", isOn: $vm.aiEnabled)
                    Toggle("我执红先行", isOn: Binding(
                        get: { vm.humanColor == .red },
                        set: { vm.humanColor = $0 ? .red : .black; vm.newGame() }
                    ))
                    .disabled(!vm.aiEnabled)
                    if !vm.history.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("着法（\(vm.history.count) 手）").font(.headline)
                            Text(vm.history.map { "\($0.index).\($0.notation)" }.joined(separator: "  "))
                                .font(.system(size: 14)).lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("中国象棋")
            .alert("棋谱已保存", isPresented: $showSaveAlert) { Button("好", role: .cancel) {} }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .onAppear { if audio.musicEnabled { audio.startMusic() } }
        }
    }
}

// MARK: - 设置页（音乐 / 音效）
struct SettingsView: View {
    @StateObject private var audio = AudioManager.shared
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("背景音乐")) {
                    Toggle("背景音乐（古风五声旋律）", isOn: $audio.musicEnabled)
                    HStack {
                        Text("音量")
                        Slider(value: $audio.musicVolume, in: 0...1)
                    }
                }
                Section(header: Text("音效")) {
                    Toggle("走子 / 吃子 / 将军音效", isOn: $audio.sfxEnabled)
                    Button("试听走子声") { audio.playMoveSound() }
                    Button("试听将军声") { audio.playCheckSound() }
                    Button("试听胜利声") { audio.playWinSound() }
                }
                Section(header: Text("说明")) {
                    Text("背景音乐为程序合成的五声音阶旋律，不含任何版权音乐文件。")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
        }
    }
}

// MARK: - 棋谱列表与复盘
struct RecordsView: View {
    @StateObject private var store = GameStore()
    @State private var replayGame: SavedGame?

    var body: some View {
        NavigationView {
            List {
                if store.savedGames.isEmpty {
                    Text("还没有保存的棋谱。下一盘棋后点“保存棋谱”即可。")
                        .foregroundColor(.secondary)
                }
                ForEach(store.savedGames) { game in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.title).font(.headline)
                        Text("\(game.dateText) · \(game.result) · \(game.moves.count) 手 · \(game.difficulty)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { replayGame = game }
                }
                .onDelete { store.delete(at: $0) }
            }
            .navigationTitle("棋谱")
            .toolbar { EditButton() }
            .sheet(item: $replayGame) { game in ReplayView(game: game) }
        }
    }
}

struct ReplayView: View {
    let game: SavedGame
    @State private var step: Int = 0

    private func boardAt(step: Int) -> Board {
        var b = Board()
        for rec in game.moves.prefix(step) {
            b = b.applying(Move(from: rec.from, to: rec.to))
        }
        return b
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 14) {
                Text("\(game.title) · \(game.result)").font(.headline)
                BoardView(board: boardAt(step: step), selected: nil, legalTargets: [], lastMove: step > 0 ? Move(from: game.moves[step - 1].from, to: game.moves[step - 1].to) : nil, onTap: { _ in })
                HStack(spacing: 16) {
                    Button("⏮ 开局") { step = 0 }.disabled(step == 0)
                    Button("◀ 上一步") { step = max(0, step - 1) }.disabled(step == 0)
                    Button("下一步 ▶") { step = min(game.moves.count, step + 1) }.disabled(step >= game.moves.count)
                    Button("⏭ 终局") { step = game.moves.count }.disabled(step >= game.moves.count)
                }
                .buttonStyle(.bordered)
                Text(step == 0 ? "开局" : "\(step). \(game.moves[step - 1].notation)")
                    .font(.headline)
                Text("第 \(step) / \(game.moves.count) 手")
                    .font(.caption).foregroundColor(.secondary)
                ShareLink(item: shareText(), subject: Text("中国象棋棋谱"), message: Text(shareText())) {
                    Label("导出分享棋谱", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding()
            .navigationTitle("复盘")
        }
    }

    private func shareText() -> String {
        var lines = ["中国象棋棋谱", "结果：\(game.result)", ""]
        for rec in game.moves { lines.append("\(rec.index). \(rec.color == .red ? "红" : "黑") \(rec.notation)") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - 残局
struct PuzzlesView: View {
    var body: some View {
        NavigationView {
            List(Puzzles.all) { puzzle in
                NavigationLink(destination: PuzzlePlayView(puzzle: puzzle)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(puzzle.title).font(.headline)
                        Text(puzzle.description).font(.caption).foregroundColor(.secondary)
                        Text("限 \(puzzle.maxMoves) 步内将死黑将").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("残局")
        }
    }
}

struct PuzzlePlayView: View {
    let puzzle: Puzzle
    @State private var board: Board
    @State private var selected: Pos?
    @State private var targets: [Pos] = []
    @State private var movesMade = 0
    @State private var message = "红方先行，将死黑将即为过关。"
    @State private var showHint = false
    @State private var isOver = false
    private let ai = AIEngine()

    init(puzzle: Puzzle) {
        self.puzzle = puzzle
        _board = State(initialValue: puzzle.initialBoard())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(puzzle.title).font(.title2).bold()
                Text(message).font(.subheadline).foregroundColor(isOver ? .green : .primary)
                Text("已走 \(movesMade) / \(puzzle.maxMoves) 步").font(.caption).foregroundColor(.secondary)
                BoardView(board: board, selected: selected, legalTargets: targets, lastMove: nil, onTap: tap)
                HStack {
                    Button("重开") { reset() }.buttonStyle(.bordered)
                    Button("提示") { showHint.toggle() }.buttonStyle(.bordered)
                }
                if showHint { Text("提示：\(puzzle.hint)").font(.caption).padding(8).background(Color.yellow.opacity(0.15)).cornerRadius(8) }
                Text(puzzle.description).font(.caption).foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("残局挑战")
    }

    private func reset() {
        board = puzzle.initialBoard()
        selected = nil; targets = []; movesMade = 0; isOver = false
        message = "红方先行，将死黑将即为过关。"
    }

    private func tap(pos: Pos) {
        guard !isOver else { return }
        if let sel = selected, targets.contains(pos) {
            guard let piece = board.piece(at: sel) else { return }
            let notation = Notation.chinese(for: Move(from: sel, to: pos), on: board)
            _ = notation; _ = piece
            board = board.applying(Move(from: sel, to: pos))
            movesMade += 1
            selected = nil; targets = []
            AudioManager.shared.playMoveSound()
            if board.hasNoLegalMove(.black) {
                message = "过关！\(board.isInCheck(.black) ? "将死" : "困毙")黑将，用时 \(movesMade) 步。"
                isOver = true
                AudioManager.shared.playWinSound()
                return
            }
            if movesMade >= puzzle.maxMoves {
                message = "步数已用完，未能将死黑将，请重开再试。"
                isOver = true
                return
            }
            // 黑方由入门 AI 应着
            DispatchQueue.global(qos: .userInitiated).async {
                let reply = AIEngine().bestMove(board: board, color: .black, difficulty: .easy)
                DispatchQueue.main.async {
                    guard let reply, !isOver else { return }
                    board = board.applying(reply)
                    if board.hasNoLegalMove(.red) {
                        message = "失败：红方被\(board.isInCheck(.red) ? "将死" : "困毙")，请重开再试。"
                        isOver = true
                        AudioManager.shared.playLoseSound()
                    }
                }
            }
            return
        }
        if let piece = board.piece(at: pos), piece.color == .red {
            selected = pos
            targets = board.legalMoves(for: .red).filter { $0.from == pos }.map { $0.to }
        } else {
            selected = nil; targets = []
        }
    }
}

// MARK: - 主界面
struct ContentView: View {
    var body: some View {
        TabView {
            GameView().tabItem { Label("对局", systemImage: "circle.grid.cross") }
            RecordsView().tabItem { Label("棋谱", systemImage: "list.bullet") }
            PuzzlesView().tabItem { Label("残局", systemImage: "puzzlepiece") }
            SettingsView().tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}
