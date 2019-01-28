combinations_gen_shuffle = (ar, length)->
  shuffle = (array) ->
    for i in [0...array.length]
      j = Math.floor(Math.random() * (i + 1))
      [array[i], array[j]] = [array[j], array[i]]
    array
  i = 0
  while i++ < 2500
    yield shuffle(ar).slice(0, length)

combinations_gen_all = (ar, length)->
  actual = [0...length]
  ar_length = ar.length
  loop
    if actual[0] is ar_length
      return
    yield actual.map (i)-> ar[i]
    loop
      actual[length - 1]++
      if length > 1
        [(length - 1)..1].forEach (i)->
          if actual[i] is ar_length
            actual[i - 1]++
            actual[i] = 0
      if actual.filter( (v, i)-> actual.indexOf(v) is i ).length isnt length
        continue
      break

combinations_gen = (ar, length)->
  if length > 2
    return combinations_gen_shuffle(ar, length)
  return combinations_gen_all(ar, length)


Rank = require('./rank').PokerRank


module.exports.PokerOdds = class PokerOdds
  _flop: [3, 4, 5]
  constructor: ->
    @cards_all = []
    Rank::_deck_ranks.forEach (r)=>
      Rank::_deck_suits.forEach (s)=>
        @cards_all.push "#{r}#{s}"

  percent: (v)-> Math.round(1000 * v) / 10

  combinations: (hand, board)->
    cards_used = hand.concat(board)
    cards_left = @cards_all.filter (c)-> cards_used.indexOf(c) < 0
    combinations = {}
    Rank::_combinations.forEach (c)->
      combinations[c] =
        round: []
        combination: null
    [2...@_flop.indexOf(board.length)].forEach (flop, i)=>
      Object.keys(combinations).forEach (c)-> combinations[c].round[i] = 0
      total = 0
      combination_iter = combinations_gen cards_left, @_flop[flop] - board.length
      loop
        next = combination_iter.next()
        if next.done
          break
        cards = next.value
        rank = new Rank board.concat(cards).concat(hand)
        if !combinations[rank._hand_message].combination
          combinations[rank._hand_message].combination = rank._hand_matched
        combinations[rank._hand_message].round[i]++
        total++
      Object.keys(combinations).forEach (c)=> combinations[c].round[i] = @percent(combinations[c].round[i] / total)
    combinations

  calculate: (hands, board)->
    cards_used = Array::concat.apply([], hands).concat(board)
    cards_left = @cards_all.filter (c)-> cards_used.indexOf(c) < 0
    hands_odds = hands.map -> 0
    combination_iter = combinations_gen cards_left, 5 - board.length
    if board.length is 5
      Rank::compare(
        hands.map (hand)=> new Rank( board.concat(hand) )._hand_rank
      )[0].forEach (win)-> hands_odds[win]++
      hands_total = hands_odds.reduce ((acc, v)-> acc + v), 0
      return hands_odds.map (hand)=> @percent(hand / hands_total)
    loop
      next = combination_iter.next()
      if next.done
        break
      cards = next.value
      Rank::compare(
        hands.map (hand)=> new Rank( board.concat(cards).concat(hand) )._hand_rank
      )[0].forEach (win)-> hands_odds[win]++
    hands_total = hands_odds.reduce ((acc, v)-> acc + v), 0
    hands_odds.map (hand)=> @percent(hand / hands_total)
