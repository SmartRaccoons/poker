events = require('events')
cloneDeep = require('lodash').cloneDeep
isEqual = require('lodash').isEqual


module.exports.Default = class Default extends events.EventEmitter
  options_default: {}
  options_bind: {}
  constructor: (options)->
    super()
    @options = Object.assign cloneDeep(@options_default), options
    @_options_bind = Object.keys(@options_bind).reduce (acc, v)=>
      acc.concat { events: v.split(','), fn: @options_bind[v].bind(@) }
    , []

  options_update: (options, force = false)->
    updated = []
    for k, v of options
      if force or !isEqual(@options[k], v)
        @options[k] = v
        updated.push k
    if updated.length is 0
      return
    @_options_bind.filter (v)->
      updated.filter( (up)-> v.events.indexOf(up) >= 0 ).length > 0
    .forEach (v)-> v.fn()
    updated.forEach (option)=> @emit "change:#{option}"
    @emit 'change'
