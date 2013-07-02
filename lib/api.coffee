request = require 'request'
_ = require 'underscore'
{E} = require './error'
{make_esc} = require 'iced-error'

random = (h,l)->Math.round Math.random()*(h-l)+l

client_id = '545553600905.apps.googleusercontent.com'
client_secret = 'q-tA1vMJhkoeoucVH7NfvryX'
red_uri = 'urn:ietf:wg:oauth:2.0:oob'
endpoint = 'https://www.googleapis.com/rpc?prettyPrint=false'
appVersion = 16077


refresh = (code,gcb)->
    esc = make_esc gcb
    option={
        url:'https://accounts.google.com/o/oauth2/token'
        method:'POST'
        encoding:'utf-8'
        headers:{
            'User-Agent':'gtm-oauth2 com.google.GooglePlus/4.2.0'
            'Content-Type':'application/x-www-form-urlencoded'
            'Accept-Language':'zh-cn'
        }
        form:{
            client_id
            client_secret
            grant_type:'refresh_token'
            refresh_token:code
        }
    }

    await request option,esc defer(rep,body)

    try
        body = JSON.parse body
    catch e
        return gcb(e)

    return gcb new Error(body.error) if body.error?

    return gcb null,"#{body.token_type} #{body.access_token}"



###
The main API class

@mixin
###
class GPlusAPI
    ###
    Create an new API object

    @param refreshToken [String] The refresh token is used to login to the API and refresh the access token.
    @param userID [String] The user's Google+ profile ID. **Don't pass Integer**
    ###
    constructor:(@refreshToken,@userID)->

    ###
    Make API request.
    You can call this function manually if you want to make custom request.

    @param method [String] The JSON-RPC object's 'method' property.
    @param param [Object] The method's parameter.
    @param callback [function(err,result)] Called when the request executed.
    ###
    makeRequest:(method,param,callback)=>
        esc = make_esc callback
        body ={
            id:random 233,1
            jsonrpc:'2.0'
            apiVersion:'v2'
            method
            params:{}
        }

        body.params = _.extend param,{
            commonFields:{
                appVersion
                effectiveUser:@userID
                sourceInfo:'native:iphone_app'
            }
        }
        body = JSON.stringify body

        if not @access?
            await refresh @refreshToken,esc defer(@access)

        options = {
            url:endpoint
            method:'POST'
            encoding:'utf-8'
            body
            proxy:'http://127.0.0.1:8888'
            strictSSL:false
            headers:{
                'Accept':'application/json-rpc',
                'Accept-Language':'zh-cn',
                'User-Agent':'Mozilla/5.0 (iPad1,1; U; CPU iPhone OS 5_1_1 like Mac OS X; zh_CN) com.google.GooglePlus/13196 (KHTML, like Gecko) Mobile/K48AP (gzip)',
                'Authorization':@access
            }
        }


        await request options,esc defer(res,body)

        try
            body = JSON.parse body
        catch e
            return callback new Error E.msg.INVALID_JSON

        if body.error?.message is 'Invalid Credentials'
            await refresh @refreshToken,esc defer(@access)
            options = {
                url:endpoint
                method:'POST'
                encoding:'utf-8'
                body
                headers:{
                    'Accept':'application/json-rpc',
                    'Accept-Language':'zh-cn',
                    'User-Agent':'Mozilla/5.0 (iPad1,1; U; CPU iPhone OS 5_1_1 like Mac OS X; zh_CN) com.google.GooglePlus/13196 (KHTML, like Gecko) Mobile/K48AP (gzip)',
                    'Authorization':@access
                }
            }
            await request options,esc defer(res,body)







        if body.error?
            return callback(new Error body.error.message)


        return callback null,body.result



    ###
    Get the current user's mobile app settings(including multi-account infomation)

    @param callback [function(err,result)] Called when the *plusi.ozinternal.getmobilesettings* method executed
    ###
    getMobileSettings:(callback)=>
        @makeRequest 'plusi.ozinternal.getmobilesettings',{},callback

    ###
    Get a user's profile.

    @param ownerId [String] The profile owner's Google+ profile ID
    @param callback [function(err,result)] Called when the *plusi.ozinternal.getsimpleprofile* method executed
    ###
    getProfile:(ownerId,callback)=>
        @makeRequest 'plusi.ozinternal.getsimpleprofile',{includeAdData:false,ownerId},callback

    ###
    Send a public post.


    @todo Implement sharing target selection
    @param updateText [String] The post's content.
    @param callback [function(err,result)] Called when the *plusi.ozinternal.postactivity* method executed
    ###
    postPublicActivity:(updateText,embed,callback)=>
        param = {
            externalId:"#{random(1999999999999,1000000000000)}_#{random(39999999,10000000)}"
            updateText
            sharingRoster:
                sharingTargetId:[{groupType:"PUBLIC"}]
        }
        param.embed = embed if embed?
        @makeRequest 'plusi.ozinternal.postactivity',param,callback

    linkPreview:(url,callback)=>
        @makeRequest 'plusi.ozinternal.linkpreview',{
            content:url,
            fallbackToUrl:true
            useSmallPreviews:true
        },callback



module.exports = GPlusAPI