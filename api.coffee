wait = require 'wait.for'
_ = require 'lodash'
request = require 'request'

client_id = '545553600905.apps.googleusercontent.com'
client_secret = 'q-tA1vMJhkoeoucVH7NfvryX'
red_uri = 'urn:ietf:wg:oauth:2.0:oob'
endpoint = 'https://www.googleapis.com/rpc?prettyPrint=false'
appVersion = 16077

random = (h,l)->Math.round Math.random()*(h-l)+l

refresh = (code,cb)-> wait.launchFiber ->
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
  try
    rep = JSON.parse wait.for(request,option).body
    throw new Error(rep.error) if rep.error?
  catch e
    return _.defer cb,e

  _.defer cb,null,"#{rep.token_type} #{rep.access_token}"



#refresh '1/Vylq1JSosdc1xD5aZ5Lc-V-6OjzOsjsx4DgmI9V1Zwc',->console.dir arguments

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
  makeRequest:(method,param,cb)=>wait.launchFiber =>
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
      try
        @access = wait.for refresh,@refreshToken
      catch e
        return _.defer cb,e
    options = {
      url:endpoint
      method:'POST'
      encoding:'utf-8'
      body
      #proxy:'http://127.0.0.1:8888'
      strictSSL:false
      headers:{
        'Accept':'application/json-rpc',
        'Accept-Language':'zh-cn',
        'User-Agent':'Mozilla/5.0 (iPad1,1; U; CPU iPhone OS 5_1_1 like Mac OS X; zh_CN) com.google.GooglePlus/13196 '+
        '(KHTML, like Gecko) Mobile/K48AP (gzip)',
        'Authorization':@access
      }
    }
    try
      rep = JSON.parse wait.for(request,options).body
      throw new Error(rep.error) if rep.error?.message is not 'Invalid Credentials' and rep.error?
    catch e
      return _.defer cb,e
    if rep.error?.message is 'Invalid Credentials'
      try
        @access = wait.for refresh,@refreshToken
      catch e
        return _.defer cb,e
      options.headers.Authorization = @access
      try
        rep = JSON.parse wait.for(request,options).body
        throw new Error(rep.error) if rep.error?
      catch e
        return _.defer cb,e

    return _.defer cb,null,rep.result

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

#api.postPublicActivity('Nya~',null,->console.dir arguments[0])



