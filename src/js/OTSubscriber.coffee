# Subscriber Object:
#   Properties:
#     id (string) - dom id of the subscriber
#     stream (Stream) - stream to which you are subscribing
#   Methods: 
#     getAudioVolume()
#     getImgData() : String
#     getStyle() : Objects
#     off( type, listener ) : objects
#     on( type, listener ) : objects
#     setAudioVolume( value ) : subscriber
#     setStyle( style, value ) : subscriber
#     subscribeToAudio( value ) : subscriber
#     subscribeToVideo( value ) : subscriber
class TBSubscriber
  getAudioVolume: ->
    return 0
  getImgData: ->
    return ""
  getStyle: ->
    return {}
  off: (event, handler) ->
    return @
  on: (event, handler) ->
# todo - videoDisabled
    return @
  setAudioVolume:(value) ->
    return @
  setStyle: (style, value) ->
    return @
  subscribeToAudio: (value) ->
    return @
  subscribeToVideo: (value) ->
    return @

  constructor: (stream, divObject, properties) ->
    if divObject instanceof Element
      @element = divObject
      @id = @element.id
    else
      @id = divObject
      @element = document.getElementById(divObject)

    pdebug "creating subscriber", properties
    @streamId = stream.streamId
    divPosition = getPosition(@element)
    subscribeToVideo="true"
    zIndex = TBGetZIndex(@element)
    insertMode = "replace"
    if(properties?)
      width = properties.width || divPosition.width
      height = properties.height || divPosition.height
      name = properties.name ? ""
      subscribeToVideo = "true"
      subscribeToAudio = "true"
      if(properties.subscribeToVideo? and properties.subscribeToVideo == false)
        subscribeToVideo="false"
      if(properties.subscribeToAudio? and properties.subscribeToAudio == false)
        subscribeToAudio="false"
      insertMode = properties.insertMode ? insertMode
    if (not width?) or width == 0 or (not height?) or height==0
      width = DefaultWidth
      height = DefaultHeight
    obj = replaceWithVideoStream(@element, stream.streamId, {width:width, height:height, insertMode:insertMode})
    # If element is not yet in body, set it to 0 and then the observer will set it properly.
    if !document.body.contains(@element)
      width = 0;
      height = 0;
    position = getPosition(@element)
    ratios = TBGetScreenRatios()
    pdebug "final subscriber position", position
    Cordova.exec(TBSuccess, TBError, OTPlugin, "subscribe", [stream.streamId, position.top, position.left, width, height, zIndex, subscribeToAudio, subscribeToVideo, ratios.widthRatio, ratios.heightRatio] )

  # deprecating
  removeEventListener: (event, listener) ->
    return @
