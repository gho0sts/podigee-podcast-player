$ = require('jquery')
_ = require('lodash')
sightglass = require('sightglass')
rivets = require('rivets')

Utils = require('./utils.coffee')
CustomStyles = require('./custom_styles.coffee')
SubscribeButton = require('./extensions/subscribe_button.coffee')

class Theme
  constructor: (@app) ->
    @loadThemeFiles()
    @addCustomStyles()

  themeConfig: =>
    options = @app.extensionOptions.SubscribeBar
    if options?.disabled == false
      SubscribeButton.load(@app)
    {
      showSubscribeBar: options?.disabled == false,
      showSubscribeButton: !@app.isInAMPMode(),
      translations: {
        playPause: @t('theme.playPause'),
        backward: @t('theme.backward'),
        forward: @t('theme.forward'),
        speed: @t('theme.changePlaybackSpeed'),

        allEpisodes: @t('subscribeBar.allEpisodes'),
        podcastOnItunes: @t('subscribeBar.podcastOnItunes'),
        podcastOnSpotify: @t('subscribeBar.podcastOnSpotify'),
        podcastOnDeezer: @t('subscribeBar.podcastOnDeezer'),
        podcastOnAlexa: @t('subscribeBar.podcastOnAlexa'),
        subscribe: @t('subscribeBar.subscribe')
      },
      customOptions: @app.customOptions,
      or: @orFunction,
      externalSubscribeUrl: @externalSubscribeUrlFunction
    }

  # used in template to fall back to arg2 if arg1 is undefined or null
  orFunction: (arg1, arg2) =>
    arg1 || arg2

  externalSubscribeUrlFunction: (url) =>
    "#{url}#openSubscribeButtonPopup"

  context: =>
    attrs = _.merge(@app.episode, @app.podcast.forTheme(), @themeConfig())
    # hide All Episodes link when on the page that is linked to
    if @app.options.theme == 'default' && Utils.onSameUrl(attrs.podcastUrl)
      attrs.podcastUrl = null
    attrs

  t: (key) ->
    @app.i18n.t(key)

  html: null
  render: =>
    @elem = $(@html)
    @view = rivets.bind(@elem, @context())
    $(@app.elemClass).replaceWith(@elem)

    @addEmbedModeClass()
    @findElements()
    @bindCoverLoad()

    return @elem

  updateView: () =>
    @view.update(@context())

  addCustomStyles: () =>
    tag = new CustomStyles(@app.options.customStyle).toStyleTag()
    return unless tag
    $('head').append(tag)

  loadThemeFiles: () =>
    theme = @app.options.theme || 'default'
    themeHtml = @app.options.themeHtml || theme.html
    themeCss = @app.options.themeCss || theme.css
    if themeHtml && themeCss
      @loadCss(themeCss)
      @loadHtml(themeHtml)
    else if theme.constructor == String
      @loadInternalTheme(theme, themeHtml, themeCss)

  loadInternalTheme: (name, themeHtml, themeCss) =>
    pathPrefix = "themes/#{name}/index"
    @loadCss(themeCss || "#{pathPrefix}.css")
    @loadHtml(themeHtml || "#{pathPrefix}.html")

  loadHtml: (path) =>
    loaded = $.Deferred()
    self = this

    $.get(path).done (html) =>
      self.html = html
      loaded.resolve()

    @loaded = loaded.promise()

  loadCss: (path) =>
    style = $('<link>').attr
      href: path
      rel: 'stylesheet'
      type: 'text/css'
      media: 'all'
    $('head').append(style)

  addPlayingClass: ->
    @elem.addClass('playing')

  removePlayingClass: ->
    @elem.removeClass('playing')

  addLoadingClass: ->
    @removePlayingClass()
    @elem.addClass('loading')

  removeLoadingClass: ->
    @elem.removeClass('loading')

  addFailedLoadingClass: ->
    @elem.addClass('error-loading')

  addEmbedModeClass: ->
    modeClass = "mode-#{@app.options.iframeMode}"
    @elem.addClass(modeClass)

  findElements: ->
    @audioElement = @elem.find('audio')
    @progressBarElement = @elem.find('progressbar')
    @playPauseElement = @elem.find('.play-button')
    @backwardElement = @elem.find('.backward-button')
    @forwardElement = @elem.find('.forward-button')
    @skipForwardElement = @elem.find('.skip-forward-button')
    @skipBackwardElement = @elem.find('.skip-backward-button')
    @speedElement = @elem.find('.speed-toggle')
    @coverImage = @elem.find('.cover-image')
    @subscribeButton = @elem.find('.subscribe-button')

    @subscribeButton.on 'click', () => SubscribeButton.open(@app)

    @buttons = @elem.find('.buttons')
    @panels = @elem.find('.panels')
    @panels.hide() unless @app.isInIframeMode() || @app.options.startPanels

  bindCoverLoad: =>
    @coverImage.on 'load', =>
      @app.sendSizeChange()

  changeActiveButton: (event) =>
    button = $(event.target)
    if button.hasClass('button-active')
      button.removeClass('button-active')
      return

    @buttons.find('.button-active').removeClass('button-active')
    button.addClass('button-active')

  removeButtons: () =>
    @buttons.empty()

  removePanels: () =>
    @panels.empty()

  addButton: (button) =>
    @buttons.append(button)
    button.on 'click', @changeActiveButton

  addExtension: (extension) =>
    @addButton(extension.button)
    @panels.append(extension.panel)

    if extension.name() == @app.options.startPanel
      extension.button.trigger('click')
      @app.options.startPanel = null

    if @app.options.startPanels && @app.options.startPanels.indexOf(extension.name()) != -1
      extension.panel.show()

    if !@app.options.startPanel && @app.isInIframeMode()
      @buttons.hide()
      @panels.hide()

  animationOptions: ->
    duration: 300
    step: _.debounce(@app.sendSizeChange, 50)

  activePanel: null
  togglePanel: (elem) =>
    return unless elem
    if @activePanel?
      if @activePanel == elem
        if !@app.isInIframeMode()
          @activePanel.slideToggle(@animationOptions())
          @panels.slideToggle(@animationOptions())
          @activePanel = null
      else
        @activePanel.slideToggle(@animationOptions())
        elem.slideToggle(@animationOptions())
        @activePanel = elem
    else
      unless @app.isInIframeMode()
        @panels.slideToggle(@animationOptions())
      elem.slideToggle(@animationOptions())
      @activePanel = elem

module.exports = Theme
