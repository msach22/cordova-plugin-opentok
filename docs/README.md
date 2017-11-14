# OpenTok Cordova Plugin API Reference

The OpenTok API lets you add live video to your app. [Find out more online](http://www.tokbox.com/platform).

For an overview of the core concepts of OpenTok, please visit our [OpenTok Developer Page](https://tokbox.com/developer/)

### This OpenTok Cordova Plugin Library is a subset of the OpenTok JavaScript Library

## Usage

To use the OpenTok Cordova Plugin, include the OpenTok JavaScript file in your HTML file.

` <script src="opentok.js"></script> `

## API

### Objects

<table>
	<tr>
		<td>
      <a href="/docs/connection.md">Connection</a>
    </td>
    <td>Represents a connection to an OpenTok session</td>
	</tr>
	<tr>
		<td>
      <a href="/docs/publisher.md">Publisher</a>
    </td>
    <td>Provides information about the publishing stream</td>
	</tr>
	<tr>
		<td>
      <a href="/docs/session.md">Session</a>
    </td>
    <td>Provides access to much of the OpenTok functionality.</td>
	</tr>
	<tr>
		<td>
      <a href="/docs/stream.md">Stream</a>
    </td>
    <td>Specifies a stream and provides information about it</td>
	</tr>
	<tr>
		<td>
      <a href="/docs/subscriber.md">Subscriber</a>
    </td>
    <td>References a stream that you have subscribed to</td>
	</tr>
	<tr>
		<td>
      <a href="/docs/tb.md">TB</a>
    </td>
    <td>Lets you initialize the OpenTok API and set up exception event handling</td>
	</tr>
</table>


### Events

<table>
	<tr>
		<td>
      <a href="/docs/exceptionEvent.md">exception</a>
    </td>
		<td>Triggered when errors or unexpected behavior is encountered</td>
	</tr>
	<tr>
		<td>
      <a href="/docs/sessionEvents.md">sessionConnected</a>
    </td>
		<td>Triggered when session has successfully connected</td>
	</tr>
	<tr>
		<td>
      <a href="/docs/sessionEvents.md">sessionDisconnected</a>
    </td>
		<td>Triggered when a session has disconnected</td>
	</tr>
	<tr>
		<td>
      <a href="/docs/streamEvents.md">streamCreated</a>
    </td>
		<td>Triggered when new stream has been created in a session</td>
	</tr>
	<tr>
		<td>
      <a href="/docs/streamEvents.md">streamDestroyed</a>
    </td>
		<td>Triggered when stream has ended in a session</td>
	</tr>
</table>


## Gotcha!

Since the video View is a native UIView on top of the phoneGap's web view, moving the 'object' DOM will have no effect on the video. To update Video position, call this function:

```
OT.updateViews()
```
