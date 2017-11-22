![OpenTok Labs](https://d26dzxoao6i3hh.cloudfront.net/items/0U1R0a0e2g1E361H0x3c/Image%202017-11-22%20at%2012.16.38%20PM.png?v=2507a2df)
# Cordova Plugin for OpenTok iOS and Android

##### Disclaimer: This plugin is based on the [Cordova OpenTok Plugin](https://github.com/songz/cordova-plugin-opentok/). Please keep in mind that this is an OpenTok Labs project which means that it's not officially supported by TokBox.

## Sample code 
To see the plugin in action, please check out [opentok-cordova-samples.](https://github.com/msach22/opentok-cordova-samples)

## Using Cordova CLI
Make sure You have Cordova 3.5.0 or greater installed. If you haven't, take a look at the [Cordova instructions](http://cordova.apache.org/docs/en/3.5.0/guide_cli_index.md.html) Page.

1. Clone this repo to get the source code for the OpenTok Cordova plugin

2. To install the OpenTok Cordova plugin, run the following command in the root of your project:
```
cordova plugin add https://github.com/msach22/cordova-plugin-opentok/
```  
3. You can remove the existing OpenTok Cordova plugin by running the following command: 
``` 
cordova plugin remove com.tokbox.cordova.opentok
```

## Getting Started on your Project:
All your editing will be done in your www folder.

To use the opentok library, make sure you include `opentok.js` file in your HTML document.  
` <script type="text/javascript" charset="utf-8" src="opentok.js"></script>`

All JavaScript code should be written in `onDeviceReady` function in `/js/index.js` because it is executed after all dependencies has loaded.
```
    onDeviceReady: function() {
        // Do Your Stuff Here!
    }
```

# Development and Contributing

Interested in contributing? We love pull requests! See the
[Contribution](CONTRIBUTING.md) guidelines.