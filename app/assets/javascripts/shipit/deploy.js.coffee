class AbortButton
  SELECTOR = '[data-action="abort"]'

  @listen: ->
    $(document).on('click', SELECTOR, @handle)

  @handle: (event) =>
    event.preventDefault()
    button = new this($(event.currentTarget))
    button.trigger()

  constructor: (@$button) ->
    @url = @$button.find('a[href]').attr('href')
    @shouldRollback = @$button.data('rollback')

  trigger: ->
    return false if @isDisabled()

    @disable()
    @waitForCompletion()
    $.post(@url).success(@waitForCompletion).error(@reenable)

  waitForCompletion: =>
    setTimeout(@reenable, 3000)

  reenable: =>
    @$button.removeClass('pending')
    @$button.siblings(SELECTOR).removeClass('disabled')

  disable: ->
    @$button.addClass('pending')
    @$button.siblings(SELECTOR).addClass('disabled')

  isDisabled: ->
    @$button.hasClass('pending') || @$button.hasClass('disabled')

AbortButton.listen()
