Rank = require('../poker/rank').PokerRank


_combinations_royalties = [25, 15, 10, 6, 4, 2, 1]

module.exports.PokerOFCRank = class PokerOFCRank
  _calculate_royalty: (line, rank)->
    if line is 0
      if rank[0] is 6
        return 22 - rank[1]
      if rank[0] is 8 and rank[1] < 9
        return 9 - rank[1]
    if line is 1 and rank[0] <= 6
      return _combinations_royalties[rank[0]] * 2
    if line is 2 and rank[0] <= 5
      return _combinations_royalties[rank[0]]
    return 0

  calculate: (hand, fantasyland = false)->
    lines = hand.map (cards, line)=>
      if cards.length isnt (if line is 0 then 3 else 5)
        return null
      rank = new Rank(cards)
      {
        rank: rank._hand_rank
        message: rank._hand_message
        royalties: PokerOFCRank::_calculate_royalty(line, rank._hand_rank)
      }
    filled = lines.filter( (rank)-> !!rank ).length is 3
    valid = !filled or ( Rank::_compare_hands(lines[2].rank, lines[1].rank) >= 0 and Rank::_compare_hands(lines[1].rank, lines[0].rank) >= 0 )

    Object.assign {lines, filled, valid}, {
      royalties: lines.reduce ( (acc, line)-> acc + ( if line then line.royalties else 0 ) ), 0
      fantasyland: do =>
        if !filled or !valid
          return false
        return if !fantasyland then lines[0].royalties >= 7 else ( lines[0].royalties >= 10 or lines[1].royalties >= 12 or lines[2].royalties >= 10 )
    }

  compare: (hands)->
    hands_new = hands.map (hand)=>
      Object.assign {}, hand, {
        points_change: 0
        lines: hand.lines.map (line)->
          Object.assign {}, line, {points_change: 0}
      }
    [0...(hands.length - 1)].forEach (hand1)=>
      [(hand1 + 1)...hands.length].forEach (hand2)=>
        lines_total = 0
        [0...3].forEach (line_number)=>
          result = do =>
            if !hands[hand1].valid and !hands[hand2].valid
              return 0
            if !hands[hand1].valid
              return -1
            if !hands[hand2].valid
              return 1
            return Rank::_compare_hands hands[hand1].lines[line_number].rank, hands[hand2].lines[line_number].rank
          hands_new[hand1].lines[line_number].points_change += result
          hands_new[hand2].lines[line_number].points_change -= result
          lines_total += result
        do =>
          if !( lines_total is 3 or lines_total is -3 )
            return
          result = if lines_total is 3 then 1 else -1
          [0...3].forEach (line_number)=>
            lines_total += result
            hands_new[hand1].lines[line_number].points_change += result
            hands_new[hand2].lines[line_number].points_change -= result
        result_royalties = hands[hand1].royalties - hands[hand2].royalties
        hands_new[hand1].points_change += lines_total + result_royalties
        hands_new[hand2].points_change -= lines_total + result_royalties
    hands_new
