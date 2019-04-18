_id = 0
module.exports.CardParam = class Card extends String
  constructor: (v)->
    _id++
    super ...arguments
    @id = _id
    parts = v.split(';')
    @card = parts[0]
    @marks = if parts[1] then parts[1].split(',') else []

  check: (marks)->
    if !Array.isArray(marks)
      marks = [marks]
    for m1 in @marks
      for m2 in marks
        if m1 is m2
          return true
    return false

  mark: (mark)->
    if @marks.indexOf(mark) >= 0
      return
    @marks.push mark

  mark_remove: (mark)->
    if !mark
      return @marks = []
    if @marks.indexOf(mark) < 0
      return
    @marks.splice(@marks.indexOf(mark), 1)

  compare: (card)->
    card.id is @id

  toString: -> [@card, @marks.join(',')].join(';')
