class AbortButton
  SELECTOR = '[data-action="abort"]'

  @listen: ->
    $(document).on('click', SELECTOR, @handle)

  @handle: (event) =>
    event.preventDefault()
    button = new this($(event.currentTarget))
    button.trigger()

  constructor: (@$button) ->
    @url = @$button.attr('href')
    @shouldRollback = @$button.data('rollback')

  trigger: ->
    return false if @isDisabled()

    @disable()
    @waitForCompletion()
    $.post(@url).success(@waitForCompletion).error(@reenable)

  waitForCompletion: =>
    setTimeout(@reenable, 3000)

  reenable: =>
    @$button.removeClass('pending btn-disabled')
    @$button.siblings(SELECTOR).removeClass('btn-disabled')

  disable: ->
    @$button.addClass('pending btn-disabled')
    @$button.siblings(SELECTOR).addClass('btn-disabled')

  isDisabled: ->
    @$button.hasClass('btn-disabled')

AbortButton.listen()
