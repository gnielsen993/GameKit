//
//  SudokuBoard.swift
//  gamekit
//
//  9×9 grid of SudokuCell. Immutable value type — mutations return a new
//  Board (mirrors NonogramBoard.setting(...) pattern). Indexed by
//  (row: 0..<9, col: 0..<9).
//
//  Givens and solution strings use the SudokuCore pack convention:
//    - 81-char string
//    - characters '1'..'9' = filled value; '0' or '.' = empty
//    - row-major order (row 0 cols 0..8, then row 1 cols 0..8, …)
//

import Foundation

struct SudokuBoard: Equatable, Hashable, Sendable {
    static let size: Int = 9
    static let boxSize: Int = 3

    /// Row-major flat array, length 81.
    private(set) var cells: [SudokuCell]

    /// Solution string for win-check + .lives validation. 81 chars, '1'..'9'.
    let solution: String

    /// Initialize from puzzle pack strings.
    /// - Parameter givens: 81-char string, '0'/'.' = empty, '1'..'9' = clue.
    /// - Parameter solution: 81-char solved board.
    /// Returns nil if either string is malformed.
    init?(givens: String, solution: String) {
        guard givens.count == 81, solution.count == 81 else { return nil }
        guard solution.allSatisfy({ $0 >= "1" && $0 <= "9" }) else { return nil }

        var cells: [SudokuCell] = []
        cells.reserveCapacity(81)
        for ch in givens {
            switch ch {
            case "1"..."9":
                guard let v = Int(String(ch)) else { return nil }
                cells.append(.given(v))
            case "0", ".":
                cells.append(.empty(notes: []))
            default:
                return nil
            }
        }
        self.cells = cells
        self.solution = solution
    }

    /// Direct cell accessor.
    func cell(row: Int, col: Int) -> SudokuCell {
        cells[row * Self.size + col]
    }

    /// Returns a copy of the board with the given cell replaced.
    func setting(_ cell: SudokuCell, atRow row: Int, col: Int) -> SudokuBoard {
        var copy = self
        copy.cells[row * Self.size + col] = cell
        return copy
    }

    /// Solution digit at (row, col), 1...9. Always defined per init guard.
    func solutionDigit(atRow row: Int, col: Int) -> Int {
        let ch = solution[solution.index(solution.startIndex, offsetBy: row * Self.size + col)]
        return Int(String(ch))!  // safe: solution chars validated in init
    }

    /// True when every cell holds the correct solution digit.
    var isSolved: Bool {
        for r in 0..<Self.size {
            for c in 0..<Self.size {
                let cell = cell(row: r, col: c)
                guard let v = cell.value, v == solutionDigit(atRow: r, col: c) else {
                    return false
                }
            }
        }
        return true
    }

    // MARK: - Peer geometry

    /// All cell indices in the same row, column, or 3×3 box as (row, col),
    /// EXCLUDING the cell itself. 20 peers per cell.
    static func peerIndices(row: Int, col: Int) -> Set<Int> {
        var peers: Set<Int> = []
        // Row
        for c in 0..<size where c != col {
            peers.insert(row * size + c)
        }
        // Column
        for r in 0..<size where r != row {
            peers.insert(r * size + col)
        }
        // 3×3 box
        let boxRow = (row / boxSize) * boxSize
        let boxCol = (col / boxSize) * boxSize
        for r in boxRow..<(boxRow + boxSize) {
            for c in boxCol..<(boxCol + boxSize) {
                if r != row || c != col {
                    peers.insert(r * size + c)
                }
            }
        }
        return peers
    }

    /// Remove `value` from every peer cell's notes. Used when a value
    /// commits — auto-clears stale notes per spec.
    func clearingPeerNotes(of value: Int, fromRow row: Int, col: Int) -> SudokuBoard {
        let peers = Self.peerIndices(row: row, col: col)
        var copy = self
        for idx in peers {
            if case .empty(var notes) = copy.cells[idx], notes.contains(value) {
                notes.remove(value)
                copy.cells[idx] = .empty(notes: notes)
            }
        }
        return copy
    }
}
