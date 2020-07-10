# Cordova Plugin for OpenTok iOS and Android (ziomarco)

<img src="https://assets.tokbox.com/img/vonage/Vonage_VideoAPI_black.svg" height="48px" alt="Tokbox is now known as Vonage" />

![OpenTok Labs](https://d26dzxoao6i3hh.cloudfront.net/items/0U1R0a0e2g1E361H0x3c/Image%202017-11-22%20at%2012.16.38%20PM.png?v=2507a2df)

##### Disclaimer: This plugin is based on the [Cordova OpenTok Plugin](https://github.com/songz/cordova-plugin-opentok/). Please keep in mind that this is an OpenTok Labs project which means that it's not officially supported by TokBox.

## Sample code

To see the plugin in action, please check out [opentok-cordova-samples.](https://github.com/opentok/opentok-cordova-samples)

## Using Cordova CLI

Make sure You have Cordova 3.5.0 or greater installed. If you haven't, take a look at the [Cordova instructions](http://cordova.apache.org/docs/en/3.5.0/guide_cli_index.md.html) Page.

1. Clone this repo to get the source code for the OpenTok Cordova plugin

2. To install the OpenTok Cordova plugin, run the following command in the root of your project:

```
cordova plugin add cordova-plugin-opentok
```

3. To remove OpenTok Cordova plugin 3.2.0 and above, use the following command:

```
cordova plugin remove cordova-plugin-opentok
```

4. To remove the old OpenTok Cordova plugin, use the following command:

```
cordova plugin remove com.tokbox.cordova.opentok
```

## Getting Started on your Project:

All your editing will be done in your www folder.

To use the opentok library, make sure you include `opentok.js` file in your HTML document.  
`<script type="text/javascript" charset="utf-8" src="opentok.js"></script>`

All JavaScript code should be written in `onDeviceReady` function in `/js/index.js` because it is executed after all dependencies has loaded.

```
    onDeviceReady: function() {
        // Do Your Stuff Here!
    }
```

## Development and Contributing

Interested in contributing? We :heart: pull requests! See the
[Contribution](CONTRIBUTING.md) guidelines.

## Getting Help

We love to hear from you so if you have questions, comments or find a bug in the project, let us know! You can either:

- Open an issue on this repository
- See <https://support.tokbox.com/> for support options
- Tweet at us! We're [@VonageDev](https://twitter.com/VonageDev) on Twitter
- Or [join the Vonage Developer Community Slack](https://developer.nexmo.com/community/slack)
