assert = require('assert')
sinon = require('sinon')

Card = require('../card').CardParam


describe 'Card', ->
  o = null
  beforeEach ->
    o = new Card('Qs;m,ar,k')

  it 'auto id', ->
    assert.equal 1, o.id
    o = new Card('')
    assert.equal 2, o.id

  it 'constructor', ->
    assert.equal 'Qs', o.card
    assert.deepEqual ['m', 'ar', 'k'], o.marks

  it 'check', ->
    assert.equal true, o.check(['m'])
    assert.equal true, o.check(['m', 'k'])
    assert.equal true, o.check(['m', 'c'])
    assert.equal false, o.check(['z', 'c'])

  it 'check (not array)', ->
    assert.equal true, o.check('m')
    assert.equal false, o.check('ma')
    assert.equal false, o.check('z')

  it 'mark', ->
    o.mark 'z'
    assert.deepEqual ['m', 'ar', 'k', 'z'], o.marks

  it 'mark (existed)', ->
    o.mark 'm'
    assert.deepEqual ['m', 'ar', 'k'], o.marks

  it 'mark_remove', ->
    o.mark_remove 'm'
    assert.deepEqual ['ar', 'k'], o.marks

  it 'mark_remove (not existed)', ->
    o.mark_remove 'z'
    assert.deepEqual ['m', 'ar', 'k'], o.marks

  it 'mark_remove (all)', ->
    o.mark_remove()
    assert.deepEqual [], o.marks

  it 'compare', ->
    o.id = 10
    assert.equal true, o.compare({id: 10})
    assert.equal false, o.compare({id: 11})

  it 'toString', ->
    o.card = 'Ac'
    o.marks = ['m', 'a']
    assert.equal 'Ac;m,a', o.toString()
    assert.equal 'Ac;m,a', "#{o}"
