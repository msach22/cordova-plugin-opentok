# Publisher Object:
#   Properties:
#     id (String) — The ID of the DOM element through which the Publisher stream is displayed
#     stream - The Stream object corresponding to the stream of the publisher
#     session (Session) — The Session to which the Publisher is publishing a stream. If the Publisher is not publishing a stream to a Session, this property is set to null.
#     replaceElementId (String) — The ID of the DOM element that was replaced when the Publisher video stream was inserted.
#   Methods: 
#     destroy():Publisher - not yet implemented
#     getImgData() : String - not yet implemented
#     getStyle() : Object - not yet implemented
#     off( type, listener )
#     on( type, listener )
#     publishAudio(Boolean) : publisher - change publishing state for Audio
#     publishVideo(Boolean) : publisher - change publishing state for Video
#     setStyle( style, value ) : publisher - not yet implemented
#
class TBPublisher
  constructor: (one, two) ->
    @sanitizeInputs(one, two)
    pdebug "creating publisher", {}
    position = getPosition(@domId)
    name=""
    publishAudio="true"
    publishVideo="true"
    cameraName = "front"
    zIndex = TBGetZIndex(document.getElementById(@domId))
    ratios = TBGetScreenRatios()
    audioFallbackEnabled = "true"
    audioBitrate = 40000
    audioSource = "true"
    videoSource = "true"
    frameRate = 30
    resolution = "640X480"
    if @properties?
      width = @properties.width ? position.width
      height = @properties.height ? position.height
      name = @properties.name ? ""
      cameraName = @properties.cameraName ? "front"
      audioFallbackEnabled = @properties.audioFallbackEnabled ? audioFallbackEnabled
      audioBitrate = @properties.audioBitrate ? audioBitrate
      audioSource = @properties.audioSource ? audioSource
      videoSource = @properties.videoSource ? videoSource
      frameRate = @properties.frameRate ? frameRate
      resolution = @properties.resolution ? resolution
      if(@properties.publishAudio? and @properties.publishAudio==false)
        publishAudio="false"
      if(@properties.publishVideo? and @properties.publishVideo==false)
        publishVideo="false"
      if(@properties.audioFallbackEnabled? and @properties.audioFallbackEnabled==false)
        audioFallbackEnabled="false"
      if(@properties.audioSource? || @properties.audioSource==false)
        audioSource="false"
      if(@properties.videoSource? || @properties.videoSource==false)
        videoSource="false"
    if (not width?) or width == 0 or (not height?) or height==0
      width = DefaultWidth
      height = DefaultHeight
    @pubElement = document.getElementById(@domId)
    replaceWithVideoStream(@domId, PublisherStreamId, {width:width, height:height})
    position = getPosition(@domId)
    TBUpdateObjects()
    OT.getHelper().eventing(@)
    Cordova.exec(TBSuccess, TBError, OTPlugin, "initPublisher", [name, position.top, position.left, width, height, zIndex, publishAudio, publishVideo, cameraName, ratios.widthRatio, ratios.heightRatio, audioFallbackEnabled, audioBitrate, audioSource, videoSource, frameRate, resolution] )
    Cordova.exec(@eventReceived, TBSuccess, OTPlugin, "addEvent", ["publisherEvents"] )
  setSession: (session) =>
    @session = session
  eventReceived: (response) =>
    pdebug "publisher event received", response
    @[response.eventType](response.data)
  streamCreated: (event) =>
    pdebug "publisher streamCreatedHandler", event
    pdebug "publisher streamCreatedHandler", @session
    pdebug "publisher streamCreatedHandler", @session.sessionConnection
    @stream = new TBStream( event.stream, @session.sessionConnection )
    streamEvent = new TBEvent( {stream: @stream } )
    @trigger("streamCreated", streamEvent)
    return @
  streamDestroyed: (event) =>
    pdebug "publisher streamDestroyed event", event
    streamEvent = new TBEvent( {stream: @stream, reason: "clientDisconnected" } )
    @trigger("streamDestroyed", streamEvent)
    # remove stream DOM?
    return @

  removePublisherElement: =>
    @pubElement.parentNode.removeChild(@pubElement)
    @pubElement = false

  destroy: ->
    if(@pubElement)
      Cordova.exec( @removePublisherElement, TBError, OTPlugin, "destroyPublisher", [])
  getImgData: ->
    return ""
  getStyle: ->
    return {}
  publishAudio: (state) ->
    @publishMedia( "publishAudio", state )
    return @
  publishVideo: (state) ->
    @publishMedia( "publishVideo", state )
    return @
  setCameraPosition: (cameraPosition) ->
    pdebug("setting camera position", cameraPosition: cameraPosition)
    Cordova.exec(TBSuccess, TBError, OTPlugin, "setCameraPosition", [cameraPosition])
    return @
  setStyle: (style, value ) ->
    return @

  publishMedia: (media, state) ->
    if media not in ["publishAudio", "publishVideo"] then return
    publishState = "true"
    if state? and ( state == false or state == "false" )
      publishState = "false"
    pdebug "setting publishstate", {media: media, publishState: publishState}
    Cordova.exec(TBSuccess, TBError, OTPlugin, media, [publishState] )
  sanitizeInputs: (one, two) ->
    if( two? )
      # all 2 optional properties present: domId, properties
      @domId = one
      @properties = two
    else if( one? )
      # only 1 property is present domId || properties
      if( typeof(one) == "object" )
        @properties = one
      else
        @domId = one
    @properties = if( @properties and typeof( @properties == "object" )) then @properties else {}
    # if domId exists but properties width or height is not specified, set properties
    if( @domId and document.getElementById( @domId ) )
      if !@properties.width or !@properties.height
        console.log "domId exists but properties width or height is not specified"
        position = getPosition( @domId )
        console.log " width: #{position.width} and height: #{position.height} for domId #{@domId}, and top: #{position.top}, left: #{position.left}"
        if position.width > 0 and position.height > 0
          @properties.width = position.width
          @properties.height = position.height
    else
      @domId = TBGenerateDomHelper()
    return @