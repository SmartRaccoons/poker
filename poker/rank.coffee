combinations_examples = [
  ['royal_flush', ['As', 'Ks', 'Qs', 'Js', 'Ts'] ]
  ['straight_flush', ['9d', '8d', '7d', '6d', '5d'] ]
  ['four_of_a_kind', ['Ac', 'As', 'Ah', 'Ad', '4s'], 4]
  ['full_house', ['Qs', 'Qh', 'Qd', 'Jc', 'Jd'] ]
  ['flush', ['Ah', 'Jh', '9h', '6h', '3h']]
  ['straight', ['9c', '8s', '7h', '6d', '5c']]
  ['three_of_a_kind', ['2h', '2d', '2c', '5s', 'Qc'], 3]
  ['two_pair', ['Ac', 'Ah', 'Ks', 'Kd', '9s'], 4]
  ['one_pair', ['As', 'Ad', '8c', 'Ts', '2h'], 2]
  ['high_card', ['As', '5c', 'Ts', '9h', '2d'], 1]
]

module.exports.PokerRank = class PokerRank
  _deck_ranks: ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2']
  _deck_suits: ['c', 's', 'h', 'd'] #Clubs (c) Spades (s) Hearts (h) Diamonds (d)

  _combinations_examples: combinations_examples
  _combinations: combinations_examples.map (v)-> v[0]
  constructor: (hand, combinations_ignore = [])->
    @_hand = hand
    .map (card)=> [card.substr(0, 1), card.substr(1, 1)]
    .sort (a, b)=> @_deck_ranks.indexOf(a[0]) - @_deck_ranks.indexOf(b[0])
    @_flush = false
    @_deck_suits.forEach (suit)=>
      suited = @_hand.filter (h)-> h[1] is suit
      if suited.length >= 5
        @_flush = suited
    for combination, i in @_combinations
      if i in combinations_ignore
        continue
      hand_rank = @[combination]()
      if hand_rank
        @_hand_rank = [i].concat(hand_rank)
        @_hand_message = combination
        @_hand_matched = @_matched.map (c)-> c.join ''
        break

  _compare_hands: (h1, h2)->
    for rank, i in h1
      if rank < h2[i]
        return 1
      if rank > h2[i]
        return -1
    return 0

  compare: (hands)->
    hands.reduce (acc, v, j)=>
      for ranks, i in acc
        if @_compare_hands(v, hands[ranks[0]]) is 1
          acc.splice(i, 0, [j])
          return acc
        if @_compare_hands(v, hands[ranks[0]]) is 0
          ranks.push(j)
          acc[i] = ranks
          return acc
      acc.push([j])
      return acc
    , []

  _straight: (cards)->
    cards_uniq = cards.filter (item, pos)-> cards.findIndex( (card)-> item[0] is card[0] ) is pos
    cards_total = cards_uniq.length
    if cards_total < 5
      return [false]
    for j in [0..cards_total - 5]
      if @_deck_ranks.indexOf(cards_uniq[j + 4][0]) - @_deck_ranks.indexOf(cards_uniq[j][0]) is 4
        return [ [@_deck_ranks.indexOf(cards_uniq[j][0])], cards_uniq.slice(j, j + 5) ]
    if cards_uniq[cards_total-1][0] is @_deck_ranks[@_deck_ranks.length - 1] and
      cards_uniq[cards_total - 4][0] is @_deck_ranks[@_deck_ranks.length - 4] and
      cards_uniq[0][0] is @_deck_ranks[0]
        return [ [@_deck_ranks.length - 4], [cards_uniq[0]].concat( cards_uniq.slice(cards_total - 4, cards_total) ) ]
    return [false]

  _match: (cards, rank, times)->
    leftovers = []
    match = []
    for card, i in cards
      if card[0] is rank
        match.push card
        if match.length is times
          return [leftovers.concat( cards.slice(i + 1) ), match]
      else
        leftovers.push card
    return [false]

  _kicker: (cards, kickers)->
    cards.map (c)=>
      @_deck_ranks.indexOf(c[0])
    .slice(0, kickers)

  royal_flush: ->
    if !( @_flush and @_flush[0][0] is @_deck_ranks[0] and @_flush[4][0] is @_deck_ranks[4] )
      return false
    @_matched = @_flush.slice(0, 5)
    return [0]

  straight_flush: ->
    if @_flush
      [rank, matched] = @_straight(@_flush)
      if rank
        @_matched = matched
        return rank
    false

  four_of_a_kind: ->
    for rank, i in @_deck_ranks
      [ranks_left, matched] = @_match(@_hand, rank, 4)
      if ranks_left
        @_matched = matched.concat(ranks_left.slice(0, 1))
        return [i].concat(@_kicker(ranks_left, 1))
    return false

  full_house: ->
    for rank, i in @_deck_ranks
      [ranks_left, matched] = @_match(@_hand, rank, 3)
      if ranks_left
        for rank2, j in @_deck_ranks
          if i isnt j
            [ranks_left2, matched2] = @_match(ranks_left, rank2, 2)
            if ranks_left2
              @_matched = matched.concat(matched2)
              return [i, j]
    return false

  flush: ->
    if !@_flush
      return false
    @_matched = @_flush.slice(0, 5)
    @_kicker(@_flush, 5)

  straight: ->
    [rank, matched] = @_straight(@_hand)
    if !rank
      return false
    @_matched = matched
    rank

  three_of_a_kind: ->
    for rank, i in @_deck_ranks
      [ranks_left, matched] = @_match(@_hand, rank, 3)
      if ranks_left
        @_matched = matched.concat ranks_left.slice(0, 2)
        return [i].concat(@_kicker(ranks_left, 2))
    return false

  two_pair: ->
    for rank, i in @_deck_ranks
      [ranks_left, matched] = @_match(@_hand, rank, 2)
      if ranks_left
        for rank2, j in @_deck_ranks
          if i < j
            [ranks_left2, matched2] = @_match(ranks_left, rank2, 2)
            if ranks_left2
              @_matched = matched.concat(matched2).concat(ranks_left2.slice(0, 1))
              return [i, j].concat(@_kicker(ranks_left2, 1))
    return false

  one_pair: ->
    for rank, i in @_deck_ranks
      [ranks_left, matched] = @_match(@_hand, rank, 2)
      if ranks_left
        @_matched = matched.concat ranks_left.slice(0, 3)
        return [i].concat(@_kicker(ranks_left, 3))
    return false

  high_card: ->
    @_matched = @_hand.slice(0, 5)
    @_kicker(@_hand, 5)
