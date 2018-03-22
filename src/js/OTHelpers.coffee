streamElements = {} # keep track of DOM elements for each stream

# Whenever updateViews are involved, parameters passed through will always have:
# TBPublisher constructor, TBUpdateObjects, TBSubscriber constructor
# [id, top, left, width, height, zIndex, ... ]

#
# Helper methods
#
getPosition = (pubDiv) ->
  # Get the position of element
  if !pubDiv then return {}
  computedStyle = if window.getComputedStyle then getComputedStyle(pubDiv, null) else {}
  width = pubDiv.offsetWidth
  height = pubDiv.offsetHeight
  curtop = pubDiv.offsetTop
  curleft = pubDiv.offsetLeft
  while(pubDiv = pubDiv.offsetParent)
    curleft += pubDiv.offsetLeft
    curtop += pubDiv.offsetTop
  return {
    top:curtop
    left:curleft
    width:width
    height:height
  }

replaceWithVideoStream = (element, streamId, properties) ->
  typeClass = if streamId == PublisherStreamId then PublisherTypeClass else SubscriberTypeClass
  if (properties.insertMode == "replace")
    newElement = element
  else
    newElement = document.createElement( "div" )
  newElement.setAttribute( "class", "OT_root #{typeClass}" )
  newElement.setAttribute( "data-streamid", streamId )
  newElement.setAttribute( "data-insertMode", properties.insertMode )
  if (typeof properties.width is 'string')
    newElement.style.width = properties.width
  else
    newElement.style.width = properties.width+"px"
  if (typeof properties.height is 'string')
    newElement.style.height = properties.height
  else
    newElement.style.height = properties.height+"px"
  newElement.style.overflow = "hidden"
  newElement.style['background-color'] = "#000000"
  streamElements[ streamId ] = newElement

  internalDiv = document.createElement( "div" )
  internalDiv.setAttribute( "class", VideoContainerClass)
  internalDiv.style.width = "100%"
  internalDiv.style.height = "100%"
  internalDiv.style.left = "0px"
  internalDiv.style.top = "0px"

  videoElement = document.createElement( "video" )
  videoElement.style.width = "100%"
  videoElement.style.height = "100%"
  # todo: js change styles or append css stylesheets? Concern: users will not be able to change via css

  internalDiv.appendChild( videoElement )
  newElement.appendChild( internalDiv )

  if (properties.insertMode == "append")
    element.appendChild(newElement)
  if (properties.insertMode == "before")
    element.parentNode.insertBefore(newElement, element)
  if (properties.insertMode == "after")
    element.parentNode.insertBefore(newElement, element.nextSibling)
  return newElement

TBError = (error) ->
  console.log("Error: ", error)

TBSuccess = ->
  console.log("success")

OTPublisherError = (error) ->
  if error == "permission denied"
    OTReplacePublisher()
    TBError("Camera or Audio Permission Denied")
  else
    TBError(error)

TBUpdateObjects = ()->
  updateObject = () ->
    console.log("JS: Objects being updated in TBUpdateObjects")
    objects = document.getElementsByClassName('OT_root')

    ratios = TBGetScreenRatios()
    for e in objects
      streamId = e.dataset.streamid
      position = getPosition(e)

      # If not a TBPosition yet set, or new position not equals to the old one. Update views.
      if !e.TBPosition || position.top != e.TBPosition.top || position.left != e.TBPosition.left || position.width != e.TBPosition.width || position.height != e.TBPosition.height
        console.log("JS: Object updated with sessionId " + streamId + " updated");
        e.TBPosition = position;
        Cordova.exec(TBSuccess, TBError, OTPlugin, "updateView", [streamId, position.top, position.left, position.width, position.height, TBGetZIndex(e), ratios.widthRatio, ratios.heightRatio]);
    return

  # Ensure that we update before a repaint.
  requestAnimationFrame = window.requestAnimationFrame || window.webkitRequestAnimationFrame || window.mozRequestAnimationFrame;
  if requestAnimationFrame
    requestAnimationFrame(updateObject)
  else
    setTimeout(updateObject, 1000 / 60);
  return

