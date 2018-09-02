module.exports.PokerRank = class PokerRank
  _deck_ranks: ['A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2']
  _deck_suits: ['c', 's', 'h', 'd'] #Clubs (c) Spades (s) Hearts (h) Diamonds (d)

  _combinations: [
    'royal_flush'
    'straight_flush'
    'four_of_a_kind'
    'full_house'
    'flush'
    'straight'
    'three_of_kind'
    'two_pair'
    'one_pair'
    'high_card'
  ]
  constructor: (hand)->
    @_hand = hand
    .map (card)=> [card.substr(0, 1), card.substr(1, 1)]
    .sort (a, b)=> @_deck_ranks.indexOf(a[0]) - @_deck_ranks.indexOf(b[0])
    @_ranks = @_hand.map (h) -> h[0]
    @_flush = false
    @_deck_suits.forEach (suit)=>
      suited = @_hand.filter (h)-> h[1] is suit
      if suited.length >= 5
        @_flush = suited.map (h)-> h[0]
    for combination, i in @_combinations
      hand_rank = @[combination]()
      if hand_rank
        @_hand_rank = [i].concat(hand_rank)
        @_hand_message = combination
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
    cards_uniq = cards.filter (item, pos)-> cards.indexOf(item) is pos
    cards_total = cards_uniq.length
    if cards_total < 5
      return false
    for i in [0..@_deck_ranks.length - 4]
      if i is 9 and cards_uniq[cards_total-1] is @_deck_ranks[@_deck_ranks.length - 1] and
      cards_uniq[cards_total - 4] is @_deck_ranks[@_deck_ranks.length - 4] and
      cards_uniq[0] is @_deck_ranks[0]
        return [i]
      for j in [0..cards_total - 5]
        if cards_uniq[j] is @_deck_ranks[i] and cards_uniq[j + 4] is @_deck_ranks[i + 4]
          return [i]
    return false

  _match: (cards, rank, times)->
    if cards.filter( (card)-> card is rank ).length is times
      return cards.filter (card)-> card isnt rank
    return false

  _kicker: (cards, kickers)->
    result = []
    for rank, i in @_deck_ranks
      if @_match cards, rank, 1
        result.push i
      if result.length is kickers
        return result
    return result

  royal_flush: ->
    if @_flush and @_flush[0] is @_deck_ranks[0] and @_flush[4] is @_deck_ranks[4]
     return [0]
    return false

  straight_flush: -> @_flush and @_straight(@_flush)

  four_of_a_kind: ->
    for rank, i in @_deck_ranks
      ranks_left = @_match(@_ranks, rank, 4)
      if ranks_left
        return [i].concat(@_kicker(ranks_left, 1))
    return false

  full_house: ->
    for rank, i in @_deck_ranks
      ranks_left = @_match(@_ranks, rank, 3)
      if ranks_left
        for rank2, j in @_deck_ranks
          if i isnt j and @_match(ranks_left, rank2, 2)
            return [i, j]
    return false

  flush: -> @_flush and @_kicker(@_flush, 5)

  straight: -> @_straight(@_ranks)

  three_of_kind: ->
    for rank, i in @_deck_ranks
      ranks_left = @_match(@_ranks, rank, 3)
      if ranks_left
        return [i].concat(@_kicker(ranks_left, 2))
    return false

  two_pair: ->
    for rank, i in @_deck_ranks
      ranks_left = @_match(@_ranks, rank, 2)
      if ranks_left
        for rank2, j in @_deck_ranks
          if i < j
            ranks_left2 = @_match(ranks_left, rank2, 2)
            if ranks_left2
              return [i, j].concat(@_kicker(ranks_left2, 1))
    return false

  one_pair: ->
    for rank, i in @_deck_ranks
      ranks_left = @_match(@_ranks, rank, 2)
      if ranks_left
        return [i].concat(@_kicker(ranks_left, 3))
    return false

  high_card: -> @_kicker(@_ranks, 5)
