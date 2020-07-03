package com.tokbox.cordova;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.Map;

import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.Manifest;
import android.os.Build;
import android.content.pm.PackageManager;
import android.annotation.SuppressLint;
import android.app.AlertDialog;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.graphics.Color;
import android.util.Log;
import android.util.DisplayMetrics;
import android.view.View;
import android.view.ViewGroup;
import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.Response;
import com.android.volley.VolleyError;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;

import com.opentok.android.Connection;
import com.opentok.android.OpentokError;
import com.opentok.android.Publisher;
import com.opentok.android.PublisherKit;
import com.opentok.android.Session;
import com.opentok.android.Stream;
import com.opentok.android.Stream.StreamVideoType;
import com.opentok.android.Subscriber;
import com.opentok.android.SubscriberKit;
import com.opentok.android.BaseVideoRenderer;
import com.tokbox.cordova.OpenTokCustomVideoRenderer;

public class OpenTokAndroidPlugin extends CordovaPlugin
        implements  Session.SessionListener,
                    Session.ConnectionListener,
                    Session.ReconnectionListener,
                    Session.ArchiveListener,
                    Session.SignalListener,
                    PublisherKit.PublisherListener,
                    Session.StreamPropertiesListener {

    private String sessionId;
    private String apiKey;
    protected Session mSession;
    public static final String TAG = "OTPlugin";
    public boolean sessionConnected;
    public boolean publishCalled; // we need this because creating publisher before sessionConnected = crash
    public RunnablePublisher myPublisher;
    public HashMap<String, CallbackContext> myEventListeners;
    public HashMap<String, Connection> connectionCollection;
    public HashMap<String, Stream> streamCollection;
    public HashMap<String, RunnableSubscriber> subscriberCollection;

    // Old tracking values.
    private HashMap<String, Boolean> streamHasAudio;
    private HashMap<String, Boolean> streamHasVideo;
    private HashMap<String, JSONObject> streamVideoDimensions;

    static JSONObject viewList = new JSONObject();
    static CordovaInterface _cordova;
    static CordovaWebView _webView;
    public static final String[] perms = {Manifest.permission.INTERNET, Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO};
    public CallbackContext permissionsCallback;


    public class RunnableUpdateViews implements Runnable {
        public JSONArray mProperty;
        public View mView;
        public ArrayList<RunnableUpdateViews> allStreamViews;

        public class CustomComparator implements Comparator<RunnableUpdateViews> {
            @Override
            public int compare(RunnableUpdateViews object1, RunnableUpdateViews object2) {
                return object1.getZIndex() - object2.getZIndex();
            }
        }

        public void updateZIndices() {
            allStreamViews = new ArrayList<RunnableUpdateViews>();
            for (Map.Entry<String, RunnableSubscriber> entry : subscriberCollection.entrySet()) {
                allStreamViews.add(entry.getValue());
            }
            if (myPublisher != null) {
                allStreamViews.add(myPublisher);
            }

            // Sort is still needed, because we need to sort from negative to positive for the z translation.
            Collections.sort(allStreamViews, new CustomComparator());

            for (RunnableUpdateViews viewContainer : allStreamViews) {
                // Set depth location of camera view based on CSS z-index.
                // See: https://developer.android.com/reference/android/view/View.html#setTranslationZ(float)
                if (android.os.Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    viewContainer.mView.setTranslationZ(viewContainer.getZIndex());
                }
                // If the zIndex is 0(default) bring the view to the top, last one wins.
                // See: https://github.com/saghul/cordova-plugin-iosrtc/blob/5b6a180b324c8c9bac533fa481a457b74183c740/src/PluginMediaStreamRenderer.swift#L191
                if(viewContainer.getZIndex() == 0) {
                    viewContainer.mView.bringToFront();
                }
            }
        }

        public int getZIndex() {
            try {
                return mProperty.getInt(5);
            } catch (Exception e) {
                return 0;
            }
        }

        @SuppressLint("NewApi")
        @Override
        public void run() {
            try {
                Log.i(TAG, "updating view in ui runnable" + mProperty.toString());
                Log.i(TAG, "updating view in ui runnable " + mView.toString());

                float widthRatio, heightRatio;

                // Ratios are index 6 & 7 on TB.updateViews, 8 & 9 on subscribe event, and 9 & 10 on TB.initPublisher
                int ratioIndex;
                if (mProperty.get(6) instanceof Number) {
                    ratioIndex = 6;
                } else if (mProperty.get(8) instanceof Number) {
                    ratioIndex = 8;
                } else {
                    ratioIndex = 9;
                }

                DisplayMetrics metrics = new DisplayMetrics();
                cordova.getActivity().getWindowManager().getDefaultDisplay().getMetrics(metrics);

                widthRatio = (float) mProperty.getDouble(ratioIndex) * metrics.density;
                heightRatio = (float) mProperty.getDouble(ratioIndex + 1) * metrics.density;
                mView.setY(mProperty.getInt(1) * heightRatio);
                mView.setX(mProperty.getInt(2) * widthRatio);
                ViewGroup.LayoutParams params = mView.getLayoutParams();
                params.height = (int) (mProperty.getInt(4) * heightRatio);
                params.width = (int) (mProperty.getInt(3) * widthRatio);
                mView.setLayoutParams(params);
                updateZIndices();
            } catch (Exception e) {
                Log.i(TAG, "error when trying to retrieve properties while resizing properties");
            }
        }
    }

    public class RunnablePublisher extends RunnableUpdateViews implements
            PublisherKit.PublisherListener, Publisher.CameraListener,
            PublisherKit.AudioLevelListener {
        /* properties: [name, position.top, position.left, width, height, zIndex,
           publishAudio, publishVideo, cameraName, ratios.widthRatio, ratios.heightRatio,
           audioFallbackEnabled, audioBitrate, audioSource, videoSource, frameRate, cameraResolution]
       */
        public Publisher mPublisher;

        public RunnablePublisher(JSONArray args) {
            this.mProperty = args;

            // prevent dialog box from showing because it causes crash
            SharedPreferences prefs = cordova.getActivity().getApplicationContext().getSharedPreferences("permissions",
                    Context.MODE_PRIVATE);
            Editor edit = prefs.edit();
            edit.clear();
            edit.putBoolean("opentok.publisher.accepted", true);
            edit.commit();


            boolean audioFallbackEnabled = true;
            boolean videoTrack = true;
            boolean audioTrack = true;
            boolean publishAudio = true;
            boolean publishVideo = true;
            int audioBitrate = 40000;
            String publisherName = "Android-Cordova-Publisher";
            String frameRate = "FPS_15";
            String resolution = "MEDIUM";
            String cameraName = "front";
            try {
                publisherName = this.mProperty.getString(0);
                audioBitrate = this.mProperty.getInt(12);
                frameRate = "FPS_" + this.mProperty.getString(15);
                videoTrack = this.mProperty.getString(14).equals("true");
                audioTrack = this.mProperty.getString(13).equals("true");
                audioFallbackEnabled = this.mProperty.getString(11).equals("true");
                publishVideo = this.mProperty.getString(7).equals("true");
                publishAudio = this.mProperty.getString(6).equals("true");
                cameraName = this.mProperty.getString(8).equals("back") ? "back" : cameraName;
                if (compareStrings(this.mProperty.getString(16), "1280x720")) {
                    resolution = "HIGH";
                }
                if (compareStrings(this.mProperty.getString(16), "320x240") || compareStrings(this.mProperty.getString(16), "352x288")) {
                    resolution = "LOW";
                }
                Log.i(TAG, "publisher properties sanitized");
            } catch (Exception e) {
                Log.i(TAG, "Unable to set publisher properties");
            }
            mPublisher = new Publisher.Builder(cordova.getActivity().getApplicationContext())
                    .videoTrack(videoTrack)
                    .audioTrack(audioTrack)
                    .name(publisherName)
                    .audioBitrate(audioBitrate)
                    .frameRate(Publisher.CameraCaptureFrameRate.valueOf(frameRate))
                    .resolution(Publisher.CameraCaptureResolution.valueOf(resolution))
                    .renderer(new OpenTokCustomVideoRenderer(cordova.getActivity().getApplicationContext()))
                    .build();
            mPublisher.setCameraListener(this);
            mPublisher.setPublisherListener(this);
            mPublisher.setAudioLevelListener(this);
            mPublisher.setStyle(BaseVideoRenderer.STYLE_VIDEO_SCALE, BaseVideoRenderer.STYLE_VIDEO_FILL);
            mPublisher.setAudioFallbackEnabled(audioFallbackEnabled);
            mPublisher.setPublishVideo(publishVideo);
            mPublisher.setPublishAudio(publishAudio);

            if (cameraName.equals("back")) {
                mPublisher.cycleCamera();
            }
        }

        public void setPropertyFromArray(JSONArray args) {
            this.mProperty = args;
        }

        public void startPublishing() {
            mSession.publish(mPublisher);
            cordova.getActivity().runOnUiThread(this);
        }

        public void stopPublishing() {
            ViewGroup parent = (ViewGroup) webView.getView().getParent();
            parent.removeView(this.mView);
            if(this.mPublisher != null){
                try {
                    mSession.unpublish(this.mPublisher);
                } catch(Exception e) {
                    Log.i(TAG, "Could not unpublish Publisher");
                }
            }
        }

        public void destroyPublisher() {
            ViewGroup parent = (ViewGroup) webView.getView().getParent();
            parent.removeView(this.mView);
            if (this.mPublisher != null) {
                this.mPublisher.destroy();
                this.mPublisher = null;
            }
        }

        public void getImgData(CallbackContext callbackContext) {
            ((OpenTokCustomVideoRenderer) mPublisher.getRenderer()).getSnapshot(callbackContext);
        }

        public void run() {
            if(this.mView == null) {
                this.mView = mPublisher.getView();
                ((ViewGroup) webView.getView().getParent()).addView(this.mView);

                // Set depth location of camera view based on CSS z-index.
                // See: https://developer.android.com/reference/android/view/View.html#setTranslationZ(float)
                if (android.os.Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    this.mView.setTranslationZ(this.getZIndex());
                }
            }
            super.run();
        }

        // event listeners
        @Override
        public void onError(PublisherKit arg0, OpentokError arg1) {
            // TODO Auto-generated method stub

        }

        @Override
        public void onStreamCreated(PublisherKit arg0, Stream arg1) {
            Log.i(TAG, "publisher stream received");
            streamCollection.put(arg1.getStreamId(), arg1);
            
            streamHasAudio.put(arg1.getStreamId(), arg1.hasAudio());
            streamHasVideo.put(arg1.getStreamId(), arg1.hasVideo());
            JSONObject videoDimensions = new JSONObject();
            try {
                videoDimensions.put("width", arg1.getVideoWidth());
                videoDimensions.put("height", arg1.getVideoHeight());
            } catch (JSONException e) {
            }
            streamVideoDimensions.put(arg1.getStreamId(), videoDimensions);

            triggerStreamEvent(arg1, "publisherEvents", "streamCreated");
        }

        @Override
        public void onStreamDestroyed(PublisherKit arg0, Stream arg1) {
            streamCollection.remove(arg1.getStreamId());

            streamHasAudio.remove(arg1.getStreamId());
            streamHasVideo.remove(arg1.getStreamId());
            streamVideoDimensions.remove(arg1.getStreamId());

            triggerStreamEvent(arg1, "publisherEvents", "streamDestroyed");
        }

        @Override
        public void onCameraChanged(Publisher arg0, int arg1) {
            // TODO Auto-generated method stub

        }

        @Override
        public void onCameraError(Publisher arg0, OpentokError arg1) {
            // TODO Auto-generated method stub

        }

        // audioLevelListener
        public void onAudioLevelUpdated(PublisherKit publisher, float audioLevel) {
            JSONObject data = new JSONObject();
            try {
                data.put("audioLevel", audioLevel);
                triggerJSEvent("publisherEvents", "audioLevelUpdated", data);
            } catch (JSONException e) {
            }
        }
    }

    public class RunnableSubscriber extends RunnableUpdateViews implements
            SubscriberKit.SubscriberListener, SubscriberKit.VideoListener,
            SubscriberKit.AudioLevelListener {
        //  property contains: [stream.streamId, position.top, position.left, width, height, subscribeToVideo, zIndex] )
        public Subscriber mSubscriber;
        public Stream mStream;

        public RunnableSubscriber(JSONArray args, Stream stream) {
            this.mProperty = args;
            mStream = stream;

            logMessage("NEW SUBSCRIBER BEING CREATED");
            mSubscriber = new Subscriber.Builder(cordova.getActivity().getApplicationContext(), mStream)
                    .renderer(new OpenTokCustomVideoRenderer(cordova.getActivity().getApplicationContext()))
                    .build();
            mSubscriber.setVideoListener(this);
            mSubscriber.setSubscriberListener(this);
            mSubscriber.setAudioLevelListener(this);
            mSubscriber.setStyle(BaseVideoRenderer.STYLE_VIDEO_SCALE, BaseVideoRenderer.STYLE_VIDEO_FILL);
            mSession.subscribe(mSubscriber);
            cordova.getActivity().runOnUiThread(this);
        }

        public void setPropertyFromArray(JSONArray args) {
            this.mProperty = args;
        }

        public void removeStreamView() {
            ViewGroup parent = (ViewGroup) webView.getView().getParent();
            parent.removeView(this.mView);
            if(mSubscriber != null) {
                try {
                    mSession.unsubscribe(mSubscriber);
                    mSubscriber.destroy();
                } catch(Exception e) {
                    Log.i(TAG, "Could not unsubscribe Subscriber");
                }
            }
        }

        public void run() {
            if(this.mView == null) {
                this.mView = mSubscriber.getView();
                ((ViewGroup) webView.getView().getParent()).addView(this.mView);

                // Set depth location of camera view based on CSS z-index.
                // See: https://developer.android.com/reference/android/view/View.html#setTranslationZ(float)
                if (android.os.Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    this.mView.setTranslationZ(this.getZIndex());
                }
                Log.i(TAG, "subscriber view is added to parent view!");
            }
            super.run();
        }

        public void getImgData(CallbackContext callbackContext) {
            ((OpenTokCustomVideoRenderer) mSubscriber.getRenderer()).getSnapshot(callbackContext);
        }

        @Override
        public void onConnected(SubscriberKit arg0) {
            // TODO Auto-generated method stub
            JSONObject eventData = new JSONObject();
            String streamId = arg0.getStream().getStreamId();
            try {
                eventData.put("streamId", streamId);
                triggerJSEvent("subscriberEvents", "connected", eventData);
                triggerJSEvent("sessionEvents", "subscribedToStream", eventData); // Backwards compatiblity
            } catch (JSONException e) {
                Log.e(TAG, "JSONException" + e.getMessage());
            }
            Log.i(TAG, "subscriber" + streamId + " is connected");
            this.run();
        }

        @Override
        public void onDisconnected(SubscriberKit arg0) {
            // TODO Auto-generated method stub
            JSONObject eventData = new JSONObject();
            String streamId = arg0.getStream().getStreamId();
            try {
                eventData.put("streamId", streamId);
                triggerJSEvent("subscriberEvents", "disconnected", eventData);
            } catch (JSONException e) {
                Log.e(TAG, "JSONException" + e.getMessage());
            }
            Log.i(TAG, "subscriber" + streamId + " is disconnected");
        }

        @Override
        public void onError(SubscriberKit arg0, OpentokError arg1) {
            JSONObject eventData = new JSONObject();
            String streamId = arg0.getStream().getStreamId();
            int errorCode = arg1.getErrorCode().getErrorCode();
            try {
                eventData.put("errorCode", errorCode);
                eventData.put("streamId", streamId);
                triggerJSEvent("sessionEvents", "subscribedToStream", eventData);
            } catch (JSONException e) {
                Log.e(TAG, "JSONException" + e.getMessage());
            }
            Log.e(TAG, "subscriber exception: " + arg1.getMessage() + ", stream id: " + arg0.getStream().getStreamId());
        }

        // listeners
        @Override
        public void onVideoDataReceived(SubscriberKit arg0) {
            triggerJSEvent("subscriberEvents", "videoDataReceived", null);
        }

        @Override
        public void onVideoDisabled(SubscriberKit arg0, String reason) {
            JSONObject data = new JSONObject();
            try {
                data.put("reason", reason);
                triggerJSEvent("subscriberEvents", "videoDisabled", data);
            } catch(JSONException e) {
            }
        }

        @Override
        public void onVideoDisableWarning(SubscriberKit arg0) {
            triggerJSEvent("subscriberEvents", "videoDisableWarning", null);
        }

        @Override
        public void onVideoDisableWarningLifted(SubscriberKit arg0) {
            triggerJSEvent("subscriberEvents", "videoDisableWarningLifted", null);
        }

        @Override
        public void onVideoEnabled(SubscriberKit arg0, String reason) {
            JSONObject data = new JSONObject();
            try {
                data.put("reason", reason);
                triggerJSEvent("subscriberEvents", "videoEnabled", data);
            } catch(JSONException e) {
            }
        }

        // audioLevelListener
        public void onAudioLevelUpdated(SubscriberKit subscriber, float audioLevel) {
            JSONObject data = new JSONObject();
            try {
                data.put("audioLevel", audioLevel);
                triggerJSEvent("subscriberEvents", "audioLevelUpdated", data);
            } catch (JSONException e) {
            }
        }

        public void subscribeToAudio(boolean value) {
            mSubscriber.setSubscribeToAudio(value);
        }

        public void subscribeToVideo(boolean value) {
            mSubscriber.setSubscribeToVideo(value);
        }
    }

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        _cordova = cordova;
        _webView = webView;

        // Make the web view transparent.
        _webView.getView().setBackgroundColor(Color.argb(1, 0, 0, 0));

        Log.d(TAG, "Initialize Plugin");
        // By default, get a pointer to mainView and add mainView to the viewList as it always exists (hold cordova's view)
        if (!viewList.has("mainView")) {
            // Cordova view is not in the viewList so add it.
            try {
                viewList.put("mainView", webView);
                Log.d(TAG, "Found CordovaView ****** " + webView);
            } catch (JSONException e) {
                // Error handle (this should never happen!)
                Log.e(TAG, "Critical error. Failed to retrieve Cordova's view");
            }
        }

        // set OpenTok states
        publishCalled = false;
        sessionConnected = false;
        myEventListeners = new HashMap<String, CallbackContext>();
        connectionCollection = new HashMap<String, Connection>();
        streamCollection = new HashMap<String, Stream>();
        subscriberCollection = new HashMap<String, RunnableSubscriber>();

        // Old tracking values.
        streamHasAudio = new HashMap<String, Boolean>();
        streamHasVideo = new HashMap<String, Boolean>();
        streamVideoDimensions = new HashMap<String, JSONObject>();

        super.initialize(cordova, webView);
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        Log.i(TAG, action);
        // TB Methods
        if (action.equals("initPublisher")) {
            myPublisher = new RunnablePublisher(args);
        } else if (action.equals("destroyPublisher")) {
            if (myPublisher != null) {
                myPublisher.destroyPublisher();
                myPublisher = null;
                callbackContext.success();
                return true;
            }
        } else if (action.equals("initSession")) {
            apiKey = args.getString(0);
            sessionId = args.getString(1);
            Log.i(TAG, "created new session with data: " + args.toString());
            mSession = new Session(this.cordova.getActivity().getApplicationContext(), apiKey, sessionId);
            mSession.setSessionListener(this);
            mSession.setConnectionListener(this);
            mSession.setReconnectionListener(this);
            mSession.setSignalListener(this);
            mSession.setStreamPropertiesListener(this);
            logOT(null);

            // publisher methods
        } else if (action.equals("setCameraPosition")) {
            myPublisher.mPublisher.cycleCamera();
        } else if (action.equals("publishAudio")) {
            String val = args.getString(0);
            boolean publishAudio = true;
            if (val.equalsIgnoreCase("false")) {
                publishAudio = false;
            }
            Log.i(TAG, "setting publishAudio");
            myPublisher.mPublisher.setPublishAudio(publishAudio);
        } else if (action.equals("publishVideo")) {
            String val = args.getString(0);
            boolean publishVideo = true;
            if (val.equalsIgnoreCase("false")) {
                publishVideo = false;
            }
            Log.i(TAG, "setting publishVideo");
            myPublisher.mPublisher.setPublishVideo(publishVideo);

            // session Methods
        } else if (action.equals("addEvent")) {
            Log.i(TAG, "adding new event - " + args.getString(0));
            myEventListeners.put(args.getString(0), callbackContext);
        } else if (action.equals("connect")) {
            Log.i(TAG, "connect command called");
            mSession.connect(args.getString(0));
            callbackContext.success();
        } else if (action.equals("disconnect")) {
            mSession.disconnect();
        } else if (action.equals("publish")) {
            if (sessionConnected) {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                    cordova.requestPermissions(this, 0, perms);
                    permissionsCallback = callbackContext;
                } else {
                    myPublisher.startPublishing();
                    Log.i(TAG, "publisher is publishing");
                }
            }
        } else if (action.equals("signal")) {
            Connection c = connectionCollection.get(args.getString(2));
            if (c == null) {
                mSession.sendSignal(args.getString(0), args.getString(1));
            } else {
                mSession.sendSignal(args.getString(0), args.getString(1), c);
            }
        } else if (action.equals("unpublish")) {
            Log.i( TAG, "unpublish command called");
            if (myPublisher != null) {
                myPublisher.stopPublishing();
                callbackContext.success();
                return true;
            }
        } else if (action.equals("unsubscribe")) {
            Log.i( TAG, "unsubscribe command called");
            Log.i( TAG, "unsubscribe data: " + args.toString() );
            final RunnableSubscriber runsub = subscriberCollection.get( args.getString(0) );
            if (runsub != null) {
                runsub.removeStreamView();
                callbackContext.success();
                return true;
            }
        } else if (action.equals("subscribe")) {
            Log.i(TAG, "subscribe command called");
            Log.i(TAG, "subscribe data: " + args.toString());
            Stream stream = streamCollection.get(args.getString(0));
            RunnableSubscriber runsub = new RunnableSubscriber(args, stream);
            subscriberCollection.put(stream.getStreamId(), runsub);
        } else if (action.equals("subscribeToAudio")) {
            RunnableSubscriber runsub = subscriberCollection.get(args.getString(0));
            String val = args.getString(1);
            if(runsub != null) {
                boolean subscribeAudio = true;
                if (val.equalsIgnoreCase("false")) {
                    subscribeAudio = false;
                }
                Log.i(TAG, "setting subscribeToAudio");
                runsub.subscribeToAudio(subscribeAudio);
            }
        } else if (action.equals("subscribeToVideo")) {
            RunnableSubscriber runsub = subscriberCollection.get(args.getString(0));
            String val = args.getString(1);
            if(runsub != null) {
                boolean subscribeVideo = true;
                if (val.equalsIgnoreCase("false")) {
                    subscribeVideo = false;
                }
                Log.i(TAG, "setting subscribeToVideo");
                runsub.subscribeToVideo(subscribeVideo);
            }
        } else if (action.equals("updateView")) {
            if (args.getString(0).equals("TBPublisher") && myPublisher != null && sessionConnected) {
                Log.i(TAG, "updating view for publisher");
                myPublisher.setPropertyFromArray(args);
                cordova.getActivity().runOnUiThread(myPublisher);
            } else {
                RunnableSubscriber runsub = subscriberCollection.get(args.getString(0));
                if (runsub != null) {
                    runsub.setPropertyFromArray(args);
                    cordova.getActivity().runOnUiThread(runsub);
                }
            }
        } else if (action.equals("getImgData")) {
            if (args.getString(0).equals("TBPublisher") && myPublisher != null && sessionConnected) {
                cordova.getThreadPool().execute(new Runnable() {
                    public void run() {
                      myPublisher.getImgData(callbackContext);
                    }
                });
                return true;
            } else {
                RunnableSubscriber runsub = subscriberCollection.get(args.getString(0));
                if (runsub != null) {
                  cordova.getThreadPool().execute(new Runnable() {
                      public void run() {
                         runsub.getImgData(callbackContext);
                      }
                  });
                  runsub.getImgData(callbackContext);
                  return true;
                }
            }
        } else if (action.equals("exceptionHandler")) {

        }
        return true;
    }

    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] results) throws JSONException {
        Boolean permissionError = false;
        for (int permissionResult : results) {
            if (permissionResult == PackageManager.PERMISSION_DENIED) {
                permissionError = true;
            }
        }
        if (permissionError) {
            PluginResult callback = new PluginResult(PluginResult.Status.ERROR, "permission denied");
            callback.setKeepCallback(false);
            permissionsCallback.sendPluginResult(callback);
        } else {
            myPublisher.startPublishing();
            Log.i(TAG, "permission granted-publisher is publishing");
        }
    }

    public void alertUser(String message) {
        // 1. Instantiate an AlertDialog.Builder with its constructor
        AlertDialog.Builder builder = new AlertDialog.Builder(cordova.getActivity());
        builder.setMessage(message).setTitle("TokBox Message");
        AlertDialog dialog = builder.create();
    }


    // sessionListener
    @Override
    public void onConnected(Session arg0) {
        logOT(arg0.getConnection().getConnectionId());
        Log.i(TAG, "session connected, triggering sessionConnected Event. My Cid is: " +
                mSession.getConnection().getConnectionId());
        sessionConnected = true;

        connectionCollection.put(mSession.getConnection().getConnectionId(), mSession.getConnection());

        JSONObject data = new JSONObject();
        try {
            data.put("status", "connected");
            JSONObject connection = createDataFromConnection(mSession.getConnection());
            data.put("connection", connection);
        } catch (JSONException e) {
        }
        triggerJSEvent("sessionEvents", "sessionConnected", data);
    }

    @Override
    public void onDisconnected(Session arg0) {
        sessionConnected = false;

        if (myPublisher != null) {
            myPublisher.destroyPublisher();
            myPublisher = null;
        }

        for (Map.Entry<String, RunnableSubscriber> entry : subscriberCollection.entrySet()) {
            entry.getValue().removeStreamView();
        }

        // delete all data and prevent updateviews from drawing non existent things
        subscriberCollection.clear();
        connectionCollection.clear();
        streamCollection.clear();

        JSONObject data = new JSONObject();
        try {
            data.put("reason", "clientDisconnected");
        } catch (JSONException e) {
        }

        triggerJSEvent("sessionEvents", "sessionDisconnected", data);
    }

    // reconnectionlistener
    @Override
    public void onReconnected(Session session) {
        Log.i(TAG, "session reconnected");
        triggerJSEvent("sessionEvents", "sessionReconnected", null);
    }

    @Override
    public void onReconnecting(Session session) {
        Log.i(TAG, "session reconnecting");
        triggerJSEvent("sessionEvents", "sessionReconnecting", null);
    }

    @Override
    public void onStreamDropped(Session arg0, Stream arg1) {
        Log.i(TAG, "session dropped stream");
        streamCollection.remove(arg1.getStreamId());

        streamHasAudio.remove(arg1.getStreamId());
        streamHasVideo.remove(arg1.getStreamId());
        streamVideoDimensions.remove(arg1.getStreamId());

        RunnableSubscriber subscriber = subscriberCollection.get(arg1.getStreamId());
        if (subscriber != null) {
            subscriber.removeStreamView();
            subscriberCollection.remove(arg1.getStreamId());
        }
        triggerStreamEvent(arg1, "sessionEvents", "streamDestroyed");
    }

    @Override
    public void onStreamReceived(Session arg0, Stream arg1) {
        Log.i(TAG, "stream received");
        streamCollection.put(arg1.getStreamId(), arg1);

        this.streamHasAudio.put(arg1.getStreamId(), arg1.hasAudio());
        this.streamHasVideo.put(arg1.getStreamId(), arg1.hasVideo());
        JSONObject videoDimensions = new JSONObject();
        try {
            videoDimensions.put("width", arg1.getVideoWidth());
            videoDimensions.put("height", arg1.getVideoHeight());
        } catch (JSONException e) {
        }
        this.streamVideoDimensions.put(arg1.getStreamId(), videoDimensions);

        triggerStreamEvent(arg1, "sessionEvents", "streamCreated");
    }

    @Override
    public void onError(Session arg0, OpentokError arg1) {
        // TODO Auto-generated method stub
        Log.e(TAG, "session exception: " + arg1.getMessage());
        alertUser("session error " + arg1.getMessage());
    }

    // connectionListener
    public void onConnectionCreated(Session arg0, Connection arg1) {
        Log.i(TAG, "connectionCreated");

        connectionCollection.put(arg1.getConnectionId(), arg1);

        JSONObject data = new JSONObject();
        try {
            JSONObject connection = createDataFromConnection(arg1);
            data.put("connection", connection);
        } catch (JSONException e) {
        }
        triggerJSEvent("sessionEvents", "connectionCreated", data);
    }

    public void onConnectionDestroyed(Session arg0, Connection arg1) {
        Log.i(TAG, "connection dropped: " + arg1.getConnectionId());

        connectionCollection.remove(arg1.getConnectionId());
        JSONObject data = new JSONObject();
        try {
            JSONObject connection = createDataFromConnection(arg1);
            data.put("connection", connection);
        } catch (JSONException e) {
        }
        triggerJSEvent("sessionEvents", "connectionDestroyed", data);
    }

    // signalListener
    public void onSignalReceived(Session arg0, String arg1, String arg2, Connection arg3) {
        JSONObject data = new JSONObject();
        Log.i(TAG, "signal type: " + arg1);
        Log.i(TAG, "signal data: " + arg2);
        try {
            data.put("type", arg1);
            data.put("data", arg2);
            if (arg3 != null) {
                data.put("connectionId", arg3.getConnectionId());
            }
            triggerJSEvent("sessionEvents", "signalReceived", data);
        } catch (JSONException e) {
        }
    }

    // archiveListener
    public void onArchiveStarted(Session session, String id, String name) {
        JSONObject data = new JSONObject();
        try {
            data.put("id", id);
            data.put("name", name);
            triggerJSEvent("sessionEvents", "archiveStarted", data);
        } catch (JSONException e) {
            Log.i(TAG, "archive started: " + id + " - " + name);
        }
    }

    public void onArchiveStopped(Session session, String id) {
        JSONObject data = new JSONObject();
        try {
            data.put("id", id);
            triggerJSEvent("sessionEvents", "archiveStopped", data);
        } catch (JSONException e) {
            Log.i(TAG, "archive stopped: " + id);
        }
    }

    // streamPropertiesListener
    @Override
    public void onStreamHasAudioChanged(Session session, Stream stream, boolean newValue) {
        boolean oldValue = this.streamHasAudio.get(stream.getStreamId());
        this.streamHasAudio.put(stream.getStreamId(), newValue);

        this.onStreamPropertyChanged("hasAudio", newValue, oldValue, stream);
    }

    @Override
    public void onStreamHasVideoChanged(Session session, Stream stream, boolean newValue) {
        boolean oldValue = this.streamHasVideo.get(stream.getStreamId());
        this.streamHasVideo.put(stream.getStreamId(), newValue);

        this.onStreamPropertyChanged("hasVideo", newValue, oldValue, stream);
    }

    @Override
    public void onStreamVideoDimensionsChanged(Session session, Stream stream, int width, int height) {
        JSONObject oldValue = this.streamVideoDimensions.get(stream.getStreamId());
        
        JSONObject newValue = new JSONObject();
        try {
            newValue.put("width", width);
            newValue.put("height", height);
            this.streamVideoDimensions.put(stream.getStreamId(), newValue);

            this.onStreamPropertyChanged("videoDimensions", newValue, oldValue, stream);
        } catch (JSONException e) {
        }
    }

    public void onStreamPropertyChanged(String changedProperty, Object newValue, Object oldValue, Stream stream) {
        JSONObject data = new JSONObject();
        try {
            JSONObject streamData = createDataFromStream(stream);
            data.put("changedProperty", changedProperty);
            data.put("newValue", newValue);
            data.put("oldValue", oldValue);
            data.put("stream", streamData);
            triggerJSEvent("sessionEvents", "streamPropertyChanged", data);
        } catch (JSONException e) {
        }
    }

    // Helper Methods
    public void logMessage(String a) {
        Log.i(TAG, a);
    }

    public boolean compareStrings(String a, String b) {
        if (a != null && b != null && a.equalsIgnoreCase(b)) {
            return true;
        }
        return false;
    }

    public void triggerStreamEvent(Stream arg1, String eventType, String subEvent) {
        JSONObject data = new JSONObject();
        try {
            JSONObject stream = createDataFromStream(arg1);
            data.put("stream", stream);
            triggerJSEvent(eventType, subEvent, data);
        } catch (JSONException e) {
        }
    }

    public void logOT(final String connectionId) {
        RequestQueue queue = Volley.newRequestQueue(this.cordova.getActivity().getApplicationContext());
        String url = "https://hlg.tokbox.com/prod/logging/ClientEvent";
        StringRequest postRequest = new StringRequest(Request.Method.POST, url,
            new Response.Listener<String>()
            {
                @Override
                public void onResponse(String response) {
                    // response
                    Log.i(TAG, "Log Response: " + response);
                }
            },
            new Response.ErrorListener()
            {
                 @Override
                 public void onErrorResponse(VolleyError error) {
                     // error
                     Log.i(TAG, "Error logging");
               }
            }
        ) {
            @Override
            protected Map<String, String> getParams()
            {
                    JSONObject payload = new JSONObject();
                    try {
                        payload.put("platform", "Android");
                        payload.put("cp_version", "3.4.3");
                    } catch (JSONException e) {
                        Log.i(TAG, "Error creating payload json object");
                    }
                    Map<String, String>  params = new HashMap<String, String>();
                    params.put("payload_type", "info");
                    params.put("partner_id", apiKey);
                    params.put("payload", payload.toString());
                    params.put("source", "https://github.com/opentok/cordova-plugin-opentok");
                    params.put("build", "2.16.6");
                    params.put("session_id", sessionId);
                    if (connectionId != null) {
                        params.put("action", "cp_on_connect");
                        params.put("connectionId", connectionId);                
                    } else {
                        params.put("action", "cp_initialize");
                    }

                return params;
            }
        };
        queue.add(postRequest);
    }

    public JSONObject createDataFromConnection(Connection arg1) {
        JSONObject connection = new JSONObject();

        try {
            connection.put("connectionId", arg1.getConnectionId());
            connection.put("creationTime", arg1.getCreationTime());
            connection.put("data", arg1.getData());
        } catch (JSONException e) {
        }
        return connection;
    }

    public JSONObject createDataFromStream(Stream arg1) {
        JSONObject stream = new JSONObject();
        try {
            Connection connection = arg1.getConnection();
            if (connection != null) {
                stream.put("connectionId", connection.getConnectionId()); // Backwards compatability
                stream.put("connection", createDataFromConnection(connection));
            }
            stream.put("creationTime", arg1.getCreationTime());
            stream.put("fps", -999);
            stream.put("hasAudio", arg1.hasAudio());
            stream.put("hasVideo", arg1.hasVideo());

            JSONObject videoDimensions = new JSONObject();
            try {
                videoDimensions.put("width", arg1.getVideoWidth());
                videoDimensions.put("height", arg1.getVideoHeight());
            } catch (JSONException e) {}
            stream.put("videoDimensions", videoDimensions);

            String videoType = "custom";
            if(arg1.getStreamVideoType() == Stream.StreamVideoType.StreamVideoTypeCamera) {
                videoType = "camera";
            } else if(arg1.getStreamVideoType() == Stream.StreamVideoType.StreamVideoTypeScreen) {
                videoType = "screen";
            }
            stream.put("videoType", videoType);

            stream.put("name", arg1.getName());
            stream.put("streamId", arg1.getStreamId());
        } catch (Exception e) {
        }
        return stream;
    }

    public void triggerJSEvent(String event, String type, Object data) {
        JSONObject message = new JSONObject();

        try {
            message.put("eventType", type);
            message.put("data", data);
        } catch (JSONException e) { }

        PluginResult myResult = new PluginResult(PluginResult.Status.OK, message);
        myResult.setKeepCallback(true);
        myEventListeners.get(event).sendPluginResult(myResult);
    }

    @Override
    public void onError(PublisherKit arg0, OpentokError arg1) {
        // TODO Auto-generated method stub

    }

    @Override
    public void onStreamCreated(PublisherKit arg0, Stream arg1) {
        // TODO Auto-generated method stub

    }

    @Override
    public void onStreamDestroyed(PublisherKit arg0, Stream arg1) {
        if (myPublisher != null) {
            myPublisher.destroyPublisher();
            myPublisher = null;
        }
    }

    @Override
    public void onStreamVideoTypeChanged(Session arg0, Stream arg1,
                                         StreamVideoType arg2) {
        // TODO Auto-generated method stub

    }
}