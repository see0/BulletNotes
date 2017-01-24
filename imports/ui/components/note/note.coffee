{ Template } = require 'meteor/templating'
{ ReactiveDict } = require 'meteor/reactive-dict'
{ Notes } = require '../../../api/notes/notes.coffee'
require './note.jade'
require '../share/share.coffee'

Template.note.previewXOffset = 10
Template.note.previewYOffset = 10
Template.note.donePattern = /(#done|#complete|#finished)/gim

Template.note.isValidImageUrl = (url, callback) ->
  $ '<img>',
    src: url
    error: ->
      callback url, false
    load: ->
      callback url, true

Template.note.onRendered ->
  note = this
  Tracker.autorun ->
    newNote = Notes.findOne note.data._id
    if newNote
      $(note.firstNode).find('.title').first().html Template.notes.formatText newNote.title
      if newNote.body
        $(note.firstNode).find('.body').first().show().html Template.notes.formatText newNote.body

  if @data.focusNext
    $(note.firstNode).find('.title').first().focus()

Template.note.events
  'click .title a': (event) ->
    if !$(event.target).hasClass('tagLink') && !$(event.target).hasClass('atLink')
      window.open(event.target.href)
  'click .fa-heart': (event) ->
    event.preventDefault()
    event.stopImmediatePropagation()
    Meteor.call 'notes.favorite', @_id
  'click .duplicate': (event) ->
    event.preventDefault()
    event.stopImmediatePropagation()
    Meteor.call 'notes.duplicate', @_id
  'click .expand': (event) ->
    event.stopImmediatePropagation()
    event.preventDefault()
    if Meteor.userId()
      Meteor.call 'notes.showChildren', @_id, !@showChildren, FlowRouter.getParam 'shareKey'
    else
      Session.set 'expand_'+@_id, !Session.get('expand_'+@_id)
  'click a.delete': (event) ->
    event.preventDefault();
    $(event.currentTarget).closest('.note').remove()
    Meteor.call 'notes.remove', @_id, FlowRouter.getParam 'shareKey'
  'blur p.body': (event, instance) ->
    event.stopImmediatePropagation()
    body = Template.note.stripTags(event.target.innerHTML)
    Meteor.call 'notes.updateBody', @_id, body, FlowRouter.getParam 'shareKey'
  'focus div.title': (event, instance) ->
    event.stopImmediatePropagation()
    Session.set 'preEdit', @title
    Meteor.call 'notes.focus', @_id
  'blur div.title': (event, instance) ->
    that = this
    event.stopPropagation()
    if Session.get 'indenting'
      Session.set 'indenting', false
      return
    title = Template.note.stripTags(event.target.innerHTML)
    if title != @title
      Meteor.call 'notes.updateTitle', @_id, title, FlowRouter.getParam 'shareKey', (err, res) ->
        that.title = title
        $(event.target).html Template.notes.formatText title
  'mouseover .previewLink': (event) ->
    @t = @title
    @title = ''
    c = if @t != '' then '<br/>' + @t else ''
    url = event.currentTarget.href
    Template.note.isValidImageUrl url, (url, valid) ->
      if valid
        $('body').append '<p id=\'preview\'><img src=\'' + url + '\' alt=\'Image preview\' />' + c + '</p>'
        $('#preview').css('top', event.pageY - Template.note.previewXOffset + 'px').css('left', event.pageX + Template.note.previewYOffset + 'px').fadeIn 'fast'
  'mousemove .previewLink': (event) ->
    $('#preview').css('top', event.pageY - Template.note.previewXOffset + 'px').css 'left', event.pageX + Template.note.previewYOffset + 'px'
  'mouseleave .previewLink': (event) ->
    $('#preview img').attr('src','')
    $('#preview').remove()
  'keydown div.title': (event) ->
    note = this
    event.stopImmediatePropagation()
    switch event.keyCode
      # Enter
      when 13
        event.preventDefault()
        if event.shiftKey
          # Edit the body
          console.log event
          $(event.target).siblings('.body').show().focus()
        else
          # Chop the text in half at the cursor
          # put what's on the left in a note on top
          # put what's to the right in a note below
          console.log window.getSelection().anchorOffset
          console.log event
          position = event.target.selectionStart
          text = event.target.innerHTML
          topNote = text.substr(0, position)
          bottomNote = text.substr(position)
          # Create a new note below the current.
          Meteor.call 'notes.updateTitle', note._id, topNote, FlowRouter.getParam('shareKey'), (err, res) ->
            console.log err, res
            Meteor.call 'notes.insert', '', note.rank + .5, note.parent, FlowRouter.getParam('shareKey'), (err, res) ->
              Template.notes.calculateRank()
              setTimeout (->
                $(event.target).closest('.note').next().find('.title').focus()
              ), 50
      # Tab
      when 9
        event.preventDefault()
        Session.set 'indenting', true
        # First save the title in case it was changed.
        title = Template.note.stripTags(event.target.innerHTML)
        if title != @title
          Meteor.call 'notes.updateTitle', @_id, title, FlowRouter.getParam 'shareKey'
        parent_id = Blaze.getData($(event.currentTarget).closest('.note').prev().get(0))._id
        if event.shiftKey
          Meteor.call 'notes.outdent', @_id, FlowRouter.getParam 'shareKey'
        else
          Meteor.call 'notes.makeChild', @_id, parent_id, null, FlowRouter.getParam 'shareKey'
      # Backspace / delete
      when 8
        if event.currentTarget.innerText.trim().length == 0
          $(event.currentTarget).closest('.note').prev().find('.title').focus()
          Meteor.call 'notes.remove', @_id, FlowRouter.getParam 'shareKey'
        if window.getSelection().toString() == ''
          position = event.target.selectionStart
          if position == 0
            # We're at the start of the note, add this to the note above, and remove it.
            console.log event.target.value
            prev = $(event.currentTarget).closest('.note').prev()
            console.log prev
            prevNote = Blaze.getData(prev.get(0))
            console.log prevNote
            note = this
            console.log note
            Meteor.call 'notes.updateTitle', prevNote._id, prevNote.title + event.target.value, FlowRouter.getParam 'shareKey', (err, res) ->
              Meteor.call 'notes.remove', note._id, FlowRouter.getParam 'shareKey', (err, res) ->
                # Moves the caret to the correct position
                prev.find('div.title').focus()
      # Up
      when 38
        # Command is held
        if event.metaKey
          $(event.currentTarget).closest('.note').find('.expand').trigger 'click'
        else
          if $(event.currentTarget).closest('.note').prev().length
            $(event.currentTarget).closest('.note').prev().find('div.title').focus()
          else
            # There is no previous note in the current sub list, go up a note.
            $(event.currentTarget).closest('.note').parentsUntil('.note').siblings('.noteContainer').find('div.title').focus()
      # Down
      when 40
        if event.metaKey
          $(event.currentTarget).closest('.note').find('.expand').trigger 'click'
        else
          childNote = $(event.currentTarget).closest('.note').find('ol .note').first()
          nextNote = $(event.currentTarget).closest('.note').next()
          if childNote.length
            childNote.find('div.title').first().focus()
          else if nextNote.length
            nextNote.find('div.title').first().focus()
          else
            $('#new-note').focus()
      # Escape
      when 27
        $(event.currentTarget).html Session.get 'preEdit'
        $(event.currentTarget).blur()

Template.note.stripTags = (inputText) ->
  if !inputText
    return
  inputText = inputText.replace(/<\/?span[^>]*>/g, '')
  inputText = inputText.replace(/<\/?a[^>]*>/g, '')
  inputText

Template.note.helpers
  className: ->
    className = "note"
    if @title
      tags = @title.match(/#\w+/g)
      if tags
        tags.forEach (tag) ->
          className = className + ' tag-' + tag.substr(1).toLowerCase()
    if @favorite
      className = className + ' favorite'
    if @shared
      className = className + ' shared'
    className
  style: ->
    margin = 2 * (@level - Session.get('level'))
    'margin-left: ' + margin + 'em'
  expandClass: ->
    if @children > 0 and (@showChildren || Session.get('expand_'+@_id))
      'fa-angle-up'
    else if @children > 0
      'fa-angle-down collapsed'
  bulletClass: ->
    if @children > 0
      return 'hasChildren'
    return
  children: ->
    if Session.get 'searchTerm'
      return
    if @showChildren || Session.get 'expand_'+@_id
      Meteor.subscribe 'notes.children', @_id, FlowRouter.getParam 'shareKey'
      notes = Notes.find({ parent: @_id }, sort: rank: 1)
      return notes
  progress: ->
    setTimeout ->
      $('[data-toggle="tooltip"]').tooltip('destroy').tooltip()
    , 100
    Template.notes.getProgress this
  progressClass: ->
    Template.notes.getProgressClass this
  shareKey: ->
    FlowRouter.getParam 'shareKey'