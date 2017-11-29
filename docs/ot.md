# OT Object

The OT Object lets you initialize the OpenTok API and set up exception event handling.

## Methods

[OT.addEventListener()](#addEventListener)  
[OT.initPublisher()](#initPublisher)  
[OT.initSession()](#initSession)  
[OT.removeEventListener()](#removeEventListener)  



<a name="addEventListener"></a>
### OT.addEventListener(type:String, listener:Function)

Registers a method as an event listener for a specific event. The OT class dispatches exception events, defined by the
[ExceptionEvent](exceptionEvent.md) object.

#### Parameters

* **type** (String) — This string identifying the type of event. The OT object can only dispatch one type of event: an exception event. The only type of event the OT object dispatches is an 'exception' event.

* **listener** (Function) — The function to be invoked when the OT object dispatches the event. An [ExceptionEvent](exceptionEvent.md) object is passed into this function.

Example Code:  
```
OT.addEventListener('exception', function(e){
  console.log(e.message);
});
```

<a name="initPublisher"></a>
### OT.initPublisher [replaceElementId:String], [properties:Object]):Publisher

Initializes and returns a Publisher object. You can use this Publisher object to test the microphone and camera attached to the Publisher, and then pass this Publisher object to Session.publish() to publish a stream to a session.

You can only create one publisher object. Calling `OT.initPublisher()` more than once will fail silently.

#### Parameters


* **replaceElementId** (String) - Optional. The id attribute of the existing DOM element that the Publisher video replaces. If you do not specify a replaceElementId, the application appends a new DOM element to the HTML body. 

* **properties** (Object) — Optional. This is an optional object that contains the following properties (each of which are optional):

  * **audioBitrate** (Number) — The desired bitrate for the published audio, in bits per second. The supported range of values is 6,000 - 510,000. (Invalid values are ignored.) Set this value to enable high-quality audio (or to reduce bandwidth usage with lower-quality audio).
  The following are recommended settings:

    * **8,000 - 12,000 for narrowband (NB) speech**
    * **16,000 - 20,000 for wideband (WB) speech**
    * **28,000 - 40,000 for full-band (FB) speech**
    * **48,000 - 64,000 for full-band (FB) music**
    
    * **The default value is 40,000.**

  * **audioFallbackEnabled** (Boolean) — Whether to turn on audio fallback or not.

  * **audioSource** (Boolean) — If this property is set to false, the audio subsystem will not be initialized for the publisher, and setting the publishAudio property will have no effect. If your application does not require the use of audio, it is recommended to set this property rather than use the publishAudio property, which only temporarily disables the audio track.

  * **cameraName** (String) - The preferred camera position. When setting this property, if the change is possible, the publisher will use the camera with the specified position. Valid Inputs: 'Front' or 'Back'
  
  * **frameRate** (Number) - The desired frame rate, in frames per second, of the video. Valid values are 30, 15, 7, and 1. The published stream will use the closest value supported on the publishing client. The frame rate can differ slightly from the value you set, depending on the device of the client. And the video will only use the desired frame rate if the client configuration supports it. 

  * **height** (Number) — The desired height, in pixels, of the displayed Publisher video stream (default: 198). 

  * **width** (Number) — The desired width, in pixels, of the displayed Publisher video stream (default: 264). 

  * **name** (String) — A string that will be associated with this publisher’s stream. This string is displayed at the bottom of publisher videos and at the bottom of subscriber videos associated with the published stream. If you do not specify a value, the name is set to the device name.

  * **publishAudio** (Boolean) — Whether to publish audio.

  * **publishVideo** (Boolean) — Whether to publish video.

  * **resolution** (String) - The desired resolution of the video. The format of the string is "widthxheight", where the width and height are represented in pixels. Valid values are "1280x720", "640x480", and "320x240". The published video will only use the desired resolution if the client configuration supports it. Some devices and clients do not support each of these resolution settings.

  * **videoSource** (Boolean) — If this property is set to false, the video subsystem will not be initialized for the publisher, and setting the publishVideo property will have no effect. If your application does not require the use of video, it is recommended to set this property rather than use the publishVideo property, which only temporarily disables the video track.


#### Returns

* **Publisher** ([Publisher](publisher.md)) — A Publisher object.


Example Code:  
```
var publisher = OT.initPublisher('myPublisherDiv', {name:"HelloWorld", audioSource: false } );
```

<a name="initSession"></a>
### OT.initSession(apiKey:String, sessionId:String):Session

Initializes and returns the local session object for a specified session ID.  
You connect to the session using the `connect()` method of the Session object returned by the `OT.initSession()` method. `OT.initSession()` does not initiate communications with the cloud, it simply initializes the Session object that you can use to connect (and to perform other operations once connected).

#### Parameters

* **sessionId** (String) — Use the [Session ID](https://tokbox.com/developer/guides/basics/#sessions) generated by your server that represents the session to which you are planning to connect.  

#### Returns

* **Session** ([Session](session.md)) - The session object through which all further interactions with the session will occur.

Example Code:  
```
var session = OT.initSession('1127', '1_mx...' )
```


<a name="removeEventListener"></a>
### OT.removeEventListener(type:String, listener:Function)  

Removes an event listener for a specific event  

#### Parameters

* **type** (String) — This string identifying the type of event. The OT object can only dispatch one type of event: an exception event. The only type of event the OT object dispatches is an 'exception' event.

* **listener** (Function) — The event listener function to remove.  
The OT object throws an exception if the listener name is invalid.  

Example Code:  
```
OT.removeEventListener('exception', eventHandlerFunction);
```