TBGenerateDomHelper = ->
  domId = "PubSub" + Date.now()
  div = document.createElement('div')
  div.setAttribute( 'id', domId )
  document.body.appendChild(div)
  return domId

TBGetZIndex = (ele) ->
  while( ele? )
    val = document.defaultView.getComputedStyle(ele,null).getPropertyValue('z-index')
    if ( parseInt(val) )
      return val
    ele = ele.offsetParent
  return 0

TBGetScreenRatios = ()->
    # Ratio between browser window size and viewport size
    return {
        widthRatio: window.outerWidth / window.innerWidth,
        heightRatio: window.outerHeight / window.innerHeight
    }

OTReplacePublisher = ()->
    # replace publisher because permission denied
    elements = document.getElementsByClassName('OT_root OT_publisher');
    for el in elements
      elAttribute = el.getAttribute('data-streamid')
      if elAttribute == "TBPublisher"
        element = el
        break
    attributes = ['style', 'data-streamid', 'class']
    elementChildren = element.childNodes
    element.removeAttribute attribute for attribute in attributes
    for childElement in elementChildren
      childClass = childElement.getAttribute 'class'
      if childClass == 'OT_video-container'
        element.removeChild childElement
        break
    return

OTObserveVideoContainer = (() ->
  videoContainerObserver = new MutationObserver((mutations) ->
    for mutation in mutations
      if mutation.attributeName == 'style' || mutation.attributeName == 'class'
        TBUpdateObjects();
  )
  return (videoContainer) ->
    # If already observed, just update, else observe.
    if(videoContainer._OTObserved)
      TBUpdateObjects(videoContainer)
    else
      videoContainer._OTObserved = true;
      videoContainerObserver.observe(videoContainer, {
        # Set to true if additions and removals of the target node's child elements (including text nodes) are to be observed.
        childList: false
        # Set to true if mutations to target's attributes are to be observed.
        attributes: true
        # Set to true if mutations to target's data are to be observed.
        characterData: false
        # Set to true if mutations to not just target, but also target's descendants are to be observed.
        subtree: true
        # Set to true if attributes is set to true and target's attribute value before the mutation needs to be recorded.
        attributeOldValue: false
        # Set to true if characterData is set to true and target's data before the mutation needs to be recorded.
        characterDataOldValue: false
        # Set to an array of attribute local names (without namespace) if not all attribute mutations need to be observed.
        attributeFilter: ['style', 'class']
      })
)()
OTDomObserver = new MutationObserver((mutations) ->
  getVideoContainer = (node) ->
    if typeof node.querySelector != 'function'
      return

    videoElement = node.querySelector('video')
    if videoElement
      while (videoElement = videoElement.parentNode) && !videoElement.hasAttribute('data-streamid')
        continue
      return videoElement
    return false

  checkNewNode = (node) ->
    videoContainer = getVideoContainer(node)
    if videoContainer
      OTObserveVideoContainer(videoContainer)

  checkRemovedNode = (node) ->
    # Stand-in, if we want to trigger things in the future(like emitting events).
    return

  for mutation in mutations
    # Check if its attributes that have changed(including children).
    if mutation.type == 'attributes'
      videoContainer = getVideoContainer(mutation.target)
      if videoContainer
        TBUpdateObjects()
      continue

    # Check if there has been addition or deletion of nodes.
    if mutation.type != 'childList'
      continue

    # Check added nodes.
    for node in mutation.addedNodes
      checkNewNode(node)

    # Check removed nodes.
    for node in mutation.removedNodes
      checkRemovedNode(node)

  return
)

pdebug = (msg, data) ->
  console.log "JS Lib: #{msg} - ", data
