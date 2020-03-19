Default = require('./default').Default
cloneDeep = require('lodash').cloneDeep


module.exports.PokerBoard = class Board extends Default
  options_default:
    cards: []
    pot: []
    bet_raise_position: -1
    bet_raise_count: 0
    bet_max: 0

  round: (params)->
    @options_update Object.assign(cloneDeep(@options_default), {
      bet_raise: params.bet_raise_default
    }, params)

  bet: ({bet, position, command})->
    if @options.bet_max >= bet
      return
    bet_diff = bet - @options.bet_max
    @options_update Object.assign(
      {
        bet_max: bet
        bet_raise_position: position
      }
      if command isnt 'blind' then {
        bet_raise_count: @options.bet_raise_count + 1
      }
      if bet_diff > @options.bet_raise then {
        bet_raise: @_bet_raise_calc(bet_diff)
      }
    )

  _bet_raise_calc: (bet_diff)->
    Math.ceil(bet_diff / @options.bet_raise_default) * @options.bet_raise_default

  bet_max: -> @options.bet_max

  bet_raise: -> @options.bet_raise

  bet_raise_count: -> @options.bet_raise_count

  progress: ({cards})->
    @options_update {
      cards: cloneDeep(@options.cards.slice(0).concat(cards))
      bet_raise_position: @options_default.bet_raise_position
      bet_raise_count: @options_default.bet_raise_count
      bet_max: @options_default.bet_max
      bet_raise: @options.bet_raise_default
    }

  pot: (bets, silent = false)->
    if bets.length is 0
      return
    bets.sort (p1, p2)-> p1.bet - p2.bet
    pot = JSON.parse(JSON.stringify(@options.pot))
    [0...bets.length]
      .map (i)=>
        if bets[i].fold
          pot.forEach (p)->
            index = p.positions.indexOf bets[i].position
            if index >= 0
              p.positions.splice(index, 1)
        bet = bets[i].bet
        if bet is 0
          return null
        pot_new = bets.reduce (acc, v, j)->
          if v.bet >= bet
            bets[j].bet -= bet
            acc.pot += bet
            acc.contributors.push({position: v.position, bet})
            if !v.fold
              acc.positions.push(v.position)
          return acc
        , {pot: 0, positions: [], contributors: []}
        pot_new.contributors.sort (c1, c2)-> c1.position - c2.position
        pot_new.positions.sort()
        return pot_new
      .filter (v)-> v isnt null
      .forEach (pot_new)=>
        if pot_new.contributors.length is 1
          return @emit 'pot:return', {pot: pot_new.pot, position: pot_new.positions[0]}
        for i in [0...pot.length]
          if pot_new.positions.join('') is pot[i].positions.join('')
            pot_new.contributors.forEach (cont)=>
              index = pot[i].contributors.findIndex( (c)-> c.position is cont.position )
              if index >= 0
                pot[i].contributors[index].bet += cont.bet
                return
              pot[i].contributors.push cont
            pot[i].pot += pot_new.pot
            return
        pot.push pot_new
    @options_update {pot}
    if !silent
      @emit 'pot:update', pot

  pot_devide: (winners_order, rake)->
    winners_total = winners_order.reduce ((acc, v)-> acc + v.length), 0
    winners_all = winners_order.reduce ((acc, v)-> acc.concat(v)), []
    winners_index = (i)->
      for winners_list, j in winners_order
        if winners_list.indexOf(i) >= 0
          return j
      return winners_total + 1
    rake_cap = if rake then rake.cap else 0
    @options.pot.map (pot)=>
      pot_chips = pot.pot
      if rake
        do =>
          rake_chips = Math.floor(pot_chips * rake.percent / 100)
          if rake_chips is 0 or rake_cap is 0
            return
          if rake_cap < rake_chips
            rake_chips = rake_cap
          rake_cap -= rake_chips
          pot_chips -= rake_chips
          pot.rake = rake_chips
      for winners_list, j in winners_order
        winners = pot.positions.filter (position)-> winners_list.indexOf(position) >= 0
        if winners.length is 0
          continue
        do ->
          total = winners.length
          win = Math.round( pot_chips / total )
          pot.winners = winners.map (position)-> {position, win}
          if total > 1
            pot.winners[0].win += pot_chips - win * total
        pot.showdown = []
        if winners_total <= 1 or pot.positions.length is 1
          return pot
        max_position = Math.max.apply(null, pot.positions)
        show = if pot.positions.indexOf(@options.bet_raise_position) >= 0 then @options.bet_raise_position else @options.show_first
        last_best = winners_total
        while winners.indexOf(show) is -1
          if pot.positions.indexOf(show) >= 0 and last_best >= winners_index(show)
            last_best = winners_index(show)
            pot.showdown.push(show)
          show++
          if show > max_position
            show = 0
        pot.showdown = pot.showdown.concat(winners.filter (winner)-> pot.showdown.indexOf(winner) is -1 )
        return pot

  pot_total: ->
    @options.pot.reduce ((acc, v)-> acc + v.pot ), 0

  toJSON: -> {pot: @options.pot, cards: @options.cards}
